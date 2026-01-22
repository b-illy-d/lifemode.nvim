-- Manual integration test for SQLite schema
-- Run with: nvim -u NONE -c "source tests/manual_test_schema.lua"

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

print("\n=== Running SQLite Schema Module Tests ===\n")

test("schema: init_db creates tables", function()
	local temp_db = "/tmp/test_lifemode_init.db"
	os.remove(temp_db)

	local result = schema.init_db(temp_db)
	assert(result.ok, "init_db should succeed: " .. tostring(result.error))

	local db = result.value

	local tables_query = [[
		SELECT name FROM sqlite_master
		WHERE type='table'
		ORDER BY name;
	]]
	local tables = db:select(tables_query)

	local table_names = {}
	for _, row in ipairs(tables) do
		table.insert(table_names, row.name)
	end

	assert(vim.tbl_contains(table_names, "schema_version"), "schema_version table should exist")
	assert(vim.tbl_contains(table_names, "nodes"), "nodes table should exist")
	assert(vim.tbl_contains(table_names, "edges"), "edges table should exist")

	db:close()
	os.remove(temp_db)
end)

test("schema: indexes are created", function()
	local temp_db = "/tmp/test_lifemode_indexes.db"
	os.remove(temp_db)

	local result = schema.init_db(temp_db)
	assert(result.ok, "init_db should succeed")

	local db = result.value

	local indexes_query = [[
		SELECT name FROM sqlite_master
		WHERE type='index'
		ORDER BY name;
	]]
	local indexes = db:select(indexes_query)

	local index_names = {}
	for _, row in ipairs(indexes) do
		table.insert(index_names, row.name)
	end

	assert(vim.tbl_contains(index_names, "idx_edges_from"), "idx_edges_from should exist")
	assert(vim.tbl_contains(index_names, "idx_edges_to"), "idx_edges_to should exist")

	db:close()
	os.remove(temp_db)
end)

test("schema: schema version is set to 1", function()
	local temp_db = "/tmp/test_lifemode_version.db"
	os.remove(temp_db)

	local result = schema.init_db(temp_db)
	assert(result.ok, "init_db should succeed")

	local db = result.value

	local version_result = schema.get_schema_version(db)
	assert(version_result.ok, "get_schema_version should succeed: " .. tostring(version_result.error))
	assert(version_result.value == 1, "schema version should be 1, got: " .. tostring(version_result.value))

	db:close()
	os.remove(temp_db)
end)

test("schema: idempotent init (run twice)", function()
	local temp_db = "/tmp/test_lifemode_idempotent.db"
	os.remove(temp_db)

	local result1 = schema.init_db(temp_db)
	assert(result1.ok, "first init_db should succeed")
	result1.value:close()

	local result2 = schema.init_db(temp_db)
	assert(result2.ok, "second init_db should succeed")

	local db = result2.value

	local version_result = schema.get_schema_version(db)
	assert(version_result.ok, "get_schema_version should succeed")
	assert(version_result.value == 1, "schema version should still be 1")

	db:close()
	os.remove(temp_db)
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

test("schema: nodes table schema is correct", function()
	local temp_db = "/tmp/test_lifemode_nodes_schema.db"
	os.remove(temp_db)

	local result = schema.init_db(temp_db)
	assert(result.ok, "init_db should succeed")

	local db = result.value

	local schema_query = [[
		SELECT sql FROM sqlite_master
		WHERE type='table' AND name='nodes';
	]]
	local schema_rows = db:select(schema_query)
	assert(#schema_rows > 0, "nodes table should exist")

	local sql = schema_rows[1].sql
	assert(sql:match("uuid TEXT PRIMARY KEY"), "uuid should be primary key")
	assert(sql:match("file_path TEXT NOT NULL"), "file_path should be NOT NULL")
	assert(sql:match("created INTEGER"), "created should be INTEGER")
	assert(sql:match("modified INTEGER"), "modified should be INTEGER")
	assert(sql:match("content TEXT"), "content should be TEXT")

	db:close()
	os.remove(temp_db)
end)

test("schema: edges table schema is correct", function()
	local temp_db = "/tmp/test_lifemode_edges_schema.db"
	os.remove(temp_db)

	local result = schema.init_db(temp_db)
	assert(result.ok, "init_db should succeed")

	local db = result.value

	local schema_query = [[
		SELECT sql FROM sqlite_master
		WHERE type='table' AND name='edges';
	]]
	local schema_rows = db:select(schema_query)
	assert(#schema_rows > 0, "edges table should exist")

	local sql = schema_rows[1].sql
	assert(sql:match("from_uuid TEXT NOT NULL"), "from_uuid should be NOT NULL")
	assert(sql:match("to_uuid TEXT NOT NULL"), "to_uuid should be NOT NULL")
	assert(sql:match("edge_type TEXT NOT NULL"), "edge_type should be NOT NULL")
	assert(sql:match("PRIMARY KEY"), "should have PRIMARY KEY")

	db:close()
	os.remove(temp_db)
end)

test("schema: get_schema_version returns 0 for fresh db without init", function()
	local temp_db = "/tmp/test_lifemode_version_zero.db"
	os.remove(temp_db)

	local sqlite = require("sqlite.db")
	local db = sqlite({ uri = temp_db })

	local version_result = schema.get_schema_version(db)
	assert(version_result.ok, "get_schema_version should succeed")
	assert(version_result.value == 0, "version should be 0 for fresh db")

	db:close()
	os.remove(temp_db)
end)

test("schema: migrate with same version is no-op", function()
	local temp_db = "/tmp/test_lifemode_migrate_noop.db"
	os.remove(temp_db)

	local result = schema.init_db(temp_db)
	assert(result.ok, "init_db should succeed")

	local db = result.value

	local migrate_result = schema.migrate(db, 1, 1)
	assert(migrate_result.ok, "migrate should succeed for same version")

	db:close()
	os.remove(temp_db)
end)

test("schema: migrate rejects downgrade", function()
	local temp_db = "/tmp/test_lifemode_migrate_downgrade.db"
	os.remove(temp_db)

	local result = schema.init_db(temp_db)
	assert(result.ok, "init_db should succeed")

	local db = result.value

	local migrate_result = schema.migrate(db, 2, 1)
	assert(not migrate_result.ok, "migrate should fail for downgrade")
	assert(migrate_result.error:match("downgrade"), "error should mention downgrade")

	db:close()
	os.remove(temp_db)
end)

print("\n=== All tests completed ===\n")
vim.cmd("qa!")
