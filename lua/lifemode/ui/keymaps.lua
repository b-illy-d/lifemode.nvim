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

	if keymaps.narrow and keymaps.narrow ~= "" then
		vim.keymap.set("n", keymaps.narrow, ":LifeModeNarrow<CR>", {
			noremap = true,
			silent = true,
			desc = "LifeMode: Narrow to node at cursor",
		})
	end

	if keymaps.widen and keymaps.widen ~= "" then
		vim.keymap.set("n", keymaps.widen, ":LifeModeWiden<CR>", {
			noremap = true,
			silent = true,
			desc = "LifeMode: Widen from narrow view",
		})
	end
end

return M
