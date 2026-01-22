local buf = require("lifemode.infra.nvim.buf")
local write = require("lifemode.infra.fs.write")

describe("buf", function()
	local test_file_path

	before_each(function()
		test_file_path = "/tmp/lifemode_buf_test_" .. os.time() .. "_" .. math.random(100000, 999999) .. ".md"
	end)

	after_each(function()
		if test_file_path then
			os.remove(test_file_path)
		end
	end)

	describe("open", function()
		it("opens an existing file and returns buffer number", function()
			local write_result = write.write(test_file_path, "test content\n")
			assert.is_true(write_result.ok)

			local result = buf.open(test_file_path)

			assert.is_true(result.ok)
			assert.is_number(result.value)
			assert.is_true(result.value > 0)
			assert.equals(result.value, vim.api.nvim_get_current_buf())
		end)

		it("returns error for non-existent file", function()
			local result = buf.open("/tmp/nonexistent_file_12345.md")

			assert.is_false(result.ok)
			assert.is_truthy(result.error:match("does not exist"))
		end)

		it("returns error for empty path", function()
			local result = buf.open("")

			assert.is_false(result.ok)
			assert.is_truthy(result.error:match("must be a non%-empty string"))
		end)

		it("returns error for non-string path", function()
			local result = buf.open(123)

			assert.is_false(result.ok)
			assert.is_truthy(result.error:match("must be a non%-empty string"))
		end)
	end)

	describe("get_lines", function()
		it("reads all lines from buffer", function()
			local write_result = write.write(test_file_path, "line 1\nline 2\nline 3\n")
			assert.is_true(write_result.ok)

			local open_result = buf.open(test_file_path)
			assert.is_true(open_result.ok)

			local lines = buf.get_lines(open_result.value, 0, -1)

			assert.is_table(lines)
			assert.equals(3, #lines)
			assert.equals("line 1", lines[1])
			assert.equals("line 2", lines[2])
			assert.equals("line 3", lines[3])
		end)

		it("reads partial range of lines", function()
			local write_result = write.write(test_file_path, "line 1\nline 2\nline 3\n")
			assert.is_true(write_result.ok)

			local open_result = buf.open(test_file_path)
			assert.is_true(open_result.ok)

			local lines = buf.get_lines(open_result.value, 1, 3)

			assert.is_table(lines)
			assert.equals(2, #lines)
			assert.equals("line 2", lines[1])
			assert.equals("line 3", lines[2])
		end)
	end)

	describe("set_lines", function()
		it("sets lines in buffer", function()
			local write_result = write.write(test_file_path, "old line 1\nold line 2\n")
			assert.is_true(write_result.ok)

			local open_result = buf.open(test_file_path)
			assert.is_true(open_result.ok)

			local new_lines = { "new line 1", "new line 2", "new line 3" }
			local set_result = buf.set_lines(open_result.value, 0, -1, new_lines)

			assert.is_true(set_result.ok)

			local lines = buf.get_lines(open_result.value, 0, -1)
			assert.equals(3, #lines)
			assert.equals("new line 1", lines[1])
			assert.equals("new line 2", lines[2])
			assert.equals("new line 3", lines[3])
		end)

		it("returns error for invalid buffer number", function()
			local result = buf.set_lines(999999, 0, 1, { "test" })

			assert.is_false(result.ok)
			assert.is_truthy(result.error:match("failed to set lines"))
		end)

		it("returns error when lines is not a table", function()
			local write_result = write.write(test_file_path, "test\n")
			assert.is_true(write_result.ok)

			local open_result = buf.open(test_file_path)
			assert.is_true(open_result.ok)

			local result = buf.set_lines(open_result.value, 0, 1, "not a table")

			assert.is_false(result.ok)
			assert.is_truthy(result.error:match("must be a table"))
		end)
	end)
end)
