-- Manual test for SQLite adapter WITHOUT sqlite.lua installed
-- This tests error handling when dependency is missing
-- Run with: nvim -u NONE -c "source tests/manual_test_sqlite_adapter_no_sqlite.lua"

vim.opt.runtimepath:append(".")

local adapter = require("lifemode.infra.index.sqlite")

local function test(name, fn)
	local status, err = pcall(fn)
	if status then
		print("✓ " .. name)
	else
		print("✗ " .. name)
		print("  Error: " .. tostring(err))
	end
end

print("\n=== Running SQLite Adapter Module Tests (No SQLite) ===\n")

test("adapter: open requires db_path", function()
	local result = adapter.open("")
	assert(not result.ok, "should fail when db_path is empty")
	assert(result.error:match("required"), "error should mention required")
end)

test("adapter: open without sqlite.lua returns error", function()
	local result = adapter.open("/tmp/test.db")
	assert(not result.ok, "should fail when sqlite.lua not installed")
	assert(result.error:match("sqlite.lua not installed"), "error should mention sqlite.lua: " .. result.error)
end)

test("adapter: exec requires db parameter", function()
	local result = adapter.exec(nil, "SELECT 1")
	assert(not result.ok, "should fail when db is nil")
	assert(result.error:match("required"), "error should mention required: " .. result.error)
end)

test("adapter: exec requires sql parameter", function()
	local mock_db = {}
	local result = adapter.exec(mock_db, "")
	assert(not result.ok, "should fail when sql is empty")
	assert(result.error:match("required"), "error should mention required: " .. result.error)

	local result2 = adapter.exec(mock_db, nil)
	assert(not result2.ok, "should fail when sql is nil")
	assert(result2.error:match("required"), "error should mention required: " .. result2.error)
end)

test("adapter: query requires db parameter", function()
	local result = adapter.query(nil, "SELECT 1")
	assert(not result.ok, "should fail when db is nil")
	assert(result.error:match("required"), "error should mention required: " .. result.error)
end)

test("adapter: query requires sql parameter", function()
	local mock_db = {}
	local result = adapter.query(mock_db, "")
	assert(not result.ok, "should fail when sql is empty")
	assert(result.error:match("required"), "error should mention required: " .. result.error)

	local result2 = adapter.query(mock_db, nil)
	assert(not result2.ok, "should fail when sql is nil")
	assert(result2.error:match("required"), "error should mention required: " .. result2.error)
end)

test("adapter: close handles nil gracefully", function()
	local result = adapter.close(nil)
	assert(result.ok, "close with nil should succeed (idempotent)")
end)

test("adapter: transaction requires db parameter", function()
	local result = adapter.transaction(nil, function()
		return true
	end)
	assert(not result.ok, "should fail when db is nil")
	assert(result.error:match("required"), "error should mention required: " .. result.error)
end)

test("adapter: transaction requires fn parameter", function()
	local mock_db = {}
	local result = adapter.transaction(mock_db, nil)
	assert(not result.ok, "should fail when fn is nil")
	assert(result.error:match("required"), "error should mention required: " .. result.error)
end)

print("\n=== All tests completed ===\n")
print("NOTE: Full integration tests require kkharji/sqlite.lua to be installed")
print("Install with: :Lazy install kkharji/sqlite.lua (or your package manager)")
vim.cmd("qa!")
