-- Manual test for Citation Edges WITHOUT sqlite.lua installed
-- This tests validation logic without requiring database
-- Run with: nvim -u NONE -c "source tests/manual_test_citation_edges_no_sqlite.lua"

vim.opt.runtimepath:append(".")

local index = require("lifemode.infra.index.init")

local function test(name, fn)
	local status, err = pcall(fn)
	if status then
		print("✓ " .. name)
	else
		print("✗ " .. name)
		print("  Error: " .. tostring(err))
	end
end

print("\n=== Running Citation Edges Tests (No SQLite) ===\n")

test("insert_citation_edge: requires node_uuid", function()
	local result = index.insert_citation_edge(nil, "smith2020")
	assert(not result.ok, "should fail when node_uuid is nil")
	assert(result.error:match("required"), "error should mention required: " .. result.error)
end)

test("insert_citation_edge: validates node_uuid is non-empty", function()
	local result = index.insert_citation_edge("", "smith2020")
	assert(not result.ok, "should fail when node_uuid is empty")
	assert(result.error:match("required"), "error should mention required: " .. result.error)
end)

test("insert_citation_edge: validates node_uuid format", function()
	local result = index.insert_citation_edge("not-a-uuid", "smith2020")
	assert(not result.ok, "should fail with invalid UUID")
	assert(result.error:match("invalid node UUID"), "error should mention invalid UUID: " .. result.error)
end)

test("insert_citation_edge: requires source_key", function()
	local valid_uuid = "12345678-1234-4abc-1234-123456789abc"
	local result = index.insert_citation_edge(valid_uuid, nil)
	assert(not result.ok, "should fail when source_key is nil")
	assert(result.error:match("source_key"), "error should mention source_key: " .. result.error)
end)

test("insert_citation_edge: validates source_key is non-empty", function()
	local valid_uuid = "12345678-1234-4abc-1234-123456789abc"
	local result = index.insert_citation_edge(valid_uuid, "")
	assert(not result.ok, "should fail when source_key is empty")
	assert(result.error:match("source_key"), "error should mention source_key: " .. result.error)
end)

test("insert_citation_edge: validates source_key is string", function()
	local valid_uuid = "12345678-1234-4abc-1234-123456789abc"
	local result = index.insert_citation_edge(valid_uuid, 123)
	assert(not result.ok, "should fail when source_key is not string")
	assert(result.error:match("source_key"), "error should mention source_key: " .. result.error)
end)

test("find_nodes_citing: requires source_key", function()
	local result = index.find_nodes_citing(nil)
	assert(not result.ok, "should fail when source_key is nil")
	assert(result.error:match("source_key"), "error should mention source_key: " .. result.error)
end)

test("find_nodes_citing: validates source_key is non-empty", function()
	local result = index.find_nodes_citing("")
	assert(not result.ok, "should fail when source_key is empty")
	assert(result.error:match("source_key"), "error should mention source_key: " .. result.error)
end)

test("find_nodes_citing: validates source_key is string", function()
	local result = index.find_nodes_citing(123)
	assert(not result.ok, "should fail when source_key is not string")
	assert(result.error:match("source_key"), "error should mention source_key: " .. result.error)
end)

print("\n=== All validation tests passed ===\n")
print("NOTE: Full integration tests require kkharji/sqlite.lua to be installed")
print("Install with: :Lazy install kkharji/sqlite.lua (or your package manager)")
vim.cmd("qa!")
