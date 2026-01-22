local util = require("lifemode.util")
local config = require("lifemode.config")
local schema = require("lifemode.infra.index.schema")
local adapter = require("lifemode.infra.index.sqlite")
local domain_node = require("lifemode.domain.node")
local types = require("lifemode.domain.types")

local M = {}

local function validate_uuid(uuid)
	if type(uuid) ~= "string" then
		return false
	end
	return uuid:match(
		"^[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-4[0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$"
	) ~= nil
end

local function get_db_path()
	local vault_path = config.get("vault_path")
	return vault_path .. "/.lifemode/index.sqlite"
end

local function ensure_db_dir(db_path)
	local dir = vim.fn.fnamemodify(db_path, ":h")

	if vim.fn.isdirectory(dir) == 0 then
		local mkdir_ok, mkdir_err = pcall(function()
			vim.fn.mkdir(dir, "p")
		end)

		if not mkdir_ok then
			return util.Err("ensure_db_dir: failed to create directory: " .. tostring(mkdir_err))
		end
	end

	return util.Ok(nil)
end

local function get_db()
	local db_path = get_db_path()

	local dir_result = ensure_db_dir(db_path)
	if not dir_result.ok then
		return dir_result
	end

	local init_result = schema.init_db(db_path)
	if not init_result.ok then
		return util.Err(init_result.error)
	end

	return util.Ok(init_result.value)
end

function M.insert_node(node, file_path)
	if not node then
		return util.Err("insert_node: node is required")
	end

	if not file_path or file_path == "" then
		return util.Err("insert_node: file_path is required")
	end

	local validate_result = domain_node.validate(node)
	if not validate_result.ok then
		return util.Err("insert_node: invalid node: " .. validate_result.error)
	end

	local db_result = get_db()
	if not db_result.ok then
		return util.Err("insert_node: " .. db_result.error)
	end

	local db = db_result.value

	local insert_sql = [[
		INSERT INTO nodes (uuid, file_path, created, modified, content)
		VALUES (?, ?, ?, ?, ?)
	]]

	local exec_result = adapter.exec(db, insert_sql, {
		node.id,
		file_path,
		node.meta.created,
		node.meta.modified,
		node.content,
	})

	if not exec_result.ok then
		adapter.close(db)
		if exec_result.error:match("UNIQUE") or exec_result.error:match("already exists") then
			return util.Err("insert_node: node already exists: " .. node.id)
		end
		return util.Err("insert_node: " .. exec_result.error)
	end

	local fts_sql = "INSERT INTO nodes_fts (uuid, content) VALUES (?, ?)"
	local fts_result = adapter.exec(db, fts_sql, { node.id, node.content })

	adapter.close(db)

	if not fts_result.ok then
		vim.notify(
			"[LifeMode] WARN: Failed to update FTS index for node " .. node.id .. ": " .. fts_result.error,
			vim.log.levels.WARN
		)
	end

	return util.Ok(nil)
end

function M.update_node(node, file_path)
	if not node then
		return util.Err("update_node: node is required")
	end

	if not file_path or file_path == "" then
		return util.Err("update_node: file_path is required")
	end

	local validate_result = domain_node.validate(node)
	if not validate_result.ok then
		return util.Err("update_node: invalid node: " .. validate_result.error)
	end

	local db_result = get_db()
	if not db_result.ok then
		return util.Err("update_node: " .. db_result.error)
	end

	local db = db_result.value

	local check_sql = "SELECT uuid FROM nodes WHERE uuid = ?"
	local check_result = adapter.query(db, check_sql, { node.id })

	if not check_result.ok then
		adapter.close(db)
		return util.Err("update_node: " .. check_result.error)
	end

	if #check_result.value == 0 then
		adapter.close(db)
		return util.Err("update_node: node not found: " .. node.id)
	end

	local update_sql = [[
		UPDATE nodes
		SET file_path = ?, created = ?, modified = ?, content = ?
		WHERE uuid = ?
	]]

	local exec_result =
		adapter.exec(db, update_sql, { file_path, node.meta.created, node.meta.modified, node.content, node.id })

	if not exec_result.ok then
		adapter.close(db)
		return util.Err("update_node: " .. exec_result.error)
	end

	local fts_sql = "INSERT OR REPLACE INTO nodes_fts (uuid, content) VALUES (?, ?)"
	local fts_result = adapter.exec(db, fts_sql, { node.id, node.content })

	adapter.close(db)

	if not fts_result.ok then
		vim.notify(
			"[LifeMode] WARN: Failed to update FTS index for node " .. node.id .. ": " .. fts_result.error,
			vim.log.levels.WARN
		)
	end

	return util.Ok(nil)
end

function M.delete_node(uuid)
	if not uuid or uuid == "" then
		return util.Err("delete_node: uuid is required")
	end

	if not validate_uuid(uuid) then
		return util.Err("delete_node: invalid UUID: " .. uuid)
	end

	local db_result = get_db()
	if not db_result.ok then
		return util.Err("delete_node: " .. db_result.error)
	end

	local db = db_result.value

	local delete_edges_sql = "DELETE FROM edges WHERE from_uuid = ? OR to_uuid = ?"
	local edges_result = adapter.exec(db, delete_edges_sql, { uuid, uuid })

	if not edges_result.ok then
		adapter.close(db)
		return util.Err("delete_node: failed to delete edges: " .. edges_result.error)
	end

	local delete_node_sql = "DELETE FROM nodes WHERE uuid = ?"
	local node_result = adapter.exec(db, delete_node_sql, { uuid })

	if not node_result.ok then
		adapter.close(db)
		return util.Err("delete_node: " .. node_result.error)
	end

	local delete_fts_sql = "DELETE FROM nodes_fts WHERE uuid = ?"
	local fts_result = adapter.exec(db, delete_fts_sql, { uuid })

	adapter.close(db)

	if not fts_result.ok then
		vim.notify(
			"[LifeMode] WARN: Failed to delete from FTS index: " .. uuid .. ": " .. fts_result.error,
			vim.log.levels.WARN
		)
	end

	return util.Ok(nil)
end

function M.find_by_id(uuid)
	if not uuid or uuid == "" then
		return util.Err("find_by_id: uuid is required")
	end

	if not validate_uuid(uuid) then
		return util.Err("find_by_id: invalid UUID: " .. uuid)
	end

	local db_result = get_db()
	if not db_result.ok then
		return util.Err("find_by_id: " .. db_result.error)
	end

	local db = db_result.value

	local query_sql = [[
		SELECT uuid, file_path, created, modified, content
		FROM nodes WHERE uuid = ?
	]]

	local query_result = adapter.query(db, query_sql, { uuid })

	adapter.close(db)

	if not query_result.ok then
		return util.Err("find_by_id: " .. query_result.error)
	end

	local rows = query_result.value

	if #rows == 0 then
		return util.Ok(nil)
	end

	local row = rows[1]

	local node_meta = {
		id = row.uuid,
		created = row.created,
		modified = row.modified,
	}

	local node_result = types.Node_new(row.content, node_meta)

	if not node_result.ok then
		return util.Err("find_by_id: corrupted node data: " .. node_result.error)
	end

	return util.Ok(node_result.value)
end

return M
