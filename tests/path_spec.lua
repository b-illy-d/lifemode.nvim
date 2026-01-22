local path = require("lifemode.infra.fs.path")
local write = require("lifemode.infra.fs.write")
local read = require("lifemode.infra.fs.read")
local node = require("lifemode.domain.node")

describe("Path computation integration", function()
	local test_vault

	before_each(function()
		test_vault = os.tmpname()
		os.remove(test_vault)
	end)

	after_each(function()
		if test_vault and write.exists(test_vault) then
			os.execute("rm -rf " .. test_vault)
		end
	end)

	describe("date-based vault structure", function()
		it("creates date path and writes file", function()
			local timestamp = os.time({ year = 2026, month = 1, day = 22, hour = 12 })
			local date_dir = path.date_path(test_vault, timestamp)
			local file_path = date_dir .. "note.md"

			local result = write.write(file_path, "Daily note")

			assert.is_true(result.ok)
			assert.is_true(write.exists(file_path))
		end)

		it("organizes nodes by date", function()
			local jan_22 = os.time({ year = 2026, month = 1, day = 22, hour = 12 })
			local jan_23 = os.time({ year = 2026, month = 1, day = 23, hour = 12 })

			local path_22 = path.date_path(test_vault, jan_22) .. "note.md"
			local path_23 = path.date_path(test_vault, jan_23) .. "note.md"

			write.write(path_22, "Note from 22nd")
			write.write(path_23, "Note from 23rd")

			local r22 = read.read(path_22)
			local r23 = read.read(path_23)

			assert.is_true(r22.ok)
			assert.is_true(r23.ok)
			assert.equals("Note from 22nd", r22.value)
			assert.equals("Note from 23rd", r23.value)
		end)

		it("handles cross-month organization", function()
			local jan_31 = os.time({ year = 2026, month = 1, day = 31, hour = 12 })
			local feb_01 = os.time({ year = 2026, month = 2, day = 1, hour = 12 })

			local jan_path = path.date_path(test_vault, jan_31)
			local feb_path = path.date_path(test_vault, feb_01)

			assert.matches("/01%-Jan/31/$", jan_path)
			assert.matches("/02%-Feb/01/$", feb_path)
		end)
	end)

	describe("node persistence with dates", function()
		it("stores node in date-based path", function()
			local n = node.create("Daily thought")
			local timestamp = os.time({ year = 2026, month = 1, day = 22, hour = 12 })
			local date_dir = path.date_path(test_vault, timestamp)
			local file_path = date_dir .. n.value.id .. ".md"

			local markdown = node.to_markdown(n.value)
			write.write(file_path, markdown)

			local read_result = read.read(file_path)
			local parsed = node.parse(read_result.value)

			assert.is_true(parsed.ok)
			assert.equals(n.value.id, parsed.value.id)
			assert.equals(n.value.content, parsed.value.content)
		end)

		it("supports multiple nodes per day", function()
			local timestamp = os.time({ year = 2026, month = 1, day = 22, hour = 12 })
			local date_dir = path.date_path(test_vault, timestamp)

			local n1 = node.create("First thought")
			local n2 = node.create("Second thought")
			local n3 = node.create("Third thought")

			write.write(date_dir .. n1.value.id .. ".md", node.to_markdown(n1.value))
			write.write(date_dir .. n2.value.id .. ".md", node.to_markdown(n2.value))
			write.write(date_dir .. n3.value.id .. ".md", node.to_markdown(n3.value))

			assert.is_true(write.exists(date_dir .. n1.value.id .. ".md"))
			assert.is_true(write.exists(date_dir .. n2.value.id .. ".md"))
			assert.is_true(write.exists(date_dir .. n3.value.id .. ".md"))
		end)
	end)

	describe("path resolution", function()
		it("resolves node path from UUID", function()
			local uuid = "12345678-1234-4abc-9def-123456789abc"
			local relative = "2026/01-Jan/22/" .. uuid .. ".md"
			local absolute = path.resolve(test_vault, relative)

			assert.matches(test_vault, absolute)
			assert.matches(uuid:gsub("%-", "%%-"), absolute)
		end)

		it("writes to resolved path", function()
			local relative = "notes/test.md"
			local absolute = path.resolve(test_vault, relative)

			write.write(absolute, "test content")

			assert.is_true(write.exists(absolute))
		end)
	end)

	describe("today's path", function()
		it("generates path for current date", function()
			local today_path = path.date_path(test_vault, nil)
			local today = os.date("*t")

			assert.matches("/" .. today.year .. "/", today_path)
		end)

		it("can write to today's path", function()
			local today_path = path.date_path(test_vault, nil)
			local file_path = today_path .. "today.md"

			local result = write.write(file_path, "Today's note")

			assert.is_true(result.ok)
			assert.is_true(write.exists(file_path))
		end)
	end)

	describe("month transitions", function()
		it("handles all 12 months", function()
			for month = 1, 12 do
				local timestamp = os.time({ year = 2026, month = month, day = 15, hour = 12 })
				local date_path_str = path.date_path(test_vault, timestamp)

				local month_str = string.format("%02d", month)
				assert.matches("/" .. month_str, date_path_str)
			end
		end)
	end)

	describe("tilde expansion integration", function()
		it("works with home directory vault", function()
			local timestamp = os.time({ year = 2026, month = 1, day = 22, hour = 12 })
			local home_path = path.date_path("~/temp_vault", timestamp)

			assert.is_not.matches("^~/", home_path)
		end)
	end)
end)
