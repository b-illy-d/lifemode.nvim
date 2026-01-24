local config = require("lifemode.config")
local commands = require("lifemode.ui.commands")

describe("Phase 12: Config reset and invalid vault handling", function()
	local test_vault_path

	before_each(function()
		package.loaded["lifemode.config"] = nil
		config = require("lifemode.config")
		test_vault_path = "/tmp/lifemode_test_" .. os.time() .. "_" .. math.random(100000, 999999)
		vim.fn.mkdir(test_vault_path, "p")
	end)

	after_each(function()
		if test_vault_path then
			vim.fn.delete(test_vault_path, "rf")
		end
		package.loaded["lifemode.config"] = nil
	end)

	describe("_reset_for_testing", function()
		it("resets internal config state", function()
			config.validate_config({ vault_path = test_vault_path })
			assert.equals(test_vault_path, config.get("vault_path"))

			config._reset_for_testing()

			assert.has_error(function()
				config.get("vault_path")
			end)
		end)

		it("prevents LifeModeNewNode from working after reset", function()
			config.validate_config({ vault_path = test_vault_path })
			commands.setup_commands()

			config._reset_for_testing()

			local initial_bufnr = vim.api.nvim_get_current_buf()

			commands.new_node()

			local current_bufnr = vim.api.nvim_get_current_buf()

			assert.equals(initial_bufnr, current_bufnr)

			local files_created = vim.fn.glob(test_vault_path .. "/**/*.md", false, true)
			assert.equals(0, #files_created)
		end)
	end)

	describe("LifeModeNewNode with uninitialized config", function()
		it("fails with helpful error when config not initialized", function()
			commands.setup_commands()

			local ok, err = pcall(function()
				vim.cmd("LifeModeNewNode")
			end)

			assert.is_false(ok)
			assert.is_truthy(err:match("Config not initialized") or err:match("setup"))
		end)

		it("does not create any files when config invalid", function()
			commands.setup_commands()

			local initial_buf_count = #vim.api.nvim_list_bufs()

			pcall(function()
				vim.cmd("LifeModeNewNode")
			end)

			local files_created = vim.fn.glob(test_vault_path .. "/**/*.md", false, true)
			assert.equals(0, #files_created)
		end)
	end)
end)
