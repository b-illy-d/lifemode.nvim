local util = require("lifemode.util")
local M = {}

function M.exists(path)
	if type(path) ~= "string" or path == "" then
		return false
	end

	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	return false
end

function M.mkdir(path)
	if type(path) ~= "string" or path == "" then
		return util.Err("mkdir: path must be a non-empty string")
	end

	local success, err = pcall(function()
		vim.fn.mkdir(path, "p")
	end)

	if not success then
		return util.Err("mkdir failed: " .. tostring(err))
	end

	if not M.exists(path) then
		return util.Err("mkdir failed: directory was not created")
	end

	return util.Ok(nil)
end

function M.write(path, content)
	if type(path) ~= "string" or path == "" then
		return util.Err("write: path must be a non-empty string")
	end

	if type(content) ~= "string" then
		return util.Err("write: content must be a string")
	end

	local parent = vim.fn.fnamemodify(path, ":h")
	if parent ~= "" and parent ~= "." then
		local mkdir_result = M.mkdir(parent)
		if not mkdir_result.ok then
			return util.Err("write: failed to create parent directory: " .. mkdir_result.error)
		end
	end

	local temp_path = path .. ".tmp"

	local file, open_err = io.open(temp_path, "w")
	if not file then
		return util.Err("write: failed to open temp file: " .. tostring(open_err))
	end

	local write_ok, write_err = file:write(content)
	if not write_ok then
		file:close()
		os.remove(temp_path)
		return util.Err("write: failed to write content: " .. tostring(write_err))
	end

	file:close()

	local rename_ok, rename_err = os.rename(temp_path, path)
	if not rename_ok then
		os.remove(temp_path)
		return util.Err("write: failed to rename temp file: " .. tostring(rename_err))
	end

	return util.Ok(nil)
end

return M
