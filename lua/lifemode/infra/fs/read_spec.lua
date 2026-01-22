local read = require("lifemode.infra.fs.read")
local write = require("lifemode.infra.fs.write")

describe("read.read", function()
	local test_file

	before_each(function()
		test_file = os.tmpname()
	end)

	after_each(function()
		if test_file and write.exists(test_file) then
			os.remove(test_file)
		end
	end)

	it("reads content from existing file", function()
		local f = io.open(test_file, "w")
		f:write("test content")
		f:close()

		local result = read.read(test_file)

		assert.is_true(result.ok)
		assert.equals("test content", result.value)
	end)

	it("reads empty file", function()
		local f = io.open(test_file, "w")
		f:close()

		local result = read.read(test_file)

		assert.is_true(result.ok)
		assert.equals("", result.value)
	end)

	it("reads multiline content", function()
		local content = "Line 1\nLine 2\nLine 3"
		local f = io.open(test_file, "w")
		f:write(content)
		f:close()

		local result = read.read(test_file)

		assert.is_true(result.ok)
		assert.equals(content, result.value)
	end)

	it("reads large content", function()
		local large = string.rep("test ", 10000)
		local f = io.open(test_file, "w")
		f:write(large)
		f:close()

		local result = read.read(test_file)

		assert.is_true(result.ok)
		assert.equals(#large, #result.value)
	end)

	it("returns Err for non-existent file", function()
		local result = read.read("/nonexistent/file/path.txt")

		assert.is_false(result.ok)
		assert.matches("file not found", result.error)
	end)

	it("returns Err for empty path", function()
		local result = read.read("")

		assert.is_false(result.ok)
		assert.matches("non%-empty string", result.error)
	end)

	it("returns Err for non-string path", function()
		local result = read.read(nil)

		assert.is_false(result.ok)
		assert.matches("non%-empty string", result.error)
	end)
end)

describe("read.mtime", function()
	local test_file

	before_each(function()
		test_file = os.tmpname()
		local f = io.open(test_file, "w")
		f:write("test")
		f:close()
	end)

	after_each(function()
		if test_file and write.exists(test_file) then
			os.remove(test_file)
		end
	end)

	it("returns modification time for existing file", function()
		local result = read.mtime(test_file)

		assert.is_true(result.ok)
		assert.is_number(result.value)
		assert.is_true(result.value > 0)
	end)

	it("returns recent timestamp for new file", function()
		local before = os.time()
		local new_file = os.tmpname()
		local f = io.open(new_file, "w")
		f:write("new")
		f:close()
		local after = os.time()

		local result = read.mtime(new_file)

		assert.is_true(result.ok)
		assert.is_true(result.value >= before)
		assert.is_true(result.value <= after + 1)

		os.remove(new_file)
	end)

	it("returns different mtimes for modified file", function()
		local result1 = read.mtime(test_file)
		assert.is_true(result1.ok)

		os.execute("sleep 1")

		local f = io.open(test_file, "w")
		f:write("updated")
		f:close()

		local result2 = read.mtime(test_file)
		assert.is_true(result2.ok)
		assert.is_true(result2.value > result1.value)
	end)

	it("returns Err for non-existent file", function()
		local result = read.mtime("/nonexistent/file.txt")

		assert.is_false(result.ok)
		assert.matches("file not found", result.error)
	end)

	it("returns Err for empty path", function()
		local result = read.mtime("")

		assert.is_false(result.ok)
		assert.matches("non%-empty string", result.error)
	end)

	it("returns Err for non-string path", function()
		local result = read.mtime(nil)

		assert.is_false(result.ok)
		assert.matches("non%-empty string", result.error)
	end)
end)
