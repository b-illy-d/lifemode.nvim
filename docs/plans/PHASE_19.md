# Phase 19: SQLite Schema - Implementation Plan

## Overview
Define database structure for LifeMode's SQLite index. Create tables for nodes and edges, with appropriate indexes for query performance.

## Module: `lua/lifemode/infra/index/schema.lua`

### Function Signatures

#### 1. `init_db(db_path)`
**Purpose:** Initialize database with schema if not exists

**Parameters:**
- `db_path` (string): Absolute path to SQLite database file

**Returns:** `Result<sqlite_connection>`

**Behavior:**
1. Open or create SQLite database at db_path
2. Execute schema creation statements (CREATE TABLE IF NOT EXISTS)
3. Create indexes if not exist
4. Set PRAGMA settings (foreign_keys = ON, journal_mode = WAL)
5. Return database connection object

**Error cases:**
- db_path directory doesn't exist → Err("Database directory does not exist")
- Permission denied → Err("Permission denied")
- Invalid path → Err("Invalid database path")

#### 2. `migrate(db, from_version, to_version)`
**Purpose:** Upgrade database schema between versions

**Parameters:**
- `db` (sqlite_connection): Open database connection
- `from_version` (number): Current schema version
- `to_version` (number): Target schema version

**Returns:** `Result<()>`

**Behavior:**
1. Check current schema version from `schema_version` table (if exists)
2. Apply migration steps sequentially (from_version → from_version+1 → ... → to_version)
3. Wrap in transaction (BEGIN/COMMIT)
4. Update schema_version table
5. Return Ok(nil) on success

**Migration steps (for MVP, version 1 → 2):**
- Version 1: Initial schema (nodes + edges tables)
- Version 2: Add FTS5 virtual table for full-text search (Phase 24)

**Error cases:**
- Migration not found → Err("No migration path from {from} to {to}")
- SQL execution failure → Err("Migration failed: {sql_error}")
- Version downgrade attempted → Err("Downgrade not supported")

#### 3. `get_schema_version(db)`
**Purpose:** Get current schema version from database

**Parameters:**
- `db` (sqlite_connection): Open database connection

**Returns:** `Result<number>`

**Behavior:**
1. Check if schema_version table exists
2. If not exists, return Ok(0) (fresh database)
3. If exists, query `SELECT version FROM schema_version LIMIT 1`
4. Return version number

#### 4. `get_schema_sql()`
**Purpose:** Return initial schema SQL statements

**Parameters:** None

**Returns:** `table` (array of SQL strings)

**Behavior:**
Return array of SQL statements for initial schema:
1. CREATE TABLE schema_version
2. CREATE TABLE nodes
3. CREATE TABLE edges
4. CREATE INDEX idx_edges_from
5. CREATE INDEX idx_edges_to
6. INSERT INTO schema_version

### SQL Schema Definitions

#### Schema Version Table
```sql
CREATE TABLE IF NOT EXISTS schema_version (
  version INTEGER PRIMARY KEY,
  applied_at INTEGER NOT NULL
);

INSERT INTO schema_version (version, applied_at)
VALUES (1, strftime('%s', 'now'))
ON CONFLICT DO NOTHING;
```

#### Nodes Table
```sql
CREATE TABLE IF NOT EXISTS nodes (
  uuid TEXT PRIMARY KEY,
  file_path TEXT NOT NULL,
  created INTEGER,
  modified INTEGER,
  content TEXT
);
```

**Columns:**
- `uuid`: Node UUID (primary key, from frontmatter `id`)
- `file_path`: Absolute path to markdown file
- `created`: Unix timestamp (from frontmatter `created`)
- `modified`: Unix timestamp (file mtime)
- `content`: Full text content of node (after frontmatter)

#### Edges Table
```sql
CREATE TABLE IF NOT EXISTS edges (
  from_uuid TEXT NOT NULL,
  to_uuid TEXT NOT NULL,
  edge_type TEXT NOT NULL,
  PRIMARY KEY (from_uuid, to_uuid, edge_type)
);

CREATE INDEX IF NOT EXISTS idx_edges_from ON edges(from_uuid);
CREATE INDEX IF NOT EXISTS idx_edges_to ON edges(to_uuid);
```

**Columns:**
- `from_uuid`: Source node UUID
- `to_uuid`: Target node UUID
- `edge_type`: Type of relationship (e.g., "wikilink", "citation", "transclusion")

**Indexes:**
- `idx_edges_from`: Fast lookup of outgoing edges from a node
- `idx_edges_to`: Fast lookup of backlinks to a node

### PRAGMA Settings

```sql
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
```

**Rationale:**
- `foreign_keys = ON`: Enforce referential integrity (edges reference nodes)
- `journal_mode = WAL`: Write-ahead logging for better concurrency

### SQLite Library Integration

**Use kkharji/sqlite.lua:**
```lua
local sqlite = require("sqlite.db")

-- Open database
local db = sqlite({
  uri = db_path,
  opts = {
    -- Options if needed
  }
})

-- Execute SQL
db:exec(sql_string)

-- Query
local rows = db:select(sql_string)
```

### Integration Tests

#### Test 1: Init database creates tables
```lua
local schema = require("lifemode.infra.index.schema")
local temp_db = "/tmp/test_lifemode_init.db"

-- Clean slate
os.remove(temp_db)

-- Initialize
local result = schema.init_db(temp_db)
assert(result.ok, "init_db should succeed")

local db = result.value

-- Verify tables exist
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
```

#### Test 2: Indexes are created
```lua
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
```

#### Test 3: Schema version is set
```lua
local version_result = schema.get_schema_version(db)
assert(version_result.ok, "get_schema_version should succeed")
assert(version_result.value == 1, "schema version should be 1")
```

#### Test 4: Idempotent init (run twice)
```lua
-- Run init_db again on same database
local result2 = schema.init_db(temp_db)
assert(result2.ok, "init_db should be idempotent")

-- Version should still be 1
local version_result2 = schema.get_schema_version(result2.value)
assert(version_result2.value == 1, "schema version should still be 1")
```

#### Test 5: Error when db_path directory doesn't exist
```lua
local bad_path = "/nonexistent/path/db.sqlite"
local result = schema.init_db(bad_path)
assert(not result.ok, "should fail when directory doesn't exist")
assert(result.error:match("not exist") or result.error:match("directory"), "error should mention directory")
```

## Dependencies
- `lifemode.util` (Result type)
- `sqlite.lua` (kkharji/sqlite.lua Neovim plugin)
- Neovim filesystem API (for path validation)

## Acceptance Criteria
- [ ] schema.lua module created
- [ ] init_db() creates database with tables
- [ ] nodes table has correct schema
- [ ] edges table has correct schema
- [ ] Indexes created on edges table
- [ ] schema_version table tracks version
- [ ] get_schema_version() returns correct version
- [ ] Idempotent initialization (safe to run multiple times)
- [ ] PRAGMA settings applied
- [ ] Error handling for invalid paths
- [ ] Tests pass

## Design Decisions

### Decision: Use kkharji/sqlite.lua library
**Rationale:** Most mature SQLite binding for Neovim. Pure Lua FFI, no C compilation needed. Well-maintained, used by telescope.nvim and other plugins. API is clean and Result-friendly.

### Decision: schema_version table for migrations
**Rationale:** Explicit versioning enables future schema changes without breaking existing installations. Single source of truth for current version. Industry standard pattern (e.g., Rails migrations, Alembic).

### Decision: WAL journal mode
**Rationale:** Write-Ahead Logging provides better concurrency - readers don't block writers. Critical for Neovim where index updates may happen while user is querying. Standard recommendation for applications with concurrent access.

### Decision: Composite primary key on edges
**Rationale:** `(from_uuid, to_uuid, edge_type)` as PK enforces uniqueness - can't have duplicate edges of same type between same nodes. Avoids need for synthetic ID. Efficient for common queries.

### Decision: Separate indexes on from_uuid and to_uuid
**Rationale:** Two most common queries: (1) outgoing edges from node, (2) backlinks to node. Composite PK already indexes from_uuid, but explicit index ensures optimal performance. to_uuid needs separate index for backlinks query.

### Decision: content column stores full text
**Rationale:** Enables full-text search (Phase 24) without re-reading files. Denormalization is acceptable - content is source of truth in markdown files, index is derived. Rebuild command (Phase 22) will resync if needed.

### Decision: created/modified as INTEGER (Unix timestamp)
**Rationale:** SQLite's INTEGER is efficient for date range queries. Unix timestamp is unambiguous (no timezone issues). Conversion to/from human-readable dates happens in application layer.

### Decision: No foreign key constraints yet
**Rationale:** For MVP, edges may reference nodes that don't exist in index yet (stale references during incremental updates). Soft referential integrity - query logic handles missing nodes gracefully. Could add FK constraints in later phase if needed.
