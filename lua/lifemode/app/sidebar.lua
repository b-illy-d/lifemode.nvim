local util = require("lifemode.util")
local ui_sidebar = require("lifemode.ui.sidebar")
local extmark = require("lifemode.infra.nvim.extmark")

local M = {}

function M.refresh_if_needed()
	if not ui_sidebar.is_open() then
		return util.Ok(nil)
	end

	local node_result = extmark.get_node_at_cursor()

	if not node_result.ok then
		return util.Ok(nil)
	end

	local current_uuid = node_result.value.uuid
	local sidebar_uuid = ui_sidebar.get_current_uuid()

	if current_uuid == sidebar_uuid then
		return util.Ok(nil)
	end

	local render_result = ui_sidebar.render_sidebar(current_uuid)

	if not render_result.ok then
		vim.notify(
			"[LifeMode] WARN: Failed to refresh sidebar: " .. render_result.error,
			vim.log.levels.WARN
		)
		return util.Ok(nil)
	end

	return util.Ok(nil)
end

function M.setup_auto_update()
	vim.api.nvim_create_autocmd("CursorHold", {
		group = "LifeMode",
		pattern = "*.md",
		callback = function()
			M.refresh_if_needed()
		end,
	})

	return util.Ok(nil)
end

return M
