local types = require("lifemode.domain.types")

describe("Citation_new", function()
	local valid_uuid = "12345678-1234-4abc-1234-123456789abc"

	it("creates citation with location", function()
		local result = types.Citation_new("bibtex", "smith2020", "@smith2020", {
			node_id = valid_uuid,
			line = 10,
			col = 5,
		})

		assert.is_true(result.ok)
		assert.equals("bibtex", result.value.scheme)
		assert.equals("smith2020", result.value.key)
		assert.equals("@smith2020", result.value.raw)
		assert.is_not_nil(result.value.location)
		assert.equals(valid_uuid, result.value.location.node_id)
		assert.equals(10, result.value.location.line)
		assert.equals(5, result.value.location.col)
	end)

	it("creates citation without location", function()
		local result = types.Citation_new("bibtex", "smith2020", "@smith2020", nil)

		assert.is_true(result.ok)
		assert.equals("bibtex", result.value.scheme)
		assert.equals("smith2020", result.value.key)
		assert.equals("@smith2020", result.value.raw)
		assert.is_nil(result.value.location)
	end)

	it("validates scheme is non-empty string", function()
		local result = types.Citation_new("", "smith2020", "@smith2020", nil)
		assert.is_false(result.ok)
		assert.matches("scheme", result.error)

		result = types.Citation_new(nil, "smith2020", "@smith2020", nil)
		assert.is_false(result.ok)
		assert.matches("scheme", result.error)

		result = types.Citation_new(123, "smith2020", "@smith2020", nil)
		assert.is_false(result.ok)
		assert.matches("scheme", result.error)
	end)

	it("validates key is non-empty string", function()
		local result = types.Citation_new("bibtex", "", "@smith2020", nil)
		assert.is_false(result.ok)
		assert.matches("key", result.error)

		result = types.Citation_new("bibtex", nil, "@smith2020", nil)
		assert.is_false(result.ok)
		assert.matches("key", result.error)

		result = types.Citation_new("bibtex", 123, "@smith2020", nil)
		assert.is_false(result.ok)
		assert.matches("key", result.error)
	end)

	it("validates raw is non-empty string", function()
		local result = types.Citation_new("bibtex", "smith2020", "", nil)
		assert.is_false(result.ok)
		assert.matches("raw", result.error)

		result = types.Citation_new("bibtex", "smith2020", nil, nil)
		assert.is_false(result.ok)
		assert.matches("raw", result.error)

		result = types.Citation_new("bibtex", "smith2020", 123, nil)
		assert.is_false(result.ok)
		assert.matches("raw", result.error)
	end)

	it("validates location is table if provided", function()
		local result = types.Citation_new("bibtex", "smith2020", "@smith2020", "not-a-table")
		assert.is_false(result.ok)
		assert.matches("location", result.error)
	end)

	it("validates location.node_id is valid UUID", function()
		local result = types.Citation_new("bibtex", "smith2020", "@smith2020", {
			node_id = "not-a-uuid",
			line = 10,
			col = 5,
		})
		assert.is_false(result.ok)
		assert.matches("UUID", result.error)

		result = types.Citation_new("bibtex", "smith2020", "@smith2020", {
			line = 10,
			col = 5,
		})
		assert.is_false(result.ok)
		assert.matches("node_id", result.error)
	end)

	it("validates location.line is number", function()
		local result = types.Citation_new("bibtex", "smith2020", "@smith2020", {
			node_id = valid_uuid,
			line = "not-a-number",
			col = 5,
		})
		assert.is_false(result.ok)
		assert.matches("line", result.error)
	end)

	it("validates location.col is number", function()
		local result = types.Citation_new("bibtex", "smith2020", "@smith2020", {
			node_id = valid_uuid,
			line = 10,
			col = "not-a-number",
		})
		assert.is_false(result.ok)
		assert.matches("col", result.error)
	end)

	it("deep copies location to ensure immutability", function()
		local loc = {
			node_id = valid_uuid,
			line = 10,
			col = 5,
		}
		local result = types.Citation_new("bibtex", "smith2020", "@smith2020", loc)

		assert.is_true(result.ok)

		loc.line = 999

		assert.equals(10, result.value.location.line)
	end)

	it("supports various citation schemes", function()
		local schemes = { "bibtex", "bible", "summa", "custom-scheme" }

		for _, scheme in ipairs(schemes) do
			local result = types.Citation_new(scheme, "key", "@key", nil)
			assert.is_true(result.ok)
			assert.equals(scheme, result.value.scheme)
		end
	end)
end)
