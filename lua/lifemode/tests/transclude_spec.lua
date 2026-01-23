local transclude = require("lifemode.domain.transclude")
local util = require("lifemode.util")

describe("transclude.expand", function()
	local function make_fetch_fn(nodes)
		return function(uuid)
			local node = nodes[uuid]
			if node then
				return util.Ok(node)
			else
				return util.Ok(nil)
			end
		end
	end

	it("expands single transclusion", function()
		local nodes = {
			["uuid-b"] = { content = "World" },
		}
		local fetch_fn = make_fetch_fn(nodes)

		local content = "Hello {{uuid-b}}"
		local result = transclude.expand(content, {}, 0, 10, fetch_fn)

		assert.is_true(result.ok)
		assert.equals("Hello World", result.value)
	end)

	it("expands nested transclusions", function()
		local nodes = {
			["uuid-b"] = { content = "Middle {{uuid-c}}" },
			["uuid-c"] = { content = "End" },
		}
		local fetch_fn = make_fetch_fn(nodes)

		local content = "Start {{uuid-b}}"
		local result = transclude.expand(content, {}, 0, 10, fetch_fn)

		assert.is_true(result.ok)
		assert.equals("Start Middle End", result.value)
	end)

	it("detects cycles", function()
		local nodes = {
			["uuid-a"] = { content = "A {{uuid-b}}" },
			["uuid-b"] = { content = "B {{uuid-a}}" },
		}
		local fetch_fn = make_fetch_fn(nodes)

		local content = "Start {{uuid-a}}"
		local result = transclude.expand(content, {}, 0, 10, fetch_fn)

		assert.is_true(result.ok)
		assert.matches("⚠️ Cycle detected", result.value)
	end)

	it("enforces max depth", function()
		local nodes = {
			["uuid-1"] = { content = "{{uuid-2}}" },
			["uuid-2"] = { content = "{{uuid-3}}" },
			["uuid-3"] = { content = "{{uuid-4}}" },
			["uuid-4"] = { content = "{{uuid-5}}" },
			["uuid-5"] = { content = "{{uuid-6}}" },
			["uuid-6"] = { content = "{{uuid-7}}" },
			["uuid-7"] = { content = "{{uuid-8}}" },
			["uuid-8"] = { content = "{{uuid-9}}" },
			["uuid-9"] = { content = "{{uuid-10}}" },
			["uuid-10"] = { content = "{{uuid-11}}" },
			["uuid-11"] = { content = "End" },
		}
		local fetch_fn = make_fetch_fn(nodes)

		local content = "{{uuid-1}}"
		local result = transclude.expand(content, {}, 0, 10, fetch_fn)

		assert.is_true(result.ok)
		assert.matches("⚠️ Max depth reached", result.value)
	end)

	it("handles missing nodes", function()
		local nodes = {}
		local fetch_fn = make_fetch_fn(nodes)

		local content = "Hello {{missing-uuid}}"
		local result = transclude.expand(content, {}, 0, 10, fetch_fn)

		assert.is_true(result.ok)
		assert.matches("⚠️ Node not found: {{missing%-uuid}}", result.value)
	end)

	it("expands multiple tokens in one pass", function()
		local nodes = {
			["uuid-a"] = { content = "A" },
			["uuid-b"] = { content = "B" },
			["uuid-c"] = { content = "C" },
		}
		local fetch_fn = make_fetch_fn(nodes)

		local content = "{{uuid-a}} and {{uuid-b}} and {{uuid-c}}"
		local result = transclude.expand(content, {}, 0, 10, fetch_fn)

		assert.is_true(result.ok)
		assert.equals("A and B and C", result.value)
	end)

	it("allows same node in different branches", function()
		local nodes = {
			["uuid-a"] = { content = "{{uuid-c}}" },
			["uuid-b"] = { content = "{{uuid-c}}" },
			["uuid-c"] = { content = "Shared" },
		}
		local fetch_fn = make_fetch_fn(nodes)

		local content = "{{uuid-a}} and {{uuid-b}}"
		local result = transclude.expand(content, {}, 0, 10, fetch_fn)

		assert.is_true(result.ok)
		assert.equals("Shared and Shared", result.value)
	end)

	it("handles empty content", function()
		local nodes = {}
		local fetch_fn = make_fetch_fn(nodes)

		local result = transclude.expand("", {}, 0, 10, fetch_fn)

		assert.is_true(result.ok)
		assert.equals("", result.value)
	end)

	it("validates parameters", function()
		local fetch_fn = function()
			return util.Ok(nil)
		end

		local result = transclude.expand(nil, {}, 0, 10, fetch_fn)
		assert.is_false(result.ok)
		assert.matches("content must be string", result.error)

		result = transclude.expand("test", nil, 0, 10, fetch_fn)
		assert.is_false(result.ok)
		assert.matches("visited must be table", result.error)

		result = transclude.expand("test", {}, -1, 10, fetch_fn)
		assert.is_false(result.ok)
		assert.matches("depth must be non%-negative", result.error)

		result = transclude.expand("test", {}, 0, 0, fetch_fn)
		assert.is_false(result.ok)
		assert.matches("max_depth must be positive", result.error)

		result = transclude.expand("test", {}, 0, 10, nil)
		assert.is_false(result.ok)
		assert.matches("fetch_fn must be function", result.error)
	end)

	it("preserves text around transclusions", function()
		local nodes = {
			["uuid-x"] = { content = "MIDDLE" },
		}
		local fetch_fn = make_fetch_fn(nodes)

		local content = "Before {{uuid-x}} After"
		local result = transclude.expand(content, {}, 0, 10, fetch_fn)

		assert.is_true(result.ok)
		assert.equals("Before MIDDLE After", result.value)
	end)
end)
