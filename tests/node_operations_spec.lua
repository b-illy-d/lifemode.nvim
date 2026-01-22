local node = require("lifemode.domain.node")

describe("Node operations integration", function()
	describe("create and serialize workflow", function()
		it("creates node and serializes to markdown", function()
			local result = node.create("My first thought")
			assert.is_true(result.ok)

			local markdown = node.to_markdown(result.value)
			assert.matches("^%-%-%-\n", markdown)
			assert.matches("\n%-%-%-\nMy first thought$", markdown)
			assert.matches("id: [0-9a-f]", markdown)
			assert.matches("created: %d+", markdown)
		end)

		it("creates node with custom meta and serializes", function()
			local meta = {
				type = "task",
				status = "in_progress",
				tags = { "work", "urgent" },
			}
			local result = node.create("Complete project documentation", meta)
			assert.is_true(result.ok)

			local markdown = node.to_markdown(result.value)
			assert.matches("type: task", markdown)
			assert.matches("status: in_progress", markdown)
			assert.matches("Complete project documentation", markdown)
		end)

		it("round-trip preserves content", function()
			local original_content = "# Heading\n\nParagraph with **bold** and *italic*."
			local result = node.create(original_content)
			assert.is_true(result.ok)

			local markdown = node.to_markdown(result.value)
			assert.matches(original_content:gsub("%p", "%%%1") .. "$", markdown)
		end)
	end)

	describe("validate workflow", function()
		it("validates freshly created node", function()
			local result = node.create("test content")
			assert.is_true(result.ok)

			local validation = node.validate(result.value)
			assert.is_true(validation.ok)
		end)

		it("detects invalid node structure", function()
			local invalid_node = {
				id = "not-a-uuid",
				content = "test",
				meta = { id = "not-a-uuid", created = "not-a-timestamp" },
			}

			local validation = node.validate(invalid_node)
			assert.is_false(validation.ok)
		end)
	end)

	describe("multiple nodes workflow", function()
		it("creates multiple distinct nodes", function()
			local result1 = node.create("First node")
			local result2 = node.create("Second node")
			local result3 = node.create("Third node")

			assert.is_true(result1.ok)
			assert.is_true(result2.ok)
			assert.is_true(result3.ok)

			assert.is_not.equals(result1.value.id, result2.value.id)
			assert.is_not.equals(result2.value.id, result3.value.id)
			assert.is_not.equals(result1.value.id, result3.value.id)
		end)

		it("serializes multiple nodes independently", function()
			local result1 = node.create("Node one", { type = "note" })
			local result2 = node.create("Node two", { type = "task" })

			local md1 = node.to_markdown(result1.value)
			local md2 = node.to_markdown(result2.value)

			assert.matches("type: note", md1)
			assert.matches("type: task", md2)
			assert.matches("Node one", md1)
			assert.matches("Node two", md2)
		end)
	end)

	describe("timestamp behavior", function()
		it("sets created timestamp to current time", function()
			local before = os.time()
			local result = node.create("test")
			local after = os.time()

			assert.is_true(result.ok)
			assert.is_true(result.value.meta.created >= before)
			assert.is_true(result.value.meta.created <= after)
		end)

		it("defaults modified to created", function()
			local result = node.create("test")
			assert.is_true(result.ok)
			assert.equals(result.value.meta.created, result.value.meta.modified)
		end)

		it("allows manual modified timestamp", function()
			local created = os.time() - 3600
			local modified = os.time()
			local meta = { created = created, modified = modified }

			local result = node.create("test", meta)
			assert.is_true(result.ok)
			assert.equals(created, result.value.meta.created)
			assert.equals(modified, result.value.meta.modified)
		end)
	end)

	describe("edge cases", function()
		it("handles empty content", function()
			local result = node.create("")
			assert.is_true(result.ok)

			local markdown = node.to_markdown(result.value)
			assert.matches("\n%-%-%-\n$", markdown)
		end)

		it("handles very long content", function()
			local long_content = string.rep("This is a long line. ", 1000)
			local result = node.create(long_content)
			assert.is_true(result.ok)

			local markdown = node.to_markdown(result.value)
			assert.matches(long_content:sub(1, 50):gsub("%p", "%%%1"), markdown)
		end)

		it("handles special characters in content", function()
			local special = "Content with @#$%^&*()[]{}|\\:;\"'<>?,./`~"
			local result = node.create(special)
			assert.is_true(result.ok)

			local markdown = node.to_markdown(result.value)
			assert.matches(special:gsub("%p", "%%%1"), markdown)
		end)

		it("handles nested meta tables", function()
			local meta = {
				tags = { "tag1", "tag2" },
				settings = {
					color = "blue",
					priority = 5,
				},
			}
			local result = node.create("test", meta)
			assert.is_true(result.ok)

			local markdown = node.to_markdown(result.value)
			assert.is_not_nil(markdown)
		end)
	end)

	describe("parsing workflow", function()
		it("parses markdown back to node", function()
			local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
created: 1234567890
modified: 1234567890
type: note
---
This is test content]]

			local result = node.parse(markdown)

			assert.is_true(result.ok)
			assert.equals("12345678-1234-4abc-9def-123456789abc", result.value.id)
			assert.equals(1234567890, result.value.meta.created)
			assert.equals("note", result.value.meta.type)
			assert.equals("This is test content", result.value.content)
		end)

		it("round-trips node through serialize and parse", function()
			local original = node.create("Original content", { type = "task", status = "todo" })
			assert.is_true(original.ok)

			local markdown = node.to_markdown(original.value)
			local parsed = node.parse(markdown)

			assert.is_true(parsed.ok)
			assert.equals(original.value.content, parsed.value.content)
			assert.equals(original.value.id, parsed.value.id)
			assert.equals(original.value.meta.type, parsed.value.meta.type)
			assert.equals(original.value.meta.status, parsed.value.meta.status)
		end)

		it("handles multiple round-trips", function()
			local r1 = node.create("Content v1")
			local md1 = node.to_markdown(r1.value)
			local r2 = node.parse(md1)
			local md2 = node.to_markdown(r2.value)
			local r3 = node.parse(md2)

			assert.is_true(r1.ok)
			assert.is_true(r2.ok)
			assert.is_true(r3.ok)
			assert.equals(r1.value.content, r3.value.content)
			assert.equals(r1.value.id, r3.value.id)
		end)
	end)

	describe("parsing error handling", function()
		it("detects missing frontmatter", function()
			local result = node.parse("Just plain text")

			assert.is_false(result.ok)
			assert.matches("Missing frontmatter", result.error)
		end)

		it("detects malformed frontmatter", function()
			local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
created: 1234567890
no closing delimiter]]

			local result = node.parse(markdown)

			assert.is_false(result.ok)
			assert.matches("Missing frontmatter closing delimiter", result.error)
		end)

		it("detects missing required fields", function()
			local markdown = [[---
type: note
---
content]]

			local result = node.parse(markdown)

			assert.is_false(result.ok)
			assert.matches("Missing required field", result.error)
		end)
	end)
end)
