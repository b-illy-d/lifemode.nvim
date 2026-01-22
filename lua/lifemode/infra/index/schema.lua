local util = require("lifemode.util")

local M = {}

function M.get_schema_sql()
	return {
		[[
CREATE TABLE IF NOT EXISTS schema_version (
  version INTEGER PRIMARY KEY,
  applied_at INTEGER NOT NULL
);
		]],
		[[
CREATE TABLE IF NOT EXISTS nodes (
  uuid TEXT PRIMARY KEY,
  file_path TEXT NOT NULL,
  created INTEGER,
  modified INTEGER,
  content TEXT
);
		]],
		[[
CREATE TABLE IF NOT EXISTS edges (
  from_uuid TEXT NOT NULL,
  to_uuid TEXT NOT NULL,
  edge_type TEXT NOT NULL,
  PRIMARY KEY (from_uuid, to_uuid, edge_type)
);
		]],
		[[
CREATE VIRTUAL TABLE IF NOT EXISTS nodes_fts USING fts5(
  content,
  uuid UNINDEXED
);
		]],
		[[
CREATE INDEX IF NOT EXISTS idx_edges_from ON edges(from_uuid);
		]],
		[[
CREATE INDEX IF NOT EXISTS idx_edges_to ON edges(to_uuid);
		]],
		[[
INSERT INTO schema_version (version, applied_at)
VALUES (2, strftime('%s', 'now'))
ON CONFLICT DO NOTHING;
		]],
	}
end

function M.init_db(db_path)
	if not db_path or db_path == "" then
		return util.Err("init_db: db_path is required")
	end

	local dir = vim.fn.fnamemodify(db_path, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		return util.Err("init_db: database directory does not exist: " .. dir)
	end

	local ok, sqlite = pcall(require, "sqlite.db")
	if not ok then
		return util.Err("init_db: sqlite.lua not installed (requires kkharji/sqlite.lua)")
	end

	local db_ok, db = pcall(function()
		return sqlite({
			uri = db_path,
			opts = {},
		})
	end)

	if not db_ok then
		return util.Err("init_db: failed to open database: " .. tostring(db))
	end

	local pragmas = {
		"PRAGMA foreign_keys = ON;",
		"PRAGMA journal_mode = WAL;",
	}

	for _, pragma in ipairs(pragmas) do
		local pragma_ok, pragma_err = pcall(function()
			db:exec(pragma)
		end)
		if not pragma_ok then
			return util.Err("init_db: failed to set PRAGMA: " .. tostring(pragma_err))
		end
	end

	local schema_sql = M.get_schema_sql()

	for _, sql in ipairs(schema_sql) do
		local exec_ok, exec_err = pcall(function()
			db:exec(sql)
		end)
		if not exec_ok then
			return util.Err("init_db: failed to execute schema: " .. tostring(exec_err))
		end
	end

	return util.Ok(db)
end

function M.get_schema_version(db)
	if not db then
		return util.Err("get_schema_version: db is required")
	end

	local check_ok, check_result = pcall(function()
		return db:select("SELECT name FROM sqlite_master WHERE type='table' AND name='schema_version';")
	end)

	if not check_ok then
		return util.Err("get_schema_version: failed to check table existence: " .. tostring(check_result))
	end

	if not check_result or #check_result == 0 then
		return util.Ok(0)
	end

	local query_ok, version_rows = pcall(function()
		return db:select("SELECT version FROM schema_version LIMIT 1;")
	end)

	if not query_ok then
		return util.Err("get_schema_version: failed to query version: " .. tostring(version_rows))
	end

	if not version_rows or #version_rows == 0 then
		return util.Ok(0)
	end

	return util.Ok(version_rows[1].version)
end

function M.migrate(db, from_version, to_version)
	if not db then
		return util.Err("migrate: db is required")
	end

	if not from_version or not to_version then
		return util.Err("migrate: from_version and to_version are required")
	end

	if from_version > to_version then
		return util.Err("migrate: downgrade not supported")
	end

	if from_version == to_version then
		return util.Ok(nil)
	end

	return util.Err("migrate: no migration path from " .. from_version .. " to " .. to_version)
end

return M
