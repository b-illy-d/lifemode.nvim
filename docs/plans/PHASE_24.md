# Phase 24: Full-Text Search (FTS5) - Implementation Plan

## Overview
Add SQLite FTS5 (Full-Text Search) capability to enable fast text search across node content. FTS5 provides ranking, stemming, and efficient inverted index for text queries.

## Module: `lua/lifemode/infra/index/search.lua`

### Function Signatures

#### 1. `search(query_text, opts)`
**Purpose:** Search nodes by content using FTS5

**Parameters:**
- `query_text` (string): FTS5 query (supports MATCH syntax: "word", "phrase", "word*", etc.)
- `opts` (table, optional): Search options
  - `limit` (number): Max results (default: 50)
  - `offset` (number): Skip N results (default: 0)

**Returns:** `Result<Node[]>` (array of Node objects, ranked by relevance)

**Behavior:**
1. Validate query_text (not empty)
2. Open database connection
3. Execute FTS5 query:
   ```sql
   SELECT nodes.*
   FROM nodes_fts
   JOIN nodes ON nodes_fts.uuid = nodes.uuid
   WHERE nodes_fts MATCH ?
   ORDER BY rank
   LIMIT ? OFFSET ?
   ```
4. Convert rows to Node objects
5. Return ranked results

**Error cases:**
- Empty query → Err("query_text is required")
- Invalid FTS5 syntax → Err("Invalid search syntax: ...")
- Database error → Err("Search failed: ...")

#### 2. `rebuild_fts_index()`
**Purpose:** Rebuild entire FTS5 index from nodes table

**Parameters:** None

**Returns:** `Result<{indexed}>`
- `indexed` (number): Count of nodes indexed

**Behavior:**
1. Open database connection
2. Delete all rows from nodes_fts: `DELETE FROM nodes_fts`
3. Populate from nodes table:
   ```sql
   INSERT INTO nodes_fts (uuid, content)
   SELECT uuid, content FROM nodes
   ```
4. Return count of indexed nodes

**Error cases:**
- Database error → Err("Failed to rebuild FTS index: ...")

### Schema Changes

**New FTS5 virtual table:**
```sql
CREATE VIRTUAL TABLE IF NOT EXISTS nodes_fts USING fts5(
  content,
  uuid UNINDEXED
);
```

**Why these columns:**
- `content`: Full-text indexed (searchable)
- `uuid UNINDEXED`: Not indexed but stored for JOIN

**Schema version:** Bump from 1 to 2

### Integration with Index Operations

**Modify `lua/lifemode/infra/index/init.lua`:**

#### Insert node
```lua
function M.insert_node(node, file_path)
  -- ... existing insert logic ...

  -- After successful insert, update FTS
  local fts_sql = "INSERT INTO nodes_fts (uuid, content) VALUES (?, ?)"
  local fts_result = adapter.exec(db, fts_sql, { node.id, node.content })
  -- Don't fail insert if FTS fails, just log warning
end
```

#### Update node
```lua
function M.update_node(node, file_path)
  -- ... existing update logic ...

  -- After successful update, update FTS
  local fts_sql = [[
    INSERT OR REPLACE INTO nodes_fts (uuid, content)
    VALUES (?, ?)
  ]]
  local fts_result = adapter.exec(db, fts_sql, { node.id, node.content })
  -- Don't fail update if FTS fails, just log warning
end
```

#### Delete node
```lua
function M.delete_node(uuid)
  -- ... existing delete logic ...

  -- After successful delete, remove from FTS
  local fts_sql = "DELETE FROM nodes_fts WHERE uuid = ?"
  local fts_result = adapter.exec(db, fts_sql, { uuid })
  -- Don't fail delete if FTS fails, just log warning
end
```

### FTS5 Query Syntax Examples

Users can search with FTS5 MATCH syntax:
- `"hello"` - Find documents containing "hello"
- `"hello world"` - Phrase search (both words adjacent)
- `"hello OR world"` - Either word
- `"hello AND world"` - Both words (anywhere)
- `"hel*"` - Prefix search (hello, help, etc.)
- `"hello -world"` - Contains hello but not world

### Ranking

FTS5 provides `rank` column automatically:
- Lower rank = better match (negative numbers)
- Based on BM25 algorithm
- Considers term frequency, document length, etc.

We ORDER BY rank (ascending) to get best matches first.

### Data Flow

```
User enters query
    ↓
search(query_text)
    ↓
FTS5 MATCH query
    ↓
Ranked results (by relevance)
    ↓
Convert to Node[] objects
    ↓
Return to caller
```

### Test Plan

#### Test 1: Basic search
```lua
-- Insert nodes with known content
local node1 = create_node("The quick brown fox")
local node2 = create_node("The lazy dog")

index.insert_node(node1, "/path/to/file1.md")
index.insert_node(node2, "/path/to/file2.md")

-- Search for "fox"
local results = search.search("fox")
assert(#results.value == 1)
assert(results.value[1].id == node1.id)
```

#### Test 2: Phrase search
```lua
local results = search.search('"quick brown"')
assert(#results.value == 1)
assert(results.value[1].content:match("quick brown"))
```

#### Test 3: Multiple results ranked
```lua
local node1 = create_node("apple apple apple")
local node2 = create_node("apple banana")
-- ... insert both ...

local results = search.search("apple")
assert(#results.value == 2)
-- node1 should rank higher (more occurrences)
assert(results.value[1].id == node1.id)
```

#### Test 4: Prefix search
```lua
local node = create_node("development developer")
-- ... insert ...

local results = search.search("dev*")
assert(#results.value == 1)
```

#### Test 5: Empty query
```lua
local results = search.search("")
assert(not results.ok)
assert(results.error:match("required"))
```

#### Test 6: FTS index updates on node changes
```lua
local node = create_node("original content")
index.insert_node(node, "/path")

-- Should find it
local results1 = search.search("original")
assert(#results1.value == 1)

-- Update content
node.content = "updated content"
index.update_node(node, "/path")

-- Should NOT find "original" anymore
local results2 = search.search("original")
assert(#results2.value == 0)

-- Should find "updated"
local results3 = search.search("updated")
assert(#results3.value == 1)
```

#### Test 7: Rebuild FTS index
```lua
-- Manually corrupt FTS index
-- ... delete some rows from nodes_fts ...

-- Rebuild
local rebuild_result = search.rebuild_fts_index()
assert(rebuild_result.ok)

-- Search should work again
local results = search.search("test")
assert(results.ok)
```

## Dependencies
- `lifemode.util` (Result type)
- `lifemode.infra.index.schema` (schema management)
- `lifemode.infra.index.sqlite` (database adapter)
- `lifemode.domain.types` (Node type)
- SQLite FTS5 extension (bundled with most SQLite builds)

## Acceptance Criteria
- [ ] FTS5 table created in schema
- [ ] search() returns ranked results
- [ ] FTS index updates on insert/update/delete
- [ ] Supports FTS5 MATCH syntax
- [ ] rebuild_fts_index() works
- [ ] Tests pass

## Design Decisions

### Decision: FTS5 over FTS4 or FTS3
**Rationale:** FTS5 is the latest version with better performance, BM25 ranking, and more features. FTS4/3 are legacy. All recent SQLite builds include FTS5.

### Decision: Index only content, not metadata
**Rationale:** User searches for node content, not UUIDs or timestamps. Indexing metadata wastes space and slows indexing. Can add later if needed.

### Decision: uuid UNINDEXED in FTS table
**Rationale:** We need uuid to JOIN with nodes table but don't want to search on it. UNINDEXED stores it without indexing, saving space.

### Decision: Don't fail index operations if FTS fails
**Rationale:** FTS is auxiliary - if FTS update fails (corrupted index, disk full), the node should still be inserted/updated. Log warning but continue. User can rebuild FTS index later.

### Decision: Default limit 50 results
**Rationale:** Balance between usefulness and performance. 50 results fit in most UIs. User can increase if needed via opts.limit.

### Decision: Separate rebuild_fts_index() function
**Rationale:** Allows manual recovery if FTS index gets corrupted or out of sync. Also useful for migration from non-FTS to FTS schema.

### Decision: Simple MATCH query, no query parsing
**Rationale:** FTS5 syntax is powerful enough. Don't build a query DSL on top - adds complexity and limits flexibility. User can learn FTS5 syntax (well-documented).

### Decision: Schema migration from version 1 to 2
**Rationale:** Adding FTS table is a breaking change (schema structure changed). Bump version so we can detect old vs new schema. Provide migration path.

## Migration Strategy

**Schema version 1 → 2:**
1. Detect current schema version
2. If version 1:
   - Create nodes_fts table
   - Populate from nodes: `INSERT INTO nodes_fts SELECT uuid, content FROM nodes`
   - Update schema_version to 2
3. If version 0 (new database): create with version 2 directly

**Backward compatibility:**
- Old plugins (without search) work fine with new schema (extra table ignored)
- New plugins (with search) require version 2 schema
