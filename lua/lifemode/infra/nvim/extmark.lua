local util = require("lifemode.util")

local M = {}

local ns = nil

local function get_namespace()
	if not ns then
		ns = vim.api.nvim_create_namespace("lifemode_nodes")
	end
	return ns
end

function M.set(bufnr, line, metadata)
	if type(bufnr) ~= "number" then
		return util.Err("set: bufnr must be a number")
	end

	if type(line) ~= "number" then
		return util.Err("set: line must be a number")
	end

	if type(metadata) ~= "table" then
		return util.Err("set: metadata must be a table")
	end

	if not metadata.node_id or type(metadata.node_id) ~= "string" then
		return util.Err("set: metadata.node_id is required and must be a string")
	end

	if type(metadata.node_start) ~= "number" then
		return util.Err("set: metadata.node_start must be a number")
	end

	if type(metadata.node_end) ~= "number" then
		return util.Err("set: metadata.node_end must be a number")
	end

	if not vim.api.nvim_buf_is_valid(bufnr) then
		return util.Err("set: buffer is not valid")
	end

	local success, result = pcall(function()
		return vim.api.nvim_buf_set_extmark(bufnr, get_namespace(), line, 0, {
			right_gravity = true,
			undo_restore = true,
		})
	end)

	if not success then
		return util.Err("set: failed to set extmark: " .. tostring(result))
	end

	local extmark_id = result

	vim.b[bufnr]["lifemode_extmark_" .. extmark_id] = metadata

	return util.Ok(extmark_id)
end

function M.query(bufnr, line)
	if type(bufnr) ~= "number" then
		return util.Err("query: bufnr must be a number")
	end

	if type(line) ~= "number" then
		return util.Err("query: line must be a number")
	end

	if not vim.api.nvim_buf_is_valid(bufnr) then
		return util.Err("query: buffer is not valid")
	end

	local success, marks = pcall(function()
		return vim.api.nvim_buf_get_extmarks(bufnr, get_namespace(), { line, 0 }, { line, -1 }, {
			details = true,
		})
	end)

	if not success then
		return util.Err("query: failed to get extmarks: " .. tostring(marks))
	end

	if #marks == 0 then
		return util.Err("query: no extmark found at line " .. line)
	end

	local mark = marks[1]
	local extmark_id = mark[1]

	local metadata = vim.b[bufnr]["lifemode_extmark_" .. extmark_id]

	if not metadata then
		return util.Err("query: extmark found but no metadata stored")
	end

	return util.Ok({
		node_id = metadata.node_id,
		node_start = metadata.node_start,
		node_end = metadata.node_end,
		extmark_id = extmark_id,
	})
end

function M.delete(bufnr, extmark_id)
	if type(bufnr) ~= "number" then
		return util.Err("delete: bufnr must be a number")
	end

	if type(extmark_id) ~= "number" then
		return util.Err("delete: extmark_id must be a number")
	end

	if not vim.api.nvim_buf_is_valid(bufnr) then
		return util.Err("delete: buffer is not valid")
	end

	local success, err = pcall(function()
		vim.api.nvim_buf_del_extmark(bufnr, get_namespace(), extmark_id)
	end)

	if not success then
		return util.Err("delete: failed to delete extmark: " .. tostring(err))
	end

	vim.b[bufnr]["lifemode_extmark_" .. extmark_id] = nil

	return util.Ok(nil)
end

function M.get_node_at_cursor()
	local bufnr = vim.api.nvim_get_current_buf()

	if not vim.api.nvim_buf_is_valid(bufnr) then
		return util.Err("get_node_at_cursor: current buffer is not valid")
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1] - 1

	local query_result = M.query(bufnr, line)

	if not query_result.ok then
		return util.Err("get_node_at_cursor: " .. query_result.error)
	end

	local data = query_result.value

	return util.Ok({
		uuid = data.node_id,
		start = data.node_start,
		["end"] = data.node_end,
	})
end

return M
