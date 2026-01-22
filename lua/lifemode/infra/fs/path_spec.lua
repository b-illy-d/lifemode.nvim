local path = require("lifemode.infra.fs.path")

describe("path.date_path", function()
	it("generates path with correct format", function()
		local timestamp = os.time({ year = 2026, month = 1, day = 22, hour = 12 })
		local result = path.date_path("/vault", timestamp)

		assert.matches("^/vault/2026/01%-Jan/22/$", result)
	end)

	it("handles all month abbreviations", function()
		local months = {
			{ month = 1, abbrev = "Jan" },
			{ month = 2, abbrev = "Feb" },
			{ month = 3, abbrev = "Mar" },
			{ month = 4, abbrev = "Apr" },
			{ month = 5, abbrev = "May" },
			{ month = 6, abbrev = "Jun" },
			{ month = 7, abbrev = "Jul" },
			{ month = 8, abbrev = "Aug" },
			{ month = 9, abbrev = "Sep" },
			{ month = 10, abbrev = "Oct" },
			{ month = 11, abbrev = "Nov" },
			{ month = 12, abbrev = "Dec" },
		}

		for _, m in ipairs(months) do
			local timestamp = os.time({ year = 2026, month = m.month, day = 15, hour = 12 })
			local result = path.date_path("/vault", timestamp)
			assert.matches(m.abbrev, result)
		end
	end)

	it("pads month and day with zeros", function()
		local timestamp = os.time({ year = 2026, month = 1, day = 5, hour = 12 })
		local result = path.date_path("/vault", timestamp)

		assert.matches("/2026/01%-Jan/05/$", result)
	end)

	it("handles double-digit month and day", function()
		local timestamp = os.time({ year = 2026, month = 12, day = 31, hour = 12 })
		local result = path.date_path("/vault", timestamp)

		assert.matches("/2026/12%-Dec/31/$", result)
	end)

	it("uses current date when date is nil", function()
		local result = path.date_path("/vault", nil)
		local today = os.date("*t")
		local year = today.year
		local month_padded = string.format("%02d", today.month)
		local day_padded = string.format("%02d", today.day)

		assert.matches("/" .. year .. "/" .. month_padded, result)
		assert.matches("/" .. day_padded .. "/$", result)
	end)

	it("accepts date table format", function()
		local date_table = { year = 2025, month = 6, day = 15, hour = 12 }
		local result = path.date_path("/vault", date_table)

		assert.matches("/2025/06%-Jun/15/$", result)
	end)

	it("expands tilde in vault root", function()
		local timestamp = os.time({ year = 2026, month = 1, day = 22, hour = 12 })
		local result = path.date_path("~/vault", timestamp)

		assert.is_not.matches("^~/", result)
		assert.matches("/vault/2026/01%-Jan/22/$", result)
	end)

	it("handles vault root with trailing slash", function()
		local timestamp = os.time({ year = 2026, month = 1, day = 22, hour = 12 })
		local result = path.date_path("/vault/", timestamp)

		assert.equals("/vault/2026/01-Jan/22/", result)
	end)

	it("handles vault root without trailing slash", function()
		local timestamp = os.time({ year = 2026, month = 1, day = 22, hour = 12 })
		local result = path.date_path("/vault", timestamp)

		assert.equals("/vault/2026/01-Jan/22/", result)
	end)
end)

describe("path.resolve", function()
	it("joins vault root with relative path", function()
		local result = path.resolve("/vault", "notes/file.md")

		assert.equals("/vault/notes/file.md", result)
	end)

	it("handles relative path with leading slash", function()
		local result = path.resolve("/vault", "/notes/file.md")

		assert.equals("/vault/notes/file.md", result)
	end)

	it("handles vault root with trailing slash", function()
		local result = path.resolve("/vault/", "notes/file.md")

		assert.equals("/vault/notes/file.md", result)
	end)

	it("expands tilde in vault root", function()
		local result = path.resolve("~/vault", "notes/file.md")

		assert.is_not.matches("^~/", result)
		assert.matches("/vault/notes/file.md$", result)
	end)

	it("handles deep relative paths", function()
		local result = path.resolve("/vault", "2026/01-Jan/22/node.md")

		assert.equals("/vault/2026/01-Jan/22/node.md", result)
	end)

	it("handles empty relative path", function()
		local result = path.resolve("/vault", "")

		assert.equals("/vault/", result)
	end)
end)
