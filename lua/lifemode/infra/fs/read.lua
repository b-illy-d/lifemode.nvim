local util = require("lifemode.util")
local M = {}

function M.read(path)
	if type(path) ~= "string" or path == "" then
		return util.Err("read: path must be a non-empty string")
	end

	local file, err = io.open(path, "r")
	if not file then
		if err:match("No such file or directory") then
			return util.Err("read: file not found: " .. path)
		else
			return util.Err("read: failed to open file: " .. tostring(err))
		end
	end

	local content, read_err = file:read("*a")
	file:close()

	if not content then
		return util.Err("read: failed to read content: " .. tostring(read_err))
	end

	return util.Ok(content)
end

function M.mtime(path)
	if type(path) ~= "string" or path == "" then
		return util.Err("mtime: path must be a non-empty string")
	end

	local stat, err = vim.loop.fs_stat(path)
	if not stat then
		if err and err:match("ENOENT") then
			return util.Err("mtime: file not found: " .. path)
		else
			return util.Err("mtime: failed to get file stats: " .. tostring(err))
		end
	end

	if not stat.mtime then
		return util.Err("mtime: no modification time available")
	end

	return util.Ok(stat.mtime.sec)
end

return M
