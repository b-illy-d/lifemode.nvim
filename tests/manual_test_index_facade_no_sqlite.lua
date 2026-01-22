-- Manual test for Index Facade WITHOUT sqlite.lua installed
-- This tests error handling when dependency is missing
-- Run with: nvim -u NONE -c "source tests/manual_test_index_facade_no_sqlite.lua"

vim.opt.runtimepath:append(".")

local index = require("lifemode.infra.index")
local node = require("lifemode.domain.node")

local function test(name, fn)
	local status, err = pcall(fn)
	if status then
		print("✓ " .. name)
	else
		print("✗ " .. name)
		print("  Error: " .. tostring(err))
	end
end

print("\n=== Running Index Facade Module Tests (No SQLite) ===\n")

test("index: insert_node requires node parameter", function()
	local result = index.insert_node(nil, "/tmp/test.md")
	assert(not result.ok, "should fail when node is nil")
	assert(result.error:match("required"), "error should mention required: " .. result.error)
end)

test("index: insert_node requires file_path parameter", function()
	local node_result = node.create("test content", {})
	assert(node_result.ok)

	local result = index.insert_node(node_result.value, "")
	assert(not result.ok, "should fail when file_path is empty")
	assert(result.error:match("required"), "error should mention required: " .. result.error)
end)

test("index: insert_node validates node", function()
	local invalid_node = { id = "not-a-uuid" }
	local result = index.insert_node(invalid_node, "/tmp/test.md")
	assert(not result.ok, "should fail with invalid node")
	assert(result.error:match("invalid node"), "error should mention invalid node: " .. result.error)
end)

test("index: update_node requires node parameter", function()
	local result = index.update_node(nil, "/tmp/test.md")
	assert(not result.ok, "should fail when node is nil")
	assert(result.error:match("required"), "error should mention required: " .. result.error)
end)

test("index: update_node requires file_path parameter", function()
	local node_result = node.create("test content", {})
	assert(node_result.ok)

	local result = index.update_node(node_result.value, "")
	assert(not result.ok, "should fail when file_path is empty")
	assert(result.error:match("required"), "error should mention required: " .. result.error)
end)

test("index: delete_node requires uuid parameter", function()
	local result = index.delete_node("")
	assert(not result.ok, "should fail when uuid is empty")
	assert(result.error:match("required"), "error should mention required: " .. result.error)
end)

test("index: delete_node validates UUID format", function()
	local result = index.delete_node("not-a-valid-uuid")
	assert(not result.ok, "should fail with invalid UUID")
	assert(result.error:match("invalid UUID"), "error should mention invalid UUID: " .. result.error)
end)

test("index: find_by_id requires uuid parameter", function()
	local result = index.find_by_id("")
	assert(not result.ok, "should fail when uuid is empty")
	assert(result.error:match("required"), "error should mention required: " .. result.error)
end)

test("index: find_by_id validates UUID format", function()
	local result = index.find_by_id("invalid-uuid")
	assert(not result.ok, "should fail with invalid UUID")
	assert(result.error:match("invalid UUID"), "error should mention invalid UUID: " .. result.error)
end)

print("\n=== All tests completed ===\n")
print("NOTE: Full integration tests require kkharji/sqlite.lua to be installed")
print("Install with: :Lazy install kkharji/sqlite.lua (or your package manager)")
vim.cmd("qa!")
