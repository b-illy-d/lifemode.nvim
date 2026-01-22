local util = require("lifemode.util")
local fs_write = require("lifemode.infra.fs.write")

local M = {}

function M.open(file_path)
	if type(file_path) ~= "string" or file_path == "" then
		return util.Err("open: file_path must be a non-empty string")
	end

	if not fs_write.exists(file_path) then
		return util.Err("open: file does not exist: " .. file_path)
	end

	local success, err = pcall(function()
		vim.cmd.edit(file_path)
	end)

	if not success then
		return util.Err("open: failed to open file: " .. tostring(err))
	end

	local bufnr = vim.api.nvim_get_current_buf()
	return util.Ok(bufnr)
end

function M.get_lines(bufnr, start_line, end_line)
	return vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
end

function M.set_lines(bufnr, start_line, end_line, lines)
	if type(lines) ~= "table" then
		return util.Err("set_lines: lines must be a table")
	end

	local success, err = pcall(function()
		vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, lines)
	end)

	if not success then
		return util.Err("set_lines: failed to set lines: " .. tostring(err))
	end

	return util.Ok(nil)
end

return M
