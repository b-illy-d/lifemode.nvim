local util = require("lifemode.util")

local M = {}

function M.open(db_path)
	if not db_path or db_path == "" then
		return util.Err("open: db_path is required")
	end

	local ok, sqlite = pcall(require, "sqlite.db")
	if not ok then
		return util.Err("open: sqlite.lua not installed (requires kkharji/sqlite.lua)")
	end

	local db_ok, db = pcall(function()
		return sqlite({
			uri = db_path,
			opts = {},
		})
	end)

	if not db_ok then
		return util.Err("open: failed to open database: " .. tostring(db))
	end

	return util.Ok(db)
end

function M.exec(db, sql, params)
	if not db then
		return util.Err("exec: db is required")
	end

	if not sql or sql == "" then
		return util.Err("exec: sql is required")
	end

	local ok, err = pcall(function()
		if params and #params > 0 then
			db:exec(sql, params)
		else
			db:exec(sql)
		end
	end)

	if not ok then
		return util.Err("exec: " .. tostring(err))
	end

	return util.Ok(nil)
end

function M.query(db, sql, params)
	if not db then
		return util.Err("query: db is required")
	end

	if not sql or sql == "" then
		return util.Err("query: sql is required")
	end

	local ok, rows = pcall(function()
		if params and #params > 0 then
			return db:select(sql, params)
		else
			return db:select(sql)
		end
	end)

	if not ok then
		return util.Err("query: " .. tostring(rows))
	end

	return util.Ok(rows or {})
end

function M.close(db)
	if not db then
		return util.Ok(nil)
	end

	local ok, err = pcall(function()
		db:close()
	end)

	if not ok then
		return util.Ok(nil)
	end

	return util.Ok(nil)
end

function M.transaction(db, fn)
	if not db then
		return util.Err("transaction: db is required")
	end

	if not fn then
		return util.Err("transaction: fn is required")
	end

	local begin_ok, begin_err = pcall(function()
		db:exec("BEGIN TRANSACTION")
	end)

	if not begin_ok then
		return util.Err("transaction: failed to begin: " .. tostring(begin_err))
	end

	local fn_ok, fn_result = pcall(fn)

	if not fn_ok then
		pcall(function()
			db:exec("ROLLBACK")
		end)
		return util.Err("transaction: " .. tostring(fn_result))
	end

	local commit_ok, commit_err = pcall(function()
		db:exec("COMMIT")
	end)

	if not commit_ok then
		pcall(function()
			db:exec("ROLLBACK")
		end)
		return util.Err("transaction: failed to commit: " .. tostring(commit_err))
	end

	if type(fn_result) == "table" and fn_result.ok ~= nil then
		return fn_result
	end

	return util.Ok(nil)
end

return M
