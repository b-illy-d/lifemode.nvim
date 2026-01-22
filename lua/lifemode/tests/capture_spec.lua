local capture = require("lifemode.app.capture")
local config = require("lifemode.config")
local read = require("lifemode.infra.fs.read")

describe("capture_node", function()
	local test_vault_path

	before_each(function()
		test_vault_path = "/tmp/lifemode_test_vault_" .. os.time()
		vim.fn.mkdir(test_vault_path, "p")

		config.validate_config({ vault_path = test_vault_path })
	end)

	after_each(function()
		if test_vault_path then
			vim.fn.delete(test_vault_path, "rf")
		end
	end)

	it("creates a node with content and writes to disk", function()
		local result = capture.capture_node("test content")

		assert.is_true(result.ok)
		assert.is_not_nil(result.value.node)
		assert.is_not_nil(result.value.file_path)
		assert.equals("test content", result.value.node.content)
		assert.is_not_nil(result.value.node.meta.id)
		assert.is_not_nil(result.value.node.meta.created)
		assert.is_number(result.value.node.meta.created)

		local file_result = read.read(result.value.file_path)
		assert.is_true(file_result.ok)
		assert.is_string(file_result.value)
		assert.is_truthy(file_result.value:match("^%-%-%-"))
		assert.is_truthy(file_result.value:match("test content"))
	end)

	it("creates an empty node when no content provided", function()
		local result = capture.capture_node()

		assert.is_true(result.ok)
		assert.equals("", result.value.node.content)

		local file_result = read.read(result.value.file_path)
		assert.is_true(file_result.ok)
	end)

	it("creates file in correct date-based directory structure", function()
		local result = capture.capture_node("test")

		assert.is_true(result.ok)

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

		assert.is_truthy(result.value.file_path:match(year))
		assert.is_truthy(result.value.file_path:match(month_padded .. "%-" .. month_abbrev))
		assert.is_truthy(result.value.file_path:match("/" .. day_padded .. "/"))
	end)

	it("propagates error when initial_content is not a string", function()
		local result = capture.capture_node(123)

		assert.is_false(result.ok)
		assert.is_truthy(result.error:match("must be a string"))
	end)

	it("returns valid UUID in filename", function()
		local result = capture.capture_node("test")

		assert.is_true(result.ok)

		local uuid_pattern =
			"[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-4[0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]"
		assert.is_truthy(result.value.file_path:match(uuid_pattern .. "%.md"))
	end)
end)
