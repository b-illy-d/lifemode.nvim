local config = require("lifemode.config")
local M = {}

local _initialized = false

function M.setup(opts)
	if _initialized then
		error("LifeMode already initialized. Call setup() only once.")
	end

	opts = opts or {}

	local result = config.validate_config(opts)
	if not result.ok then
		error("[LifeMode] Configuration error: " .. result.error)
	end

	vim.api.nvim_create_augroup("LifeMode", { clear = true })

	_initialized = true
end

return M
