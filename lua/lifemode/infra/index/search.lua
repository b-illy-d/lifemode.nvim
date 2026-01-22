local util = require("lifemode.util")
local config = require("lifemode.config")
local schema = require("lifemode.infra.index.schema")
local adapter = require("lifemode.infra.index.sqlite")
local types = require("lifemode.domain.types")

local M = {}

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

function M.search(query_text, opts)
	if not query_text or query_text == "" then
		return util.Err("search: query_text is required")
	end

	opts = opts or {}
	local limit = opts.limit or 50
	local offset = opts.offset or 0

	local db_result = get_db()
	if not db_result.ok then
		return util.Err("search: " .. db_result.error)
	end

	local db = db_result.value

	local search_sql = [[
		SELECT nodes.uuid, nodes.file_path, nodes.created, nodes.modified, nodes.content
		FROM nodes_fts
		JOIN nodes ON nodes_fts.uuid = nodes.uuid
		WHERE nodes_fts MATCH ?
		ORDER BY rank
		LIMIT ? OFFSET ?
	]]

	local query_result = adapter.query(db, search_sql, { query_text, limit, offset })

	adapter.close(db)

	if not query_result.ok then
		if query_result.error:match("fts5") or query_result.error:match("syntax") then
			return util.Err("search: invalid search syntax: " .. query_result.error)
		end
		return util.Err("search: " .. query_result.error)
	end

	local rows = query_result.value
	local nodes = {}

	for _, row in ipairs(rows) do
		local node_meta = {
			id = row.uuid,
			created = row.created,
			modified = row.modified,
		}

		local node_result = types.Node_new(row.content, node_meta)

		if node_result.ok then
			table.insert(nodes, node_result.value)
		end
	end

	return util.Ok(nodes)
end

function M.rebuild_fts_index()
	local db_result = get_db()
	if not db_result.ok then
		return util.Err("rebuild_fts_index: " .. db_result.error)
	end

	local db = db_result.value

	local delete_result = adapter.exec(db, "DELETE FROM nodes_fts")
	if not delete_result.ok then
		adapter.close(db)
		return util.Err("rebuild_fts_index: failed to clear FTS table: " .. delete_result.error)
	end

	local populate_sql = [[
		INSERT INTO nodes_fts (uuid, content)
		SELECT uuid, content FROM nodes
	]]

	local populate_result = adapter.exec(db, populate_sql)

	if not populate_result.ok then
		adapter.close(db)
		return util.Err("rebuild_fts_index: failed to populate FTS table: " .. populate_result.error)
	end

	local count_result = adapter.query(db, "SELECT COUNT(*) as count FROM nodes_fts")

	adapter.close(db)

	local indexed = 0
	if count_result.ok and #count_result.value > 0 then
		indexed = count_result.value[1].count or 0
	end

	return util.Ok({ indexed = indexed })
end

return M
