local transclude = require("lifemode.app.transclude")

describe("transclude.render_transclusions", function()
	it("handles buffer with no transclusions", function()
		local content = { "Just plain text", "No transclusion tokens here" }
		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
		vim.api.nvim_win_set_buf(0, bufnr)

		local result = transclude.render_transclusions(bufnr)

		assert.is_true(result.ok)

		local conceallevel = vim.api.nvim_get_option_value("conceallevel", { win = 0 })
		assert.equals(2, conceallevel)
	end)

	it("handles buffer with transclusion tokens", function()
		local content = { "Hello {{some-uuid}}" }
		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
		vim.api.nvim_win_set_buf(0, bufnr)

		local result = transclude.render_transclusions(bufnr)

		assert.is_true(result.ok)

		local conceallevel = vim.api.nvim_get_option_value("conceallevel", { win = 0 })
		assert.equals(2, conceallevel)
	end)

	it("validates buffer parameter", function()
		local result = transclude.render_transclusions(nil)
		assert.is_false(result.ok)
		assert.matches("bufnr must be number", result.error)

		result = transclude.render_transclusions(99999)
		assert.is_false(result.ok)
		assert.matches("buffer not valid", result.error)
	end)

	it("sets conceallevel to 2", function()
		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "test" })
		vim.api.nvim_win_set_buf(0, bufnr)

		local result = transclude.render_transclusions(bufnr)
		assert.is_true(result.ok)

		local conceallevel = vim.api.nvim_get_option_value("conceallevel", { win = 0 })
		assert.equals(2, conceallevel)
	end)
end)
