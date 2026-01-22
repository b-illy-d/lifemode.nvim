-- Manual integration test for SQLite adapter
-- Run with: nvim -u NONE -c "source tests/manual_test_sqlite_adapter.lua"

vim.opt.runtimepath:append(".")

local adapter = require("lifemode.infra.index.sqlite")
local schema = require("lifemode.infra.index.schema")
local util = require("lifemode.util")

local function test(name, fn)
	local status, err = pcall(fn)
	if status then
		print("✓ " .. name)
	else
		print("✗ " .. name)
		print("  Error: " .. tostring(err))
	end
end

print("\n=== Running SQLite Adapter Module Tests ===\n")

test("adapter: open database", function()
	local temp_db = "/tmp/test_adapter_open.db"
	os.remove(temp_db)

	local init_result = schema.init_db(temp_db)
	assert(init_result.ok, "schema init should succeed: " .. tostring(init_result.error))
	init_result.value:close()

	local open_result = adapter.open(temp_db)
	assert(open_result.ok, "open should succeed: " .. tostring(open_result.error))

	local db = open_result.value
	assert(db, "should return database connection")

	adapter.close(db)
	os.remove(temp_db)
end)

test("adapter: exec INSERT statement", function()
	local temp_db = "/tmp/test_adapter_exec.db"
	os.remove(temp_db)

	schema.init_db(temp_db).value:close()

	local db = adapter.open(temp_db).value

	local exec_result = adapter.exec(db, [[
		INSERT INTO nodes (uuid, file_path, created, modified, content)
		VALUES (?, ?, ?, ?, ?)
	]], { "test-uuid", "/tmp/test.md", 1234567890, 1234567890, "test content" })

	assert(exec_result.ok, "exec should succeed: " .. tostring(exec_result.error))

	adapter.close(db)
	os.remove(temp_db)
end)

test("adapter: query SELECT statement", function()
	local temp_db = "/tmp/test_adapter_query.db"
	os.remove(temp_db)

	schema.init_db(temp_db).value:close()

	local db = adapter.open(temp_db).value

	adapter.exec(db, "INSERT INTO nodes VALUES (?, ?, ?, ?, ?)", { "uuid1", "/tmp/1.md", 100, 100, "content1" })
	adapter.exec(db, "INSERT INTO nodes VALUES (?, ?, ?, ?, ?)", { "uuid2", "/tmp/2.md", 200, 200, "content2" })

	local query_result = adapter.query(db, "SELECT * FROM nodes WHERE uuid = ?", { "uuid1" })
	assert(query_result.ok, "query should succeed: " .. tostring(query_result.error))

	local rows = query_result.value
	assert(#rows == 1, "should return 1 row, got: " .. #rows)
	assert(rows[1].uuid == "uuid1", "should return correct row")
	assert(rows[1].content == "content1", "should return correct content")

	adapter.close(db)
	os.remove(temp_db)
end)

test("adapter: query returns empty result", function()
	local temp_db = "/tmp/test_adapter_empty.db"
	os.remove(temp_db)

	schema.init_db(temp_db).value:close()

	local db = adapter.open(temp_db).value

	local query_result = adapter.query(db, "SELECT * FROM nodes WHERE uuid = ?", { "nonexistent" })
	assert(query_result.ok, "query should succeed even with no results")
	assert(#query_result.value == 0, "should return empty table")

	adapter.close(db)
	os.remove(temp_db)
end)

test("adapter: exec with SQL error", function()
	local temp_db = "/tmp/test_adapter_error.db"
	os.remove(temp_db)

	schema.init_db(temp_db).value:close()

	local db = adapter.open(temp_db).value

	local exec_result = adapter.exec(db, "INSERT INTO nonexistent_table VALUES (?)", { "value" })
	assert(not exec_result.ok, "should fail with SQL error")
	assert(
		exec_result.error:match("exec") or exec_result.error:match("table") or exec_result.error:match("no such"),
		"error should mention problem: " .. exec_result.error
	)

	adapter.close(db)
	os.remove(temp_db)
end)

test("adapter: transaction commits on success", function()
	local temp_db = "/tmp/test_adapter_tx_commit.db"
	os.remove(temp_db)

	schema.init_db(temp_db).value:close()

	local db = adapter.open(temp_db).value

	local tx_result = adapter.transaction(db, function()
		adapter.exec(
			db,
			"INSERT INTO nodes VALUES (?, ?, ?, ?, ?)",
			{ "tx-uuid-1", "/tmp/tx1.md", 300, 300, "tx content 1" }
		)
		adapter.exec(
			db,
			"INSERT INTO nodes VALUES (?, ?, ?, ?, ?)",
			{ "tx-uuid-2", "/tmp/tx2.md", 400, 400, "tx content 2" }
		)
		return util.Ok(nil)
	end)

	assert(tx_result.ok, "transaction should succeed: " .. tostring(tx_result.error))

	local query_result = adapter.query(db, "SELECT COUNT(*) as count FROM nodes WHERE uuid LIKE 'tx-%'")
	assert(query_result.value[1].count == 2, "both inserts should be committed")

	adapter.close(db)
	os.remove(temp_db)
end)

test("adapter: transaction rolls back on error", function()
	local temp_db = "/tmp/test_adapter_tx_rollback.db"
	os.remove(temp_db)

	schema.init_db(temp_db).value:close()

	local db = adapter.open(temp_db).value

	local tx_result = adapter.transaction(db, function()
		adapter.exec(db, "INSERT INTO nodes VALUES (?, ?, ?, ?, ?)", { "rollback-uuid", "/tmp/rb.md", 500, 500, "content" })
		error("intentional error")
	end)

	assert(not tx_result.ok, "transaction should fail")

	local query_result = adapter.query(db, "SELECT * FROM nodes WHERE uuid = ?", { "rollback-uuid" })
	assert(#query_result.value == 0, "insert should be rolled back")

	adapter.close(db)
	os.remove(temp_db)
end)

test("adapter: close is idempotent", function()
	local temp_db = "/tmp/test_adapter_close.db"
	os.remove(temp_db)

	schema.init_db(temp_db).value:close()

	local db = adapter.open(temp_db).value

	local close1 = adapter.close(db)
	assert(close1.ok, "first close should succeed")

	local close2 = adapter.close(db)
	assert(close2.ok, "second close should succeed (idempotent)")

	os.remove(temp_db)
end)

test("adapter: exec requires db parameter", function()
	local result = adapter.exec(nil, "SELECT 1")
	assert(not result.ok, "should fail when db is nil")
	assert(result.error:match("required"), "error should mention required")
end)

test("adapter: query requires db parameter", function()
	local result = adapter.query(nil, "SELECT 1")
	assert(not result.ok, "should fail when db is nil")
	assert(result.error:match("required"), "error should mention required")
end)

test("adapter: exec requires sql parameter", function()
	local temp_db = "/tmp/test_adapter_no_sql.db"
	os.remove(temp_db)

	schema.init_db(temp_db).value:close()
	local db = adapter.open(temp_db).value

	local result = adapter.exec(db, "")
	assert(not result.ok, "should fail when sql is empty")
	assert(result.error:match("required"), "error should mention required")

	adapter.close(db)
	os.remove(temp_db)
end)

test("adapter: query with multiple rows", function()
	local temp_db = "/tmp/test_adapter_multi_rows.db"
	os.remove(temp_db)

	schema.init_db(temp_db).value:close()
	local db = adapter.open(temp_db).value

	adapter.exec(db, "INSERT INTO nodes VALUES (?, ?, ?, ?, ?)", { "uuid-a", "/tmp/a.md", 100, 100, "content a" })
	adapter.exec(db, "INSERT INTO nodes VALUES (?, ?, ?, ?, ?)", { "uuid-b", "/tmp/b.md", 200, 200, "content b" })
	adapter.exec(db, "INSERT INTO nodes VALUES (?, ?, ?, ?, ?)", { "uuid-c", "/tmp/c.md", 300, 300, "content c" })

	local query_result = adapter.query(db, "SELECT * FROM nodes ORDER BY created")
	assert(query_result.ok, "query should succeed")
	assert(#query_result.value == 3, "should return 3 rows")
	assert(query_result.value[1].uuid == "uuid-a", "first row should be uuid-a")
	assert(query_result.value[2].uuid == "uuid-b", "second row should be uuid-b")
	assert(query_result.value[3].uuid == "uuid-c", "third row should be uuid-c")

	adapter.close(db)
	os.remove(temp_db)
end)

print("\n=== All tests completed ===\n")
vim.cmd("qa!")
