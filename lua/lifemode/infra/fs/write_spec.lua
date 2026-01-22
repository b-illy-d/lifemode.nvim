local write = require("lifemode.infra.fs.write")

describe("write.exists", function()
	it("returns false for non-existent path", function()
		local result = write.exists("/nonexistent/path/that/does/not/exist")
		assert.is_false(result)
	end)

	it("returns false for empty string", function()
		local result = write.exists("")
		assert.is_false(result)
	end)

	it("returns false for non-string input", function()
		local result = write.exists(nil)
		assert.is_false(result)

		local result2 = write.exists(123)
		assert.is_false(result2)
	end)

	it("returns true for existing file", function()
		local temp_file = os.tmpname()
		local f = io.open(temp_file, "w")
		f:write("test")
		f:close()

		local result = write.exists(temp_file)
		assert.is_true(result)

		os.remove(temp_file)
	end)
end)

describe("write.mkdir", function()
	local test_dir

	before_each(function()
		test_dir = os.tmpname()
		os.remove(test_dir)
	end)

	after_each(function()
		if test_dir and write.exists(test_dir) then
			os.execute("rm -rf " .. test_dir)
		end
	end)

	it("creates a single directory", function()
		local result = write.mkdir(test_dir)

		assert.is_true(result.ok)
		assert.is_true(write.exists(test_dir))
	end)

	it("creates nested directories", function()
		local nested = test_dir .. "/a/b/c"
		local result = write.mkdir(nested)

		assert.is_true(result.ok)
		assert.is_true(write.exists(nested))
	end)

	it("succeeds if directory already exists", function()
		local result1 = write.mkdir(test_dir)
		assert.is_true(result1.ok)

		local result2 = write.mkdir(test_dir)
		assert.is_true(result2.ok)
	end)

	it("returns Err for empty path", function()
		local result = write.mkdir("")

		assert.is_false(result.ok)
		assert.matches("non%-empty string", result.error)
	end)

	it("returns Err for non-string path", function()
		local result = write.mkdir(nil)

		assert.is_false(result.ok)
		assert.matches("non%-empty string", result.error)
	end)
end)

describe("write.write", function()
	local test_dir
	local test_file

	before_each(function()
		test_dir = os.tmpname()
		os.remove(test_dir)
		test_file = test_dir .. "/test.txt"
	end)

	after_each(function()
		if test_dir and write.exists(test_dir) then
			os.execute("rm -rf " .. test_dir)
		end
	end)

	it("writes content to new file", function()
		local result = write.write(test_file, "test content")

		assert.is_true(result.ok)
		assert.is_true(write.exists(test_file))

		local f = io.open(test_file, "r")
		local content = f:read("*a")
		f:close()

		assert.equals("test content", content)
	end)

	it("creates parent directories", function()
		local nested_file = test_dir .. "/a/b/c/test.txt"
		local result = write.write(nested_file, "nested content")

		assert.is_true(result.ok)
		assert.is_true(write.exists(nested_file))
	end)

	it("overwrites existing file", function()
		local result1 = write.write(test_file, "original")
		assert.is_true(result1.ok)

		local result2 = write.write(test_file, "updated")
		assert.is_true(result2.ok)

		local f = io.open(test_file, "r")
		local content = f:read("*a")
		f:close()

		assert.equals("updated", content)
	end)

	it("writes empty content", function()
		local result = write.write(test_file, "")

		assert.is_true(result.ok)
		assert.is_true(write.exists(test_file))

		local f = io.open(test_file, "r")
		local content = f:read("*a")
		f:close()

		assert.equals("", content)
	end)

	it("writes multiline content", function()
		local content = "Line 1\nLine 2\nLine 3"
		local result = write.write(test_file, content)

		assert.is_true(result.ok)

		local f = io.open(test_file, "r")
		local read_content = f:read("*a")
		f:close()

		assert.equals(content, read_content)
	end)

	it("returns Err for empty path", function()
		local result = write.write("", "content")

		assert.is_false(result.ok)
		assert.matches("non%-empty string", result.error)
	end)

	it("returns Err for non-string path", function()
		local result = write.write(nil, "content")

		assert.is_false(result.ok)
		assert.matches("non%-empty string", result.error)
	end)

	it("returns Err for non-string content", function()
		local result = write.write(test_file, 123)

		assert.is_false(result.ok)
		assert.matches("content must be a string", result.error)
	end)
end)
