local commands = require("lifemode.ui.commands")
local config = require("lifemode.config")
local read = require("lifemode.infra.fs.read")

describe("commands", function()
	local test_vault_path

	before_each(function()
		test_vault_path = "/tmp/lifemode_cmd_test_" .. os.time() .. "_" .. math.random(100000, 999999)
		vim.fn.mkdir(test_vault_path, "p")
		config.validate_config({ vault_path = test_vault_path })

		commands.setup_commands()
	end)

	after_each(function()
		if test_vault_path then
			vim.fn.delete(test_vault_path, "rf")
		end
	end)

	describe("new_node", function()
		it("creates a node file and opens it in buffer", function()
			commands.new_node()

			local current_bufnr = vim.api.nvim_get_current_buf()
			local buf_name = vim.api.nvim_buf_get_name(current_bufnr)

			assert.is_truthy(buf_name:match("%.md$"))

			local lines = vim.api.nvim_buf_get_lines(current_bufnr, 0, -1, false)
			assert.is_truthy(#lines >= 4)
			assert.equals("---", lines[1])
			assert.is_truthy(lines[2]:match("^id: ") or lines[2]:match("^created: "))
			assert.is_truthy(lines[3]:match("^created: ") or lines[3]:match("^id: ") or lines[3]:match("^modified: "))

			local cursor = vim.api.nvim_win_get_cursor(0)
			assert.equals(4, cursor[1])
			assert.equals(0, cursor[2])
		end)

		it("creates file in correct date directory structure", function()
			commands.new_node()

			local current_bufnr = vim.api.nvim_get_current_buf()
			local file_path = vim.api.nvim_buf_get_name(current_bufnr)

			local date_table = os.date("*t")
			local year = tostring(date_table.year)
			local month_padded = string.format("%02d", date_table.month)

			local month_abbrevs = {
				"Jan",
				"Feb",
				"Mar",
				"Apr",
				"May",
				"Jun",
				"Jul",
				"Aug",
				"Sep",
				"Oct",
				"Nov",
				"Dec",
			}
			local month_abbrev = month_abbrevs[date_table.month]
			local day_padded = string.format("%02d", date_table.day)

			assert.is_truthy(file_path:match(year))
			assert.is_truthy(file_path:match(month_padded .. "%-" .. month_abbrev))
			assert.is_truthy(file_path:match("/" .. day_padded .. "/"))
			assert.is_truthy(file_path:match("%.md$"))

			local file_result = read.read(file_path)
			assert.is_true(file_result.ok)
		end)
	end)

	describe("LifeModeNewNode command", function()
		it("executes successfully via command", function()
			local initial_bufnr = vim.api.nvim_get_current_buf()

			vim.cmd("LifeModeNewNode")

			local current_bufnr = vim.api.nvim_get_current_buf()
			assert.is_not_equal(initial_bufnr, current_bufnr)

			local lines = vim.api.nvim_buf_get_lines(current_bufnr, 0, 4, false)
			assert.equals(4, #lines)
			assert.equals("---", lines[1])
		end)
	end)
end)
