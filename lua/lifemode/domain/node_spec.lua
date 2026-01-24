local node = require("lifemode.domain.node")
local util = require("lifemode.util")

describe("node.create", function()
	describe("minimal arguments", function()
		it("creates node with just content", function()
			local result = node.create("test content")

			assert.is_true(result.ok)
			local n = result.value
			assert.equals("test content", n.content)
			assert.is_not_nil(n.id)
			assert.is_not_nil(n.meta.created)
			assert.is_nil(n.meta.modified)
		end)

		it("generates valid UUID v4", function()
			local result = node.create("test")

			assert.is_true(result.ok)
			local uuid = result.value.id
			assert.matches("^[0-9a-f]", uuid)
			assert.matches("%-4[0-9a-f][0-9a-f][0-9a-f]%-", uuid)
		end)

		it("generates unique UUIDs", function()
			local result1 = node.create("test1")
			local result2 = node.create("test2")

			assert.is_true(result1.ok)
			assert.is_true(result2.ok)
			assert.is_not.equals(result1.value.id, result2.value.id)
		end)
	end)

	describe("with partial meta", function()
		it("preserves provided id", function()
			local meta = { id = "12345678-1234-4abc-9def-123456789abc" }
			local result = node.create("test", meta)

			assert.is_true(result.ok)
			assert.equals("12345678-1234-4abc-9def-123456789abc", result.value.id)
		end)

		it("preserves provided created timestamp", function()
			local meta = { created = 1234567890 }
			local result = node.create("test", meta)

			assert.is_true(result.ok)
			assert.equals(1234567890, result.value.meta.created)
			assert.is_nil(result.value.meta.modified)
		end)

		it("preserves provided modified timestamp", function()
			local meta = { created = 1234567890, modified = 1234567999 }
			local result = node.create("test", meta)

			assert.is_true(result.ok)
			assert.equals(1234567999, result.value.meta.modified)
		end)

		it("preserves additional meta fields", function()
			local meta = { type = "task", status = "todo", tags = { "work", "urgent" } }
			local result = node.create("test", meta)

			assert.is_true(result.ok)
			assert.equals("task", result.value.meta.type)
			assert.equals("todo", result.value.meta.status)
			assert.is_not_nil(result.value.meta.tags)
		end)
	end)

	describe("error cases", function()
		it("returns Err for non-string content", function()
			local result = node.create(123)

			assert.is_false(result.ok)
			assert.matches("content must be a string", result.error)
		end)

		it("returns Err for nil content", function()
			local result = node.create(nil)

			assert.is_false(result.ok)
			assert.matches("content must be a string", result.error)
		end)

		it("returns Err for non-table meta", function()
			local result = node.create("test", "not a table")

			assert.is_false(result.ok)
			assert.matches("meta must be a table", result.error)
		end)

		it("returns Err for invalid UUID in meta", function()
			local meta = { id = "not-a-uuid" }
			local result = node.create("test", meta)

			assert.is_false(result.ok)
			assert.matches("valid UUID v4", result.error)
		end)

		it("returns Err for non-number created", function()
			local meta = { created = "2024-01-21" }
			local result = node.create("test", meta)

			assert.is_false(result.ok)
			assert.matches("timestamp", result.error)
		end)
	end)
end)

describe("node.validate", function()
	describe("valid nodes", function()
		it("validates node with required fields", function()
			local test_node = {
				id = "12345678-1234-4abc-9def-123456789abc",
				content = "test content",
				meta = {
					id = "12345678-1234-4abc-9def-123456789abc",
					created = 1234567890,
					modified = 1234567890,
				},
			}
			local result = node.validate(test_node)

			assert.is_true(result.ok)
		end)

		it("validates node with additional meta fields", function()
			local test_node = {
				id = "12345678-1234-4abc-9def-123456789abc",
				content = "test",
				meta = {
					id = "12345678-1234-4abc-9def-123456789abc",
					created = 1234567890,
					type = "task",
					status = "todo",
				},
			}
			local result = node.validate(test_node)

			assert.is_true(result.ok)
		end)
	end)

	describe("invalid nodes", function()
		it("returns Err for non-table", function()
			local result = node.validate("not a table")

			assert.is_false(result.ok)
			assert.matches("node must be a table", result.error)
		end)

		it("returns Err for missing id", function()
			local test_node = {
				content = "test",
				meta = { created = 1234567890 },
			}
			local result = node.validate(test_node)

			assert.is_false(result.ok)
			assert.matches("node.id is required", result.error)
		end)

		it("returns Err for non-string id", function()
			local test_node = {
				id = 123,
				content = "test",
				meta = { id = "12345678-1234-4abc-9def-123456789abc", created = 1234567890 },
			}
			local result = node.validate(test_node)

			assert.is_false(result.ok)
			assert.matches("node.id must be a string", result.error)
		end)

		it("returns Err for invalid UUID format", function()
			local test_node = {
				id = "not-a-uuid",
				content = "test",
				meta = { id = "not-a-uuid", created = 1234567890 },
			}
			local result = node.validate(test_node)

			assert.is_false(result.ok)
			assert.matches("valid UUID v4", result.error)
		end)

		it("returns Err for missing content", function()
			local test_node = {
				id = "12345678-1234-4abc-9def-123456789abc",
				meta = { id = "12345678-1234-4abc-9def-123456789abc", created = 1234567890 },
			}
			local result = node.validate(test_node)

			assert.is_false(result.ok)
			assert.matches("node.content is required", result.error)
		end)

		it("returns Err for non-string content", function()
			local test_node = {
				id = "12345678-1234-4abc-9def-123456789abc",
				content = 123,
				meta = { id = "12345678-1234-4abc-9def-123456789abc", created = 1234567890 },
			}
			local result = node.validate(test_node)

			assert.is_false(result.ok)
			assert.matches("node.content must be a string", result.error)
		end)

		it("returns Err for missing meta", function()
			local test_node = {
				id = "12345678-1234-4abc-9def-123456789abc",
				content = "test",
			}
			local result = node.validate(test_node)

			assert.is_false(result.ok)
			assert.matches("node.meta is required", result.error)
		end)

		it("returns Err for non-table meta", function()
			local test_node = {
				id = "12345678-1234-4abc-9def-123456789abc",
				content = "test",
				meta = "not a table",
			}
			local result = node.validate(test_node)

			assert.is_false(result.ok)
			assert.matches("node.meta must be a table", result.error)
		end)

		it("returns Err for missing meta.id", function()
			local test_node = {
				id = "12345678-1234-4abc-9def-123456789abc",
				content = "test",
				meta = { created = 1234567890 },
			}
			local result = node.validate(test_node)

			assert.is_false(result.ok)
			assert.matches("node.meta.id is required", result.error)
		end)

		it("returns Err for missing meta.created", function()
			local test_node = {
				id = "12345678-1234-4abc-9def-123456789abc",
				content = "test",
				meta = { id = "12345678-1234-4abc-9def-123456789abc" },
			}
			local result = node.validate(test_node)

			assert.is_false(result.ok)
			assert.matches("node.meta.created is required", result.error)
		end)

		it("returns Err for non-number created", function()
			local test_node = {
				id = "12345678-1234-4abc-9def-123456789abc",
				content = "test",
				meta = {
					id = "12345678-1234-4abc-9def-123456789abc",
					created = "2024-01-21",
				},
			}
			local result = node.validate(test_node)

			assert.is_false(result.ok)
			assert.matches("timestamp", result.error)
		end)

		it("returns Err for non-number modified", function()
			local test_node = {
				id = "12345678-1234-4abc-9def-123456789abc",
				content = "test",
				meta = {
					id = "12345678-1234-4abc-9def-123456789abc",
					created = 1234567890,
					modified = "2024-01-21",
				},
			}
			local result = node.validate(test_node)

			assert.is_false(result.ok)
			assert.matches("timestamp", result.error)
		end)
	end)
end)

describe("node.to_markdown", function()
	it("serializes node with basic frontmatter", function()
		local test_node = {
			id = "12345678-1234-4abc-9def-123456789abc",
			content = "This is my content.",
			meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = 1234567890,
				modified = 1234567890,
			},
		}

		local markdown = node.to_markdown(test_node)

		assert.matches("^%-%-%-\n", markdown)
		assert.matches("id: 12345678%-1234%-4abc%-9def%-123456789abc", markdown)
		assert.matches("created: 1234567890", markdown)
		assert.matches("modified: 1234567890", markdown)
		assert.matches("\n%-%-%-\nThis is my content%.$", markdown)
	end)

	it("serializes node with additional meta fields", function()
		local test_node = {
			id = "12345678-1234-4abc-9def-123456789abc",
			content = "Task content",
			meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = 1234567890,
				modified = 1234567890,
				type = "task",
				status = "todo",
			},
		}

		local markdown = node.to_markdown(test_node)

		assert.matches("type: task", markdown)
		assert.matches("status: todo", markdown)
	end)

	it("serializes empty content", function()
		local test_node = {
			id = "12345678-1234-4abc-9def-123456789abc",
			content = "",
			meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = 1234567890,
			},
		}

		local markdown = node.to_markdown(test_node)

		assert.matches("\n%-%-%-\n$", markdown)
	end)

	it("preserves multiline content", function()
		local test_node = {
			id = "12345678-1234-4abc-9def-123456789abc",
			content = "Line 1\nLine 2\nLine 3",
			meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = 1234567890,
			},
		}

		local markdown = node.to_markdown(test_node)

		assert.matches("Line 1\nLine 2\nLine 3$", markdown)
	end)
end)

describe("node.parse", function()
	describe("valid markdown", function()
		it("parses basic frontmatter and content", function()
			local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
created: 1234567890
modified: 1234567890
---
Test content]]

			local result = node.parse(markdown)

			assert.is_true(result.ok)
			local n = result.value
			assert.equals("12345678-1234-4abc-9def-123456789abc", n.id)
			assert.equals(1234567890, n.meta.created)
			assert.equals(1234567890, n.meta.modified)
			assert.equals("Test content", n.content)
		end)

		it("parses with additional meta fields", function()
			local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
created: 1234567890
type: task
status: todo
---
Do the thing]]

			local result = node.parse(markdown)

			assert.is_true(result.ok)
			assert.equals("task", result.value.meta.type)
			assert.equals("todo", result.value.meta.status)
		end)

		it("parses multiline content", function()
			local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
created: 1234567890
---
Line 1
Line 2
Line 3]]

			local result = node.parse(markdown)

			assert.is_true(result.ok)
			assert.equals("Line 1\nLine 2\nLine 3", result.value.content)
		end)

		it("parses empty content", function()
			local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
created: 1234567890
---
]]

			local result = node.parse(markdown)

			assert.is_true(result.ok)
			assert.equals("", result.value.content)
		end)

		it("parses boolean values", function()
			local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
created: 1234567890
archived: true
draft: false
---
content]]

			local result = node.parse(markdown)

			assert.is_true(result.ok)
			assert.is_true(result.value.meta.archived)
			assert.is_false(result.value.meta.draft)
		end)

		it("parses numeric values", function()
			local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
created: 1234567890
count: 42
rating: 4.5
---
content]]

			local result = node.parse(markdown)

			assert.is_true(result.ok)
			assert.equals(42, result.value.meta.count)
			assert.equals(4.5, result.value.meta.rating)
		end)
	end)

	describe("round-trip", function()
		it("preserves node through create -> serialize -> parse", function()
			local original_content = "Test content"
			local original_meta = {
				id = "12345678-1234-4abc-9def-123456789abc",
				created = 1234567890,
				modified = 1234567890,
				type = "note",
			}

			local create_result = node.create(original_content, original_meta)
			assert.is_true(create_result.ok)

			local markdown = node.to_markdown(create_result.value)
			local parse_result = node.parse(markdown)

			assert.is_true(parse_result.ok)
			assert.equals(original_content, parse_result.value.content)
			assert.equals(original_meta.id, parse_result.value.id)
			assert.equals(original_meta.created, parse_result.value.meta.created)
			assert.equals(original_meta.type, parse_result.value.meta.type)
		end)

		it("preserves multiline content", function()
			local multiline = "Line 1\nLine 2\nLine 3"
			local create_result = node.create(multiline)
			assert.is_true(create_result.ok)

			local markdown = node.to_markdown(create_result.value)
			local parse_result = node.parse(markdown)

			assert.is_true(parse_result.ok)
			assert.equals(multiline, parse_result.value.content)
		end)
	end)

	describe("error cases", function()
		it("returns Err for non-string input", function()
			local result = node.parse(123)

			assert.is_false(result.ok)
			assert.matches("text must be a string", result.error)
		end)

		it("returns Err for missing frontmatter", function()
			local markdown = "Just content, no frontmatter"
			local result = node.parse(markdown)

			assert.is_false(result.ok)
			assert.matches("Missing frontmatter", result.error)
		end)

		it("returns Err for missing closing delimiter", function()
			local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
created: 1234567890
content without closing delimiter]]

			local result = node.parse(markdown)

			assert.is_false(result.ok)
			assert.matches("Missing frontmatter closing delimiter", result.error)
		end)

		it("returns Err for missing id field", function()
			local markdown = [[---
created: 1234567890
---
content]]

			local result = node.parse(markdown)

			assert.is_false(result.ok)
			assert.matches("Missing required field: id", result.error)
		end)

		it("returns Err for missing created field", function()
			local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
---
content]]

			local result = node.parse(markdown)

			assert.is_false(result.ok)
			assert.matches("Missing required field: created", result.error)
		end)

		it("returns Err for invalid UUID format", function()
			local markdown = [[---
id: not-a-valid-uuid
created: 1234567890
---
content]]

			local result = node.parse(markdown)

			assert.is_false(result.ok)
			assert.matches("valid UUID v4", result.error)
		end)
	end)
end)
