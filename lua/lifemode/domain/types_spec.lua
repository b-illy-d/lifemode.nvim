local types = require("lifemode.domain.types")
local util = require("lifemode.util")

describe("Node_new", function()
	describe("valid node creation", function()
		it("creates node with required fields", function()
			local meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = os.time(),
			}
			local result = types.Node_new("test content", meta)

			assert.is_true(result.ok)
			local node = result.value
			assert.equals(meta.id, node.id)
			assert.equals("test content", node.content)
			assert.equals(meta.created, node.meta.created)
		end)

		it("defaults modified to created when not provided", function()
			local meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = 1234567890,
			}
			local result = types.Node_new("test content", meta)

			assert.is_true(result.ok)
			assert.is_nil(result.value.meta.modified)
		end)

		it("preserves modified when provided", function()
			local meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = 1234567890,
				modified = 1234567999,
			}
			local result = types.Node_new("test content", meta)

			assert.is_true(result.ok)
			assert.equals(1234567999, result.value.meta.modified)
		end)

		it("handles nil bounds", function()
			local meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = os.time(),
			}
			local result = types.Node_new("test content", meta, nil)

			assert.is_true(result.ok)
			assert.is_nil(result.value.bounds)
		end)

		it("copies bounds when provided", function()
			local meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = os.time(),
			}
			local bounds = { start_line = 1, end_line = 10 }
			local result = types.Node_new("test content", meta, bounds)

			assert.is_true(result.ok)
			assert.equals(1, result.value.bounds.start_line)
			assert.equals(10, result.value.bounds.end_line)
		end)
	end)

	describe("UUID validation", function()
		it("accepts valid UUID v4", function()
			local meta = {
				id = "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
				created = os.time(),
			}
			local result = types.Node_new("test", meta)

			assert.is_true(result.ok)
		end)

		it("rejects uppercase UUID", function()
			local meta = {
				id = "A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D",
				created = os.time(),
			}
			local result = types.Node_new("test", meta)

			assert.is_false(result.ok)
			assert.matches("valid UUID v4", result.error)
		end)

		it("rejects UUID v1 (version nibble 1)", function()
			local meta = {
				id = "12345678-1234-1abc-9def-123456789abc",
				created = os.time(),
			}
			local result = types.Node_new("test", meta)

			assert.is_false(result.ok)
			assert.matches("valid UUID v4", result.error)
		end)

		it("rejects UUID v3 (version nibble 3)", function()
			local meta = {
				id = "12345678-1234-3abc-9def-123456789abc",
				created = os.time(),
			}
			local result = types.Node_new("test", meta)

			assert.is_false(result.ok)
			assert.matches("valid UUID v4", result.error)
		end)

		it("rejects UUID v5 (version nibble 5)", function()
			local meta = {
				id = "12345678-1234-5abc-9def-123456789abc",
				created = os.time(),
			}
			local result = types.Node_new("test", meta)

			assert.is_false(result.ok)
			assert.matches("valid UUID v4", result.error)
		end)

		it("rejects wrong segment lengths", function()
			local meta = {
				id = "12345678-1234-4abc-9def-123456789abcde",
				created = os.time(),
			}
			local result = types.Node_new("test", meta)

			assert.is_false(result.ok)
			assert.matches("valid UUID v4", result.error)
		end)

		it("rejects non-hex characters", function()
			local meta = {
				id = "12345678-1234-4ghi-9jkl-123456789mno",
				created = os.time(),
			}
			local result = types.Node_new("test", meta)

			assert.is_false(result.ok)
			assert.matches("valid UUID v4", result.error)
		end)

		it("rejects missing dashes", function()
			local meta = {
				id = "123456781234-4abc-9def-123456789abc",
				created = os.time(),
			}
			local result = types.Node_new("test", meta)

			assert.is_false(result.ok)
			assert.matches("valid UUID v4", result.error)
		end)
	end)

	describe("error cases", function()
		it("returns Err for non-string content", function()
			local meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = os.time(),
			}
			local result = types.Node_new(123, meta)

			assert.is_false(result.ok)
			assert.matches("content must be a string", result.error)
		end)

		it("returns Err for non-table meta", function()
			local result = types.Node_new("test", "not a table")

			assert.is_false(result.ok)
			assert.matches("meta must be a table", result.error)
		end)

		it("returns Err for missing id", function()
			local meta = {
				created = os.time(),
			}
			local result = types.Node_new("test", meta)

			assert.is_false(result.ok)
			assert.matches("meta.id is required", result.error)
		end)

		it("returns Err for missing created", function()
			local meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
			}
			local result = types.Node_new("test", meta)

			assert.is_false(result.ok)
			assert.matches("meta.created is required", result.error)
		end)

		it("returns Err for non-number created", function()
			local meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = "2024-01-21",
			}
			local result = types.Node_new("test", meta)

			assert.is_false(result.ok)
			assert.matches("created must be a timestamp", result.error)
		end)

		it("returns Err for non-number modified", function()
			local meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = 1234567890,
				modified = "2024-01-21",
			}
			local result = types.Node_new("test", meta)

			assert.is_false(result.ok)
			assert.matches("modified must be a timestamp", result.error)
		end)
	end)

	describe("immutability", function()
		it("modifying source meta does not affect node", function()
			local meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = 1234567890,
				extra_field = "original",
			}
			local result = types.Node_new("test", meta)
			assert.is_true(result.ok)

			meta.extra_field = "modified"

			assert.equals("original", result.value.meta.extra_field)
		end)

		it("modifying node meta does not affect source", function()
			local meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = 1234567890,
				extra_field = "original",
			}
			local result = types.Node_new("test", meta)
			assert.is_true(result.ok)

			result.value.meta.extra_field = "modified"

			assert.equals("original", meta.extra_field)
		end)

		it("modifying source bounds does not affect node", function()
			local meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = os.time(),
			}
			local bounds = { start_line = 1, end_line = 10 }
			local result = types.Node_new("test", meta, bounds)
			assert.is_true(result.ok)

			bounds.start_line = 999

			assert.equals(1, result.value.bounds.start_line)
		end)

		it("modifying node bounds does not affect source", function()
			local meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = os.time(),
			}
			local bounds = { start_line = 1, end_line = 10 }
			local result = types.Node_new("test", meta, bounds)
			assert.is_true(result.ok)

			result.value.bounds.start_line = 999

			assert.equals(1, bounds.start_line)
		end)

		it("handles nested tables in bounds", function()
			local meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = os.time(),
			}
			local bounds = {
				start_line = 1,
				end_line = 10,
				nested = { value = 42 },
			}
			local result = types.Node_new("test", meta, bounds)
			assert.is_true(result.ok)

			bounds.nested.value = 999

			assert.equals(42, result.value.bounds.nested.value)
		end)
	end)
end)

describe("deep_copy", function()
	it("copies simple tables", function()
		local original = { a = 1, b = 2 }
		local copy = types.deep_copy(original)

		assert.equals(1, copy.a)
		assert.equals(2, copy.b)

		copy.a = 999
		assert.equals(1, original.a)
	end)

	it("copies nested tables", function()
		local original = { a = { b = { c = 1 } } }
		local copy = types.deep_copy(original)

		copy.a.b.c = 999
		assert.equals(1, original.a.b.c)
	end)

	it("handles non-table values", function()
		assert.equals(42, types.deep_copy(42))
		assert.equals("test", types.deep_copy("test"))
		assert.is_true(types.deep_copy(true))
		assert.is_nil(types.deep_copy(nil))
	end)
end)
