local capture = require("lifemode.app.capture")
local buf = require("lifemode.infra.nvim.buf")

local M = {}

function M.new_node()
	local result = capture.capture_node("")

	if not result.ok then
		vim.notify("[LifeMode] ERROR: " .. result.error, vim.log.levels.ERROR)
		return
	end

	local file_path = result.value.file_path

	local open_result = buf.open(file_path)
	if not open_result.ok then
		vim.notify("[LifeMode] ERROR: Failed to open file: " .. open_result.error, vim.log.levels.ERROR)
		return
	end

	vim.api.nvim_win_set_cursor(0, { 4, 0 })

	vim.notify("[LifeMode] Created new node", vim.log.levels.INFO)
end

function M.setup_commands()
	vim.api.nvim_create_user_command("LifeModeNewNode", function()
		M.new_node()
	end, { nargs = 0 })
end

return M
