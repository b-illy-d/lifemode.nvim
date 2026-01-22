# Phase 20: SQLite Adapter - Implementation Plan

## Overview
Create a thin adapter layer for raw SQL execution. Wraps kkharji/sqlite.lua with Result<T> error handling and provides simple exec/query interface.

## Module: `lua/lifemode/infra/index/sqlite.lua`

### Function Signatures

#### 1. `open(db_path)`
**Purpose:** Open database connection

**Parameters:**
- `db_path` (string): Absolute path to SQLite database file

**Returns:** `Result<connection>`

**Behavior:**
1. Check if sqlite.lua is available via pcall(require, "sqlite.db")
2. If not available, return Err with installation instructions
3. Open database using sqlite.lua API
4. Return connection object wrapped in Ok()

**Error cases:**
- sqlite.lua not installed → Err("sqlite.lua not installed")
- Invalid db_path → Err("Invalid database path")
- Permission denied → Err("Permission denied")

#### 2. `exec(db, sql, params)`
**Purpose:** Execute SQL statement (INSERT, UPDATE, DELETE, CREATE, etc.)

**Parameters:**
- `db` (connection): Open database connection
- `sql` (string): SQL statement to execute
- `params` (table, optional): Parameters for prepared statement

**Returns:** `Result<()>`

**Behavior:**
1. Validate db connection is valid
2. If params provided, bind them to SQL statement
3. Execute SQL via db:exec()
4. Wrap any errors in Err()
5. Return Ok(nil) on success

**Error cases:**
- Invalid connection → Err("Invalid database connection")
- SQL syntax error → Err("SQL error: {message}")
- Constraint violation → Err("Constraint violation: {message}")

#### 3. `query(db, sql, params)`
**Purpose:** Execute SELECT query and return rows

**Parameters:**
- `db` (connection): Open database connection
- `sql` (string): SELECT statement
- `params` (table, optional): Parameters for prepared statement

**Returns:** `Result<table>` (table = array of row objects)

**Behavior:**
1. Validate db connection is valid
2. If params provided, bind them to SQL statement
3. Execute query via db:select()
4. Return rows wrapped in Ok()
5. Empty result set returns Ok({}) (empty table)

**Error cases:**
- Invalid connection → Err("Invalid database connection")
- SQL syntax error → Err("SQL error: {message}")

#### 4. `close(db)`
**Purpose:** Close database connection

**Parameters:**
- `db` (connection): Database connection to close

**Returns:** `Result<()>`

**Behavior:**
1. Check if db is valid
2. Call db:close()
3. Return Ok(nil)

**Error cases:**
- Already closed → Ok(nil) (idempotent)
- Invalid connection → Err("Invalid connection")

#### 5. `transaction(db, fn)`
**Purpose:** Execute function within transaction

**Parameters:**
- `db` (connection): Open database connection
- `fn` (function): Function to execute within transaction

**Returns:** `Result<T>` (T = return value of fn)

**Behavior:**
1. Execute "BEGIN TRANSACTION"
2. Call fn() and capture result
3. If fn() succeeds: COMMIT and return result
4. If fn() fails: ROLLBACK and return error
5. Wrap in pcall for error handling

**Error cases:**
- Transaction fails → Err("Transaction failed: {message}")
- fn() throws error → ROLLBACK, return Err(error)

### Integration with sqlite.lua

**kkharji/sqlite.lua API:**
```lua
local sqlite = require("sqlite.db")

-- Open database
local db = sqlite({
  uri = "/path/to/db.sqlite",
  opts = {}
})

-- Execute SQL
db:exec("INSERT INTO nodes VALUES (?, ?)", {uuid, content})

-- Query
local rows = db:select("SELECT * FROM nodes WHERE uuid = ?", {uuid})

-- Close
db:close()
```

**Our adapter wraps this with Result pattern:**
```lua
local adapter = require("lifemode.infra.index.sqlite")

-- Open
local db_result = adapter.open(db_path)
if not db_result.ok then
  return db_result
end
local db = db_result.value

-- Execute
local exec_result = adapter.exec(db, "INSERT INTO nodes VALUES (?, ?)", {uuid, content})
if not exec_result.ok then
  return exec_result
end

-- Query
local query_result = adapter.query(db, "SELECT * FROM nodes WHERE uuid = ?", {uuid})
if not query_result.ok then
  return query_result
end
local rows = query_result.value

-- Close
adapter.close(db)
```

### Error Handling Strategy

**Wrap all sqlite.lua calls in pcall:**
- sqlite.lua throws Lua errors on failure
- We catch with pcall and convert to Result<T>
- Preserve original error message for debugging

**Example:**
```lua
function M.exec(db, sql, params)
  if not db then
    return util.Err("exec: db is required")
  end

  local ok, err = pcall(function()
    if params then
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
```

### Connection Management

**Simple approach for MVP:**
- No connection pooling initially
- Caller responsible for open/close
- Later phases can add connection pool if needed

**Pattern:**
```lua
-- Phase 21 (Index Facade) will handle:
local db_result = sqlite_adapter.open(config.db_path)
-- ... use db ...
sqlite_adapter.close(db)
```

### Transaction Support

**Explicit transaction function:**
```lua
local result = adapter.transaction(db, function()
  adapter.exec(db, "INSERT INTO nodes ...")
  adapter.exec(db, "INSERT INTO edges ...")
  return util.Ok("both inserts succeeded")
end)
```

**Implementation:**
```lua
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
    pcall(function() db:exec("ROLLBACK") end)
    return util.Err("transaction: " .. tostring(fn_result))
  end

  local commit_ok, commit_err = pcall(function()
    db:exec("COMMIT")
  end)

  if not commit_ok then
    pcall(function() db:exec("ROLLBACK") end)
    return util.Err("transaction: failed to commit: " .. tostring(commit_err))
  end

  return fn_result or util.Ok(nil)
end
```

### Integration Tests

#### Test 1: Open database
```lua
local adapter = require("lifemode.infra.index.sqlite")
local schema = require("lifemode.infra.index.schema")

local temp_db = "/tmp/test_adapter_open.db"
os.remove(temp_db)

-- Initialize schema first
local init_result = schema.init_db(temp_db)
assert(init_result.ok, "schema init should succeed")
init_result.value:close()

-- Open with adapter
local open_result = adapter.open(temp_db)
assert(open_result.ok, "open should succeed: " .. tostring(open_result.error))

local db = open_result.value
assert(db, "should return database connection")

adapter.close(db)
os.remove(temp_db)
```

#### Test 2: exec INSERT statement
```lua
local temp_db = "/tmp/test_adapter_exec.db"
os.remove(temp_db)

schema.init_db(temp_db).value:close()

local db = adapter.open(temp_db).value

local exec_result = adapter.exec(db, [[
  INSERT INTO nodes (uuid, file_path, created, modified, content)
  VALUES (?, ?, ?, ?, ?)
]], {"test-uuid", "/tmp/test.md", 1234567890, 1234567890, "test content"})

assert(exec_result.ok, "exec should succeed: " .. tostring(exec_result.error))

adapter.close(db)
os.remove(temp_db)
```

#### Test 3: query SELECT statement
```lua
local temp_db = "/tmp/test_adapter_query.db"
os.remove(temp_db)

schema.init_db(temp_db).value:close()

local db = adapter.open(temp_db).value

-- Insert test data
adapter.exec(db, "INSERT INTO nodes VALUES (?, ?, ?, ?, ?)",
  {"uuid1", "/tmp/1.md", 100, 100, "content1"})
adapter.exec(db, "INSERT INTO nodes VALUES (?, ?, ?, ?, ?)",
  {"uuid2", "/tmp/2.md", 200, 200, "content2"})

-- Query
local query_result = adapter.query(db, "SELECT * FROM nodes WHERE uuid = ?", {"uuid1"})
assert(query_result.ok, "query should succeed")

local rows = query_result.value
assert(#rows == 1, "should return 1 row")
assert(rows[1].uuid == "uuid1", "should return correct row")
assert(rows[1].content == "content1", "should return correct content")

adapter.close(db)
os.remove(temp_db)
```

#### Test 4: query returns empty result
```lua
local db = adapter.open(temp_db).value

local query_result = adapter.query(db, "SELECT * FROM nodes WHERE uuid = ?", {"nonexistent"})
assert(query_result.ok, "query should succeed even with no results")
assert(#query_result.value == 0, "should return empty table")

adapter.close(db)
```

#### Test 5: exec with SQL error
```lua
local db = adapter.open(temp_db).value

local exec_result = adapter.exec(db, "INSERT INTO nonexistent_table VALUES (?)", {"value"})
assert(not exec_result.ok, "should fail with SQL error")
assert(exec_result.error:match("SQL") or exec_result.error:match("table"), "error should mention SQL/table")

adapter.close(db)
```

#### Test 6: transaction commits on success
```lua
local db = adapter.open(temp_db).value

local tx_result = adapter.transaction(db, function()
  adapter.exec(db, "INSERT INTO nodes VALUES (?, ?, ?, ?, ?)",
    {"tx-uuid-1", "/tmp/tx1.md", 300, 300, "tx content 1"})
  adapter.exec(db, "INSERT INTO nodes VALUES (?, ?, ?, ?, ?)",
    {"tx-uuid-2", "/tmp/tx2.md", 400, 400, "tx content 2"})
  return util.Ok(nil)
end)

assert(tx_result.ok, "transaction should succeed")

-- Verify both inserts committed
local query_result = adapter.query(db, "SELECT COUNT(*) as count FROM nodes WHERE uuid LIKE 'tx-%'")
assert(query_result.value[1].count == 2, "both inserts should be committed")

adapter.close(db)
```

#### Test 7: transaction rolls back on error
```lua
local db = adapter.open(temp_db).value

local tx_result = adapter.transaction(db, function()
  adapter.exec(db, "INSERT INTO nodes VALUES (?, ?, ?, ?, ?)",
    {"rollback-uuid", "/tmp/rb.md", 500, 500, "content"})
  error("intentional error")
end)

assert(not tx_result.ok, "transaction should fail")

-- Verify insert was rolled back
local query_result = adapter.query(db, "SELECT * FROM nodes WHERE uuid = ?", {"rollback-uuid"})
assert(#query_result.value == 0, "insert should be rolled back")

adapter.close(db)
```

#### Test 8: close is idempotent
```lua
local db = adapter.open(temp_db).value

local close1 = adapter.close(db)
assert(close1.ok, "first close should succeed")

local close2 = adapter.close(db)
assert(close2.ok, "second close should succeed (idempotent)")
```

## Dependencies
- `lifemode.util` (Result type)
- `sqlite.lua` (kkharji/sqlite.lua)
- `lifemode.infra.index.schema` (for tests)

## Acceptance Criteria
- [ ] open() opens database connection
- [ ] exec() executes SQL statements
- [ ] query() returns rows
- [ ] close() closes connection
- [ ] transaction() commits on success
- [ ] transaction() rolls back on error
- [ ] Error handling wraps all sqlite.lua errors
- [ ] Tests pass

## Design Decisions

### Decision: Use kkharji/sqlite.lua (not sqlite3 CLI)
**Rationale:** ROADMAP mentions "Use `vim.fn.system()` with `sqlite3` CLI or `sqlite.lua` plugin". sqlite.lua is superior: (1) No shell process overhead, (2) Native Lua integration, (3) Better error handling, (4) Already used in schema.lua. CLI would require parsing text output - fragile and slow.

### Decision: Thin wrapper, minimal abstraction
**Rationale:** This is infrastructure layer - just adapt sqlite.lua API to Result<T> pattern. No query builders, no ORM, no magic. Higher layers (Index Facade, Phase 21) will provide domain-specific APIs. Keep this simple and predictable.

### Decision: Caller manages connections (no pooling yet)
**Rationale:** Connection pooling adds complexity for uncertain benefit. SQLite is designed for embedded use - opening connection is fast. Future phase can add pooling if profiling shows it's needed. YAGNI principle.

### Decision: Explicit transaction function
**Rationale:** Transactions are critical for data integrity but not every operation needs them. Explicit `transaction(db, fn)` makes intent clear. Alternative (implicit transactions) would hide important behavior. Functional approach - pass function to execute in transaction context.

### Decision: pcall wraps all sqlite.lua calls
**Rationale:** sqlite.lua throws Lua errors on failure. We use Result<T> pattern throughout codebase. pcall converts exceptions to Result<T>. Preserves error messages for debugging.

### Decision: Empty query result returns Ok([])
**Rationale:** No rows is not an error - it's valid result. Returning Ok(empty_table) is consistent with SQL semantics. Caller can check `#rows == 0` without error handling.

### Decision: Close is idempotent
**Rationale:** Multiple close() calls should not error. Makes cleanup code simpler - no need to track "already closed" state. sqlite.lua close is idempotent, we preserve that.
