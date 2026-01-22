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

	if keymaps.jump_context and keymaps.jump_context ~= "" then
		vim.keymap.set("n", keymaps.jump_context, ":LifeModeJumpContext<CR>", {
			noremap = true,
			silent = true,
			desc = "LifeMode: Jump between narrow and context",
		})
	end

	if keymaps.sidebar and keymaps.sidebar ~= "" then
		vim.keymap.set("n", keymaps.sidebar, ":LifeModeSidebar<CR>", {
			noremap = true,
			silent = true,
			desc = "LifeMode: Toggle sidebar",
		})
	end
end

return M
