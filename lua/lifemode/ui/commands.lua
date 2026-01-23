local capture = require("lifemode.app.capture")
local buf = require("lifemode.infra.nvim.buf")
local narrow = require("lifemode.app.narrow")
local sidebar = require("lifemode.ui.sidebar")
local transclude = require("lifemode.app.transclude")

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

function M.narrow()
	local result = narrow.narrow_to_current()

	if not result.ok then
		vim.notify("[LifeMode] ERROR: " .. result.error, vim.log.levels.ERROR)
		return
	end

	vim.notify("[LifeMode] Narrowed to node", vim.log.levels.INFO)
end

function M.widen()
	local result = narrow.widen()

	if not result.ok then
		vim.notify("[LifeMode] ERROR: " .. result.error, vim.log.levels.ERROR)
		return
	end
end

function M.jump_context()
	local result = narrow.jump_context()

	if not result.ok then
		vim.notify("[LifeMode] ERROR: " .. result.error, vim.log.levels.ERROR)
		return
	end

	vim.notify("[LifeMode] Jumped to context", vim.log.levels.INFO)
end

function M.sidebar()
	local result = sidebar.toggle_sidebar()

	if not result.ok then
		vim.notify("[LifeMode] ERROR: " .. result.error, vim.log.levels.ERROR)
		return
	end
end

function M.refresh_transclusions()
	local bufnr = vim.api.nvim_get_current_buf()
	local result = transclude.render_transclusions(bufnr)

	if not result.ok then
		vim.notify("[LifeMode] ERROR: " .. result.error, vim.log.levels.ERROR)
		return
	end

	vim.notify("[LifeMode] Transclusions refreshed", vim.log.levels.INFO)
end

function M.setup_commands()
	vim.api.nvim_create_user_command("LifeModeNewNode", function()
		M.new_node()
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("LifeModeNarrow", function()
		M.narrow()
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("LifeModeWiden", function()
		M.widen()
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("LifeModeJumpContext", function()
		M.jump_context()
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("LifeModeSidebar", function()
		M.sidebar()
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("LifeModeRefreshTransclusions", function()
		M.refresh_transclusions()
	end, { nargs = 0 })
end

return M
