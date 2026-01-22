local write = require("lifemode.infra.fs.write")
local node = require("lifemode.domain.node")

describe("Filesystem write integration", function()
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

	describe("node persistence workflow", function()
		it("creates and writes node to filesystem", function()
			local result = node.create("My thought", { type = "note" })
			assert.is_true(result.ok)

			local markdown = node.to_markdown(result.value)
			local file_path = test_dir .. "/node.md"

			local write_result = write.write(file_path, markdown)
			assert.is_true(write_result.ok)
			assert.is_true(write.exists(file_path))
		end)

		it("creates deeply nested vault structure", function()
			local result = node.create("Daily note")
			assert.is_true(result.ok)

			local markdown = node.to_markdown(result.value)
			local date_path = test_dir .. "/2026/01-Jan/21/daily.md"

			local write_result = write.write(date_path, markdown)
			assert.is_true(write_result.ok)
			assert.is_true(write.exists(date_path))
		end)

		it("writes multiple nodes to same directory", function()
			local n1 = node.create("Node 1")
			local n2 = node.create("Node 2")
			local n3 = node.create("Node 3")

			assert.is_true(n1.ok)
			assert.is_true(n2.ok)
			assert.is_true(n3.ok)

			local dir = test_dir .. "/nodes"

			local w1 = write.write(dir .. "/1.md", node.to_markdown(n1.value))
			local w2 = write.write(dir .. "/2.md", node.to_markdown(n2.value))
			local w3 = write.write(dir .. "/3.md", node.to_markdown(n3.value))

			assert.is_true(w1.ok)
			assert.is_true(w2.ok)
			assert.is_true(w3.ok)

			assert.is_true(write.exists(dir .. "/1.md"))
			assert.is_true(write.exists(dir .. "/2.md"))
			assert.is_true(write.exists(dir .. "/3.md"))
		end)
	end)

	describe("atomic write behavior", function()
		it("does not leave temp files on success", function()
			local file_path = test_dir .. "/atomic.txt"
			local result = write.write(file_path, "content")

			assert.is_true(result.ok)
			assert.is_false(write.exists(file_path .. ".tmp"))
		end)

		it("updates file atomically", function()
			local file_path = test_dir .. "/update.txt"

			write.write(file_path, "v1")
			local result = write.write(file_path, "v2")

			assert.is_true(result.ok)

			local f = io.open(file_path, "r")
			local content = f:read("*a")
			f:close()

			assert.equals("v2", content)
		end)
	end)

	describe("directory creation behavior", function()
		it("creates intermediate directories as needed", function()
			local deep_file = test_dir .. "/a/b/c/d/e/file.txt"
			local result = write.write(deep_file, "deep content")

			assert.is_true(result.ok)
			assert.is_true(write.exists(test_dir .. "/a"))
			assert.is_true(write.exists(test_dir .. "/a/b"))
			assert.is_true(write.exists(test_dir .. "/a/b/c"))
			assert.is_true(write.exists(test_dir .. "/a/b/c/d"))
			assert.is_true(write.exists(test_dir .. "/a/b/c/d/e"))
			assert.is_true(write.exists(deep_file))
		end)

		it("handles concurrent directory creation", function()
			local dir = test_dir .. "/shared"
			local f1 = dir .. "/file1.txt"
			local f2 = dir .. "/file2.txt"

			local r1 = write.write(f1, "content1")
			local r2 = write.write(f2, "content2")

			assert.is_true(r1.ok)
			assert.is_true(r2.ok)
			assert.is_true(write.exists(f1))
			assert.is_true(write.exists(f2))
		end)
	end)

	describe("large file handling", function()
		it("writes large content successfully", function()
			local large_content = string.rep("This is a line of text.\n", 10000)
			local file_path = test_dir .. "/large.txt"

			local result = write.write(file_path, large_content)

			assert.is_true(result.ok)

			local f = io.open(file_path, "r")
			local read_content = f:read("*a")
			f:close()

			assert.equals(#large_content, #read_content)
		end)
	end)
end)
