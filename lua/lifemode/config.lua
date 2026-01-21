local util = require("lifemode.util")
local M = {}

M.defaults = {
	vault_path = "~/vault",
	sidebar = {
		width_percent = 30,
		position = "right",
	},
	keymaps = {
		new_node = "<leader>nc",
		narrow = "<leader>nn",
		widen = "<leader>nw",
		jump_context = "<leader>nj",
		sidebar = "<leader>ns",
	},
}

local _config = nil

local function deep_merge(defaults, user)
	local result = {}
	for k, v in pairs(defaults) do
		result[k] = v
	end

	for k, v in pairs(user or {}) do
		if type(v) == "table" and type(result[k]) == "table" then
			result[k] = deep_merge(result[k], v)
		else
			result[k] = v
		end
	end

	return result
end

local function expand_path(path)
	if not path then
		return nil
	end
	if path:sub(1, 1) == "~" then
		local home = os.getenv("HOME")
		if not home then
			return nil
		end
		return home .. path:sub(2)
	end
	return path
end

local function dir_exists(path)
	local escaped = path:gsub("'", "'\\''")
	local stat = io.popen("test -d '" .. escaped .. "' && echo 1 || echo 0")
	local result = stat:read("*a"):match("^%s*(.-)%s*$")
	stat:close()
	return result == "1"
end

function M.validate_config(user_config)
	if not user_config then
		user_config = {}
	end

	if type(user_config) ~= "table" then
		return util.Err("Config must be a table")
	end

	local merged = deep_merge(M.defaults, user_config)

	if not merged.vault_path or merged.vault_path == "" then
		return util.Err("vault_path is required")
	end

	local expanded_path = expand_path(merged.vault_path)
	if not expanded_path then
		return util.Err("Failed to expand vault_path: HOME not set")
	end

	if not dir_exists(expanded_path) then
		return util.Err("Vault directory does not exist: " .. expanded_path)
	end

	merged.vault_path = expanded_path

	_config = merged
	return util.Ok(merged)
end

function M.get(key)
	if not _config then
		error("Config not initialized. Call validate_config() first.")
	end

	if not key then
		return _config
	end

	local parts = {}
	for part in key:gmatch("[^.]+") do
		table.insert(parts, part)
	end

	local value = _config
	for _, part in ipairs(parts) do
		if type(value) ~= "table" then
			return nil
		end
		value = value[part]
	end

	return value
end

return M
