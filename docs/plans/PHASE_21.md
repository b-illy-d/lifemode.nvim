# Phase 21: Index Facade (Insert/Update) - Implementation Plan

## Overview
High-level index operations facade. Provides domain-friendly API for inserting, updating, deleting, and querying nodes in the SQLite index. Bridges domain layer (Node objects) and infrastructure layer (SQL).

## Module: `lua/lifemode/infra/index/init.lua`

### Function Signatures

#### 1. `insert_node(node, file_path)`
**Purpose:** Insert node into index

**Parameters:**
- `node` (Node): Node object from domain layer
- `file_path` (string): Absolute path to markdown file

**Returns:** `Result<()>`

**Behavior:**
1. Validate node using domain.node.validate()
2. Open database connection via schema.init_db()
3. Extract node data: uuid, created, modified, content
4. Hash content for change detection (use simple string hash)
5. Execute INSERT via sqlite adapter:
   ```sql
   INSERT INTO nodes (uuid, file_path, created, modified, content)
   VALUES (?, ?, ?, ?, ?)
   ```
6. Close database connection
7. Return Ok(nil) on success

**Error cases:**
- Invalid node → Err("Invalid node: {validation_error}")
- Database error → Err("Failed to insert node: {sql_error}")
- Duplicate UUID → Err("Node already exists: {uuid}")

#### 2. `update_node(node, file_path)`
**Purpose:** Update existing node in index

**Parameters:**
- `node` (Node): Updated node object
- `file_path` (string): Absolute path to markdown file

**Returns:** `Result<()>`

**Behavior:**
1. Validate node
2. Open database connection
3. Check if node exists via SELECT
4. If not exists, return Err("Node not found")
5. Update via sqlite adapter:
   ```sql
   UPDATE nodes
   SET file_path = ?, created = ?, modified = ?, content = ?
   WHERE uuid = ?
   ```
6. Close connection
7. Return Ok(nil)

**Error cases:**
- Node not found → Err("Node not found: {uuid}")
- Database error → Err("Failed to update node: {sql_error}")

#### 3. `delete_node(uuid)`
**Purpose:** Remove node from index

**Parameters:**
- `uuid` (string): Node UUID to delete

**Returns:** `Result<()>`

**Behavior:**
1. Validate UUID format
2. Open database connection
3. Delete from nodes table:
   ```sql
   DELETE FROM nodes WHERE uuid = ?
   ```
4. Delete associated edges:
   ```sql
   DELETE FROM edges WHERE from_uuid = ? OR to_uuid = ?
   ```
5. Close connection
6. Return Ok(nil) even if node didn't exist (idempotent)

**Error cases:**
- Invalid UUID → Err("Invalid UUID: {uuid}")
- Database error → Err("Failed to delete node: {sql_error}")

#### 4. `find_by_id(uuid)`
**Purpose:** Query node by UUID

**Parameters:**
- `uuid` (string): Node UUID to find

**Returns:** `Result<Node?>` (Ok(nil) if not found)

**Behavior:**
1. Validate UUID format
2. Open database connection
3. Query via sqlite adapter:
   ```sql
   SELECT uuid, file_path, created, modified, content
   FROM nodes WHERE uuid = ?
   ```
4. If no rows, return Ok(nil)
5. If rows found:
   - Extract first row
   - Reconstruct Node object via domain.types.Node_new()
   - Return Ok(node)
6. Close connection

**Error cases:**
- Invalid UUID → Err("Invalid UUID: {uuid}")
- Database error → Err("Failed to query node: {sql_error}")
- Invalid data → Err("Corrupted node data: {error}")

#### 5. `get_db_path()`
**Purpose:** Compute database path from config

**Parameters:** None

**Returns:** `string` (absolute path to database file)

**Behavior:**
1. Get vault_path from config
2. Construct path: `{vault_path}/.lifemode/index.sqlite`
3. Return absolute path

### Helper Functions

#### `validate_uuid(uuid)`
**Purpose:** Check if string is valid UUIDv4

**Parameters:**
- `uuid` (string): UUID to validate

**Returns:** `boolean`

**Behavior:**
- Use same regex as domain.types
- Return true if valid, false otherwise

#### `ensure_db_dir(db_path)`
**Purpose:** Create .lifemode directory if doesn't exist

**Parameters:**
- `db_path` (string): Database file path

**Returns:** `Result<()>`

**Behavior:**
1. Extract directory from db_path
2. Check if directory exists
3. If not, create with vim.fn.mkdir(dir, "p")
4. Return Ok(nil) on success

**Error cases:**
- Failed to create → Err("Failed to create directory: {path}")

### Data Flow

```
Domain Layer (Node object)
    ↓
Index Facade (this module)
    ↓ SQL construction
SQLite Adapter (exec/query)
    ↓
Database (nodes table)
```

**Insert flow:**
```
node → validate → extract fields → INSERT SQL → exec → Ok()
```

**Query flow:**
```
uuid → validate → SELECT SQL → query → rows → reconstruct Node → Ok(node)
```

### Integration with Config

**Database path:**
```lua
local config = require("lifemode.config")
local vault_path = config.get("vault_path")
local db_path = vault_path .. "/.lifemode/index.sqlite"
```

**Directory creation:**
```lua
local lifemode_dir = vault_path .. "/.lifemode"
if vim.fn.isdirectory(lifemode_dir) == 0 then
  vim.fn.mkdir(lifemode_dir, "p")
end
```

### Integration Tests

#### Test 1: Insert node
```lua
local index = require("lifemode.infra.index")
local node = require("lifemode.domain.node")

local test_db = "/tmp/test_index_insert.db"
-- Setup schema first
schema.init_db(test_db)

local node_result = node.create("test content", {})
assert(node_result.ok)
local test_node = node_result.value

local insert_result = index.insert_node(test_node, "/tmp/test.md")
assert(insert_result.ok, "insert should succeed")

-- Verify with direct SQL
local db = adapter.open(test_db).value
local rows = adapter.query(db, "SELECT * FROM nodes WHERE uuid = ?", {test_node.id}).value
assert(#rows == 1, "node should be in database")
assert(rows[1].content == "test content")
```

#### Test 2: Find by ID
```lua
-- After insert from Test 1
local find_result = index.find_by_id(test_node.id)
assert(find_result.ok, "find should succeed")
assert(find_result.value ~= nil, "node should be found")
assert(find_result.value.id == test_node.id)
assert(find_result.value.content == "test content")
```

#### Test 3: Update node
```lua
-- Modify node
local updated_node = types.Node_new("updated content", test_node.meta).value

local update_result = index.update_node(updated_node, "/tmp/updated.md")
assert(update_result.ok, "update should succeed")

-- Verify
local find_result = index.find_by_id(updated_node.id)
assert(find_result.value.content == "updated content")
```

#### Test 4: Delete node
```lua
local delete_result = index.delete_node(test_node.id)
assert(delete_result.ok, "delete should succeed")

-- Verify deleted
local find_result = index.find_by_id(test_node.id)
assert(find_result.ok, "find should succeed")
assert(find_result.value == nil, "node should be deleted")
```

#### Test 5: Find non-existent node
```lua
local find_result = index.find_by_id("00000000-0000-4000-a000-000000000000")
assert(find_result.ok, "find should succeed")
assert(find_result.value == nil, "should return nil for non-existent")
```

#### Test 6: Insert duplicate UUID
```lua
local dup_result = index.insert_node(test_node, "/tmp/test.md")
assert(not dup_result.ok, "insert duplicate should fail")
assert(dup_result.error:match("already exists") or dup_result.error:match("UNIQUE"))
```

#### Test 7: Update non-existent node
```lua
local fake_node = node.create("fake", {id = "11111111-1111-4111-a111-111111111111"}).value
local update_result = index.update_node(fake_node, "/tmp/fake.md")
assert(not update_result.ok, "update non-existent should fail")
assert(update_result.error:match("not found"))
```

#### Test 8: Delete idempotent
```lua
local delete1 = index.delete_node(test_node.id)
assert(delete1.ok, "first delete should succeed")

local delete2 = index.delete_node(test_node.id)
assert(delete2.ok, "second delete should succeed (idempotent)")
```

## Dependencies
- `lifemode.util` (Result type)
- `lifemode.config` (vault_path)
- `lifemode.infra.index.schema` (init_db)
- `lifemode.infra.index.sqlite` (exec, query, open, close)
- `lifemode.domain.node` (validate)
- `lifemode.domain.types` (Node_new)

## Acceptance Criteria
- [ ] insert_node() inserts node into database
- [ ] update_node() updates existing node
- [ ] delete_node() removes node and edges
- [ ] find_by_id() returns node or nil
- [ ] Database directory created if missing
- [ ] UUID validation
- [ ] Error handling for all operations
- [ ] Tests pass

## Design Decisions

### Decision: Store file_path in nodes table
**Rationale:** Need to map nodes back to source files for editing operations. Also useful for displaying file locations in UI. Path stored as absolute path for consistency.

### Decision: Store content as TEXT not hash
**Rationale:** ROADMAP mentions "hash content for change detection" but we need full content for full-text search (Phase 24). Store full content, compute hash only if needed for change detection. Content column enables FTS5 later.

### Decision: delete_node() is idempotent
**Rationale:** Deleting non-existent node is not an error - end state is the same (node doesn't exist). Simplifies caller logic - no need to check existence before delete.

### Decision: find_by_id() returns Ok(nil) not Err()
**Rationale:** Not finding a node is valid result, not error. Returning Ok(nil) makes it explicit - caller checks `result.value == nil`. Alternative (Err) would force error handling for non-error case.

### Decision: Facade manages database lifecycle
**Rationale:** Open connection → execute operation → close connection. Each function is self-contained. Caller doesn't manage connections. Alternative (caller passes connection) would leak infrastructure concerns to application layer.

### Decision: Node reconstruction via domain.types.Node_new()
**Rationale:** Ensures returned nodes are valid domain objects. Use same constructor that domain layer uses. Maintains type safety and validation.

### Decision: Delete edges with node
**Rationale:** When node is deleted, its edges become invalid (dangling references). Delete them atomically. Prevents index corruption. Both outgoing and incoming edges removed.

### Decision: Update requires existing node
**Rationale:** Clear semantics - insert creates, update modifies. If node doesn't exist, that's caller error. Alternative (upsert) would hide whether operation was create or update. Explicit is better.
