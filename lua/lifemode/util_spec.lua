local util = require("lifemode.util")

describe("Result type", function()
	describe("Ok", function()
		it("unwrap returns value", function()
			local result = util.Ok(42)
			assert.equals(42, result:unwrap())
		end)

		it("unwrap_or returns value", function()
			local result = util.Ok(42)
			assert.equals(42, result:unwrap_or(999))
		end)

		it("handles nil value", function()
			local result = util.Ok(nil)
			assert.is_nil(result:unwrap())
			assert.is_nil(result:unwrap_or(999))
		end)

		it("handles false value", function()
			local result = util.Ok(false)
			assert.is_false(result:unwrap())
			assert.is_false(result:unwrap_or(999))
		end)
	end)

	describe("Err", function()
		it("unwrap throws error", function()
			local result = util.Err("something broke")
			assert.has_error(function()
				result:unwrap()
			end, "something broke")
		end)

		it("unwrap_or returns default", function()
			local result = util.Err("something broke")
			assert.equals(999, result:unwrap_or(999))
		end)

		it("handles empty error string", function()
			local result = util.Err("")
			assert.has_error(function()
				result:unwrap()
			end)
		end)
	end)
end)

describe("uuid", function()
	it("generates valid UUID v4 format", function()
		local id = util.uuid()
		assert.matches("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$", id)
	end)

	it("uses lowercase hex only", function()
		local id = util.uuid()
		assert.equals(id, id:lower())
	end)

	it("generates unique IDs across multiple calls", function()
		local ids = {}
		for i = 1, 10 do
			ids[i] = util.uuid()
		end

		for i = 1, 10 do
			for j = i + 1, 10 do
				assert.is_not.equals(ids[i], ids[j])
			end
		end
	end)

	it("has version 4 marker", function()
		local id = util.uuid()
		local version_char = id:sub(15, 15)
		assert.equals("4", version_char)
	end)

	it("has correct segment lengths", function()
		local id = util.uuid()
		local parts = {}
		for part in id:gmatch("[^-]+") do
			table.insert(parts, part)
		end

		assert.equals(5, #parts)
		assert.equals(8, #parts[1])
		assert.equals(4, #parts[2])
		assert.equals(4, #parts[3])
		assert.equals(4, #parts[4])
		assert.equals(12, #parts[5])
	end)
end)

describe("parse_date", function()
	it("parses valid date", function()
		local result = util.parse_date("2024-01-21")
		assert.is_true(result.ok)
		assert.equals(os.time({ year = 2024, month = 1, day = 21, hour = 0, min = 0, sec = 0 }), result.value)
	end)

	it("returns Err for nil", function()
		local result = util.parse_date(nil)
		assert.is_false(result.ok)
		assert.matches("Invalid date: expected string", result.error)
	end)

	it("returns Err for non-string", function()
		local result = util.parse_date(42)
		assert.is_false(result.ok)
		assert.matches("Invalid date: expected string", result.error)
	end)

	it("returns Err for wrong format", function()
		local result = util.parse_date("01/21/2024")
		assert.is_false(result.ok)
		assert.matches("Invalid date format", result.error)
	end)

	it("returns Err for single-digit month", function()
		local result = util.parse_date("2024-1-21")
		assert.is_false(result.ok)
		assert.matches("Invalid date format", result.error)
	end)

	it("returns Err for single-digit day", function()
		local result = util.parse_date("2024-01-1")
		assert.is_false(result.ok)
		assert.matches("Invalid date format", result.error)
	end)

	it("returns Err for invalid month", function()
		local result = util.parse_date("2024-13-01")
		assert.is_false(result.ok)
		assert.matches("Invalid month", result.error)
	end)

	it("returns Err for month zero", function()
		local result = util.parse_date("2024-00-01")
		assert.is_false(result.ok)
		assert.matches("Invalid month", result.error)
	end)

	it("returns Err for invalid day", function()
		local result = util.parse_date("2024-01-32")
		assert.is_false(result.ok)
		assert.matches("Invalid day", result.error)
	end)

	it("returns Err for day zero", function()
		local result = util.parse_date("2024-01-00")
		assert.is_false(result.ok)
		assert.matches("Invalid day", result.error)
	end)

	it("handles leap year dates", function()
		local result = util.parse_date("2024-02-29")
		assert.is_true(result.ok)
	end)

	it("handles month boundaries", function()
		local result = util.parse_date("2024-12-31")
		assert.is_true(result.ok)
	end)
end)
