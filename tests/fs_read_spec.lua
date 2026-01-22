local read = require("lifemode.infra.fs.read")
local write = require("lifemode.infra.fs.write")
local node = require("lifemode.domain.node")

describe("Filesystem read integration", function()
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

	describe("read and write round-trip", function()
		it("writes and reads back content", function()
			local file_path = test_dir .. "/test.txt"
			local content = "test content"

			local write_result = write.write(file_path, content)
			assert.is_true(write_result.ok)

			local read_result = read.read(file_path)
			assert.is_true(read_result.ok)
			assert.equals(content, read_result.value)
		end)

		it("preserves multiline content", function()
			local file_path = test_dir .. "/multiline.txt"
			local content = "Line 1\nLine 2\nLine 3"

			write.write(file_path, content)
			local read_result = read.read(file_path)

			assert.is_true(read_result.ok)
			assert.equals(content, read_result.value)
		end)

		it("handles empty files", function()
			local file_path = test_dir .. "/empty.txt"

			write.write(file_path, "")
			local read_result = read.read(file_path)

			assert.is_true(read_result.ok)
			assert.equals("", read_result.value)
		end)
	end)

	describe("node persistence round-trip", function()
		it("writes node and reads it back", function()
			local original = node.create("Test content", { type = "note" })
			assert.is_true(original.ok)

			local markdown = node.to_markdown(original.value)
			local file_path = test_dir .. "/node.md"

			write.write(file_path, markdown)
			local read_result = read.read(file_path)

			assert.is_true(read_result.ok)
			assert.equals(markdown, read_result.value)
		end)

		it("completes full node cycle: create → serialize → write → read → parse", function()
			local original = node.create("My thought", { type = "task", status = "todo" })
			assert.is_true(original.ok)

			local markdown = node.to_markdown(original.value)
			local file_path = test_dir .. "/cycle.md"

			local write_result = write.write(file_path, markdown)
			assert.is_true(write_result.ok)

			local read_result = read.read(file_path)
			assert.is_true(read_result.ok)

			local parsed = node.parse(read_result.value)
			assert.is_true(parsed.ok)

			assert.equals(original.value.content, parsed.value.content)
			assert.equals(original.value.id, parsed.value.id)
			assert.equals(original.value.meta.type, parsed.value.meta.type)
			assert.equals(original.value.meta.status, parsed.value.meta.status)
		end)

		it("handles vault structure with multiple nodes", function()
			local n1 = node.create("Node 1")
			local n2 = node.create("Node 2")

			local dir = test_dir .. "/vault/2026/01-Jan/22"

			write.write(dir .. "/node1.md", node.to_markdown(n1.value))
			write.write(dir .. "/node2.md", node.to_markdown(n2.value))

			local r1 = read.read(dir .. "/node1.md")
			local r2 = read.read(dir .. "/node2.md")

			assert.is_true(r1.ok)
			assert.is_true(r2.ok)

			local p1 = node.parse(r1.value)
			local p2 = node.parse(r2.value)

			assert.is_true(p1.ok)
			assert.is_true(p2.ok)
			assert.equals(n1.value.id, p1.value.id)
			assert.equals(n2.value.id, p2.value.id)
		end)
	end)

	describe("mtime tracking", function()
		it("returns mtime after write", function()
			local file_path = test_dir .. "/mtime_test.txt"

			write.write(file_path, "content")
			local mtime_result = read.mtime(file_path)

			assert.is_true(mtime_result.ok)
			assert.is_number(mtime_result.value)
		end)

		it("detects file modification", function()
			local file_path = test_dir .. "/modify_test.txt"

			write.write(file_path, "original")
			local mtime1 = read.mtime(file_path)

			os.execute("sleep 1")

			write.write(file_path, "modified")
			local mtime2 = read.mtime(file_path)

			assert.is_true(mtime1.ok)
			assert.is_true(mtime2.ok)
			assert.is_true(mtime2.value > mtime1.value)
		end)

		it("consistent mtime for unchanged file", function()
			local file_path = test_dir .. "/unchanged.txt"

			write.write(file_path, "content")
			local mtime1 = read.mtime(file_path)
			local mtime2 = read.mtime(file_path)

			assert.is_true(mtime1.ok)
			assert.is_true(mtime2.ok)
			assert.equals(mtime1.value, mtime2.value)
		end)
	end)

	describe("error handling", function()
		it("handles missing file gracefully", function()
			local result = read.read(test_dir .. "/nonexistent.txt")

			assert.is_false(result.ok)
			assert.matches("file not found", result.error)
		end)

		it("handles missing file for mtime", function()
			local result = read.mtime(test_dir .. "/nonexistent.txt")

			assert.is_false(result.ok)
			assert.matches("file not found", result.error)
		end)
	end)

	describe("special content handling", function()
		it("preserves special characters", function()
			local file_path = test_dir .. "/special.txt"
			local special = "Content with @#$%^&*()[]{}|\\:;\"'<>?,./`~"

			write.write(file_path, special)
			local read_result = read.read(file_path)

			assert.is_true(read_result.ok)
			assert.equals(special, read_result.value)
		end)

		it("preserves Unicode content", function()
			local file_path = test_dir .. "/unicode.txt"
			local unicode = "Hello 世界 🌍 Ω α β"

			write.write(file_path, unicode)
			local read_result = read.read(file_path)

			assert.is_true(read_result.ok)
			assert.equals(unicode, read_result.value)
		end)
	end)
end)
