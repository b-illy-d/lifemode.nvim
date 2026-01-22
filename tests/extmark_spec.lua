describe("infra.nvim.extmark", function()
	local extmark = require("lifemode.infra.nvim.extmark")

	local bufnr

	before_each(function()
		bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"line 0",
			"line 1",
			"line 2",
			"line 3",
			"line 4",
		})
	end)

	after_each(function()
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end)

	describe("set", function()
		it("creates extmark with metadata", function()
			local result = extmark.set(bufnr, 1, {
				node_id = "test-uuid-123",
				node_start = 1,
				node_end = 3,
			})

			assert.is_true(result.ok)
			assert.is_number(result.value)
		end)

		it("fails with invalid bufnr", function()
			local result = extmark.set("not a number", 1, {
				node_id = "test-uuid",
				node_start = 1,
				node_end = 3,
			})

			assert.is_false(result.ok)
			assert.matches("bufnr must be a number", result.error)
		end)

		it("fails with invalid line", function()
			local result = extmark.set(bufnr, "not a number", {
				node_id = "test-uuid",
				node_start = 1,
				node_end = 3,
			})

			assert.is_false(result.ok)
			assert.matches("line must be a number", result.error)
		end)

		it("fails with missing node_id", function()
			local result = extmark.set(bufnr, 1, {
				node_start = 1,
				node_end = 3,
			})

			assert.is_false(result.ok)
			assert.matches("node_id", result.error)
		end)

		it("fails with invalid buffer", function()
			local invalid_bufnr = 9999
			local result = extmark.set(invalid_bufnr, 1, {
				node_id = "test-uuid",
				node_start = 1,
				node_end = 3,
			})

			assert.is_false(result.ok)
			assert.matches("buffer is not valid", result.error)
		end)
	end)

	describe("query", function()
		it("retrieves metadata from extmark", function()
			local set_result = extmark.set(bufnr, 2, {
				node_id = "query-test-uuid",
				node_start = 2,
				node_end = 4,
			})

			assert.is_true(set_result.ok)

			local query_result = extmark.query(bufnr, 2)

			assert.is_true(query_result.ok)
			assert.equals("query-test-uuid", query_result.value.node_id)
			assert.equals(2, query_result.value.node_start)
			assert.equals(4, query_result.value.node_end)
			assert.is_number(query_result.value.extmark_id)
		end)

		it("fails when no extmark at line", function()
			local query_result = extmark.query(bufnr, 1)

			assert.is_false(query_result.ok)
			assert.matches("no extmark found", query_result.error)
		end)

		it("fails with invalid bufnr", function()
			local result = extmark.query("not a number", 1)

			assert.is_false(result.ok)
			assert.matches("bufnr must be a number", result.error)
		end)

		it("fails with invalid buffer", function()
			local invalid_bufnr = 9999
			local result = extmark.query(invalid_bufnr, 1)

			assert.is_false(result.ok)
			assert.matches("buffer is not valid", result.error)
		end)
	end)

	describe("delete", function()
		it("removes extmark by ID", function()
			local set_result = extmark.set(bufnr, 1, {
				node_id = "delete-test-uuid",
				node_start = 1,
				node_end = 3,
			})

			assert.is_true(set_result.ok)
			local extmark_id = set_result.value

			local delete_result = extmark.delete(bufnr, extmark_id)

			assert.is_true(delete_result.ok)

			local query_result = extmark.query(bufnr, 1)
			assert.is_false(query_result.ok)
		end)

		it("fails with invalid bufnr", function()
			local result = extmark.delete("not a number", 1)

			assert.is_false(result.ok)
			assert.matches("bufnr must be a number", result.error)
		end)

		it("fails with invalid extmark_id", function()
			local result = extmark.delete(bufnr, "not a number")

			assert.is_false(result.ok)
			assert.matches("extmark_id must be a number", result.error)
		end)

		it("fails with invalid buffer", function()
			local invalid_bufnr = 9999
			local result = extmark.delete(invalid_bufnr, 1)

			assert.is_false(result.ok)
			assert.matches("buffer is not valid", result.error)
		end)
	end)

	describe("get_node_at_cursor", function()
		it("finds node at current cursor position", function()
			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { 3, 0 })

			local set_result = extmark.set(bufnr, 2, {
				node_id = "cursor-test-uuid",
				node_start = 2,
				node_end = 4,
			})

			assert.is_true(set_result.ok)

			local cursor_result = extmark.get_node_at_cursor()

			assert.is_true(cursor_result.ok)
			assert.equals("cursor-test-uuid", cursor_result.value.uuid)
			assert.equals(2, cursor_result.value.start)
			assert.equals(4, cursor_result.value["end"])
		end)

		it("fails when cursor not on extmark", function()
			vim.api.nvim_set_current_buf(bufnr)
			vim.api.nvim_win_set_cursor(0, { 1, 0 })

			local result = extmark.get_node_at_cursor()

			assert.is_false(result.ok)
			assert.matches("no extmark found", result.error)
		end)
	end)
end)
