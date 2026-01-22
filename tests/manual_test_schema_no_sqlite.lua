-- Manual test for SQLite schema WITHOUT sqlite.lua installed
-- This tests the module's error handling when dependency is missing
-- Run with: nvim -u NONE -c "source tests/manual_test_schema_no_sqlite.lua"

vim.opt.runtimepath:append(".")

local schema = require("lifemode.infra.index.schema")

local function test(name, fn)
	local status, err = pcall(fn)
	if status then
		print("✓ " .. name)
	else
		print("✗ " .. name)
		print("  Error: " .. tostring(err))
	end
end

print("\n=== Running Schema Module Tests (No SQLite) ===\n")

test("schema: get_schema_sql returns array of SQL statements", function()
	local sql = schema.get_schema_sql()
	assert(type(sql) == "table", "should return table")
	assert(#sql > 0, "should have SQL statements")

	local found_schema_version = false
	local found_nodes = false
	local found_edges = false
	local found_idx_from = false
	local found_idx_to = false

	for _, statement in ipairs(sql) do
		if statement:match("schema_version") then
			found_schema_version = true
		end
		if statement:match("CREATE TABLE.*nodes") then
			found_nodes = true
		end
		if statement:match("CREATE TABLE.*edges") then
			found_edges = true
		end
		if statement:match("idx_edges_from") then
			found_idx_from = true
		end
		if statement:match("idx_edges_to") then
			found_idx_to = true
		end
	end

	assert(found_schema_version, "should have schema_version table")
	assert(found_nodes, "should have nodes table")
	assert(found_edges, "should have edges table")
	assert(found_idx_from, "should have idx_edges_from index")
	assert(found_idx_to, "should have idx_edges_to index")
end)

test("schema: error when db_path is empty", function()
	local result = schema.init_db("")
	assert(not result.ok, "should fail when db_path is empty")
	assert(result.error:match("required"), "error should mention required")
end)

test("schema: error when db_path directory doesn't exist", function()
	local bad_path = "/nonexistent_test_dir_12345/db.sqlite"
	local result = schema.init_db(bad_path)
	assert(not result.ok, "should fail when directory doesn't exist")
	assert(
		result.error:match("not exist") or result.error:match("directory"),
		"error should mention directory: " .. result.error
	)
end)

test("schema: error when sqlite.lua not installed", function()
	local temp_dir = "/tmp"
	local result = schema.init_db(temp_dir .. "/test.db")
	assert(not result.ok, "should fail when sqlite.lua not installed")
	assert(result.error:match("sqlite.lua not installed"), "error should mention sqlite.lua: " .. result.error)
end)

test("schema: get_schema_version requires db parameter", function()
	local result = schema.get_schema_version(nil)
	assert(not result.ok, "should fail when db is nil")
	assert(result.error:match("required"), "error should mention required")
end)

test("schema: migrate requires parameters", function()
	local result1 = schema.migrate(nil, 1, 2)
	assert(not result1.ok, "should fail when db is nil")

	local mock_db = {}
	local result2 = schema.migrate(mock_db, nil, 2)
	assert(not result2.ok, "should fail when from_version is nil")

	local result3 = schema.migrate(mock_db, 1, nil)
	assert(not result3.ok, "should fail when to_version is nil")
end)

test("schema: migrate rejects downgrade", function()
	local mock_db = {}
	local result = schema.migrate(mock_db, 2, 1)
	assert(not result.ok, "should fail for downgrade")
	assert(result.error:match("downgrade"), "error should mention downgrade: " .. result.error)
end)

test("schema: migrate is no-op for same version", function()
	local mock_db = {}
	local result = schema.migrate(mock_db, 1, 1)
	assert(result.ok, "should succeed for same version")
end)

test("schema: migrate returns error for unknown migration path", function()
	local mock_db = {}
	local result = schema.migrate(mock_db, 1, 2)
	assert(not result.ok, "should fail for unknown migration")
	assert(result.error:match("no migration path"), "error should mention migration path")
end)

print("\n=== All tests completed ===\n")
print("NOTE: Full integration tests require kkharji/sqlite.lua to be installed")
print("Install with: :Lazy install kkharji/sqlite.lua (or your package manager)")
vim.cmd("qa!")
