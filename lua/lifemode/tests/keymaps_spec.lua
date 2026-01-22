local keymaps = require("lifemode.ui.keymaps")
local commands = require("lifemode.ui.commands")
local config = require("lifemode.config")

describe("keymaps", function()
	local test_vault_path

	before_each(function()
		test_vault_path = "/tmp/lifemode_keymap_test_" .. os.time() .. "_" .. math.random(100000, 999999)
		vim.fn.mkdir(test_vault_path, "p")

		for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
			if map.lhs and map.lhs:match("<[Ll]eader>n") then
				pcall(vim.keymap.del, "n", map.lhs)
			end
		end
	end)

	after_each(function()
		if test_vault_path then
			vim.fn.delete(test_vault_path, "rf")
		end

		for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
			if map.lhs and map.lhs:match("<[Ll]eader>n") then
				pcall(vim.keymap.del, "n", map.lhs)
			end
		end
	end)

	describe("setup_keymaps", function()
		it("registers default new_node keymap", function()
			config.validate_config({ vault_path = test_vault_path })
			commands.setup_commands()
			keymaps.setup_keymaps()

			local found = false
			for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
				if map.rhs and type(map.rhs) == "string" and map.rhs:match("LifeModeNewNode") then
					found = true
					break
				end
			end

			assert.is_true(found, "Expected LifeModeNewNode keymap to be registered")
		end)

		it("respects custom keymap configuration", function()
			config.validate_config({
				vault_path = test_vault_path,
				keymaps = { new_node = "<leader>zz" },
			})
			commands.setup_commands()
			keymaps.setup_keymaps()

			local found = false
			for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
				if map.rhs and type(map.rhs) == "string" and map.rhs:match("LifeModeNewNode") then
					found = true
					break
				end
			end

			assert.is_true(found, "Expected LifeModeNewNode keymap with custom binding to be registered")
		end)

		it("does not register keymap when set to empty string", function()
			local count_before = 0
			for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
				if map.rhs and type(map.rhs) == "string" and map.rhs:match("LifeModeNewNode") then
					count_before = count_before + 1
				end
			end

			config.validate_config({
				vault_path = test_vault_path,
				keymaps = { new_node = "" },
			})
			commands.setup_commands()
			keymaps.setup_keymaps()

			local count_after = 0
			for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
				if map.rhs and type(map.rhs) == "string" and map.rhs:match("LifeModeNewNode") then
					count_after = count_after + 1
				end
			end

			assert.equals(count_before, count_after, "No new LifeModeNewNode keymap should be registered")
		end)
	end)
end)
