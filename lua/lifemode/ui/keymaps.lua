local config = require("lifemode.config")

local M = {}

function M.setup_keymaps()
	local keymaps = config.get("keymaps")

	if keymaps.new_node and keymaps.new_node ~= "" then
		vim.keymap.set("n", keymaps.new_node, ":LifeModeNewNode<CR>", {
			noremap = true,
			silent = true,
			desc = "LifeMode: Create new node",
		})
	end
end

return M
