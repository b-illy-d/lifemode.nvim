# Phase 28: Store Edges in Index - Implementation Plan

## Overview
Add functions to persist edges (relationships) to the SQLite database. This enables storing wikilinks, transclusions, and citations as queryable edges in the index.

## Module: `lua/lifemode/infra/index/init.lua` (modify existing)

### Function Signatures

#### `M.insert_edge(edge)`
**Purpose:** Store a single edge in the database

**Parameters:**
- `edge` (Edge): Edge object with from, to, kind, context

**Returns:** `Result<()>`

**Behavior:**
1. Validate edge using domain validation (from types.Edge_new if needed)
2. Get database connection
3. INSERT edge into edges table
   - Columns: from_uuid, to_uuid, edge_type (note: schema uses edge_type not kind)
   - Context field not in schema - will not store it for MVP (future enhancement)
4. Handle conflicts: if edge already exists, treat as success (idempotent)
5. Close DB and return Ok(nil)

**Error handling:**
- Invalid edge structure
- Database connection failure
- SQL execution error

#### `M.delete_edges_from(uuid)`
**Purpose:** Delete all outgoing edges from a node (used when re-parsing node content)

**Parameters:**
- `uuid` (string): UUID of the source node

**Returns:** `Result<()>`

**Behavior:**
1. Validate UUID format
2. Get database connection
3. DELETE FROM edges WHERE from_uuid = ?
4. Close DB and return Ok(nil)

**Rationale:** When re-parsing a node's wikilinks, we need to clear old edges before inserting new ones. This prevents stale references.

#### `M.find_edges(uuid, direction, kind)`
**Purpose:** Query edges by direction and optionally filter by kind

**Parameters:**
- `uuid` (string): UUID of the node
- `direction` (string): "in" (backlinks), "out" (outgoing), "both"
- `kind` (string|nil): Optional filter - "wikilink", "transclusion", "citation"

**Returns:** `Result<Edge[]>`

**Behavior:**
1. Validate UUID format
2. Validate direction is one of: "in", "out", "both"
3. If kind provided, validate it's one of: "wikilink", "transclusion", "citation"
4. Get database connection
5. Build SQL query based on direction:
   - "in": WHERE to_uuid = ?
   - "out": WHERE from_uuid = ?
   - "both": WHERE from_uuid = ? OR to_uuid = ?
6. If kind specified, add: AND edge_type = ?
7. Execute query
8. Convert rows to Edge objects using types.Edge_new
9. Close DB and return Ok(edges)

**Error handling:**
- Invalid UUID
- Invalid direction
- Invalid kind
- Database error
- Corrupted edge data (validation fails)

### Data Structure Mapping

**Domain Edge:**
```lua
{
  from = "uuid1",
  to = "uuid2",
  kind = "wikilink",
  context = "surrounding text"  -- not stored in schema yet
}
```

**Database Schema:**
```sql
edges (
  from_uuid TEXT,
  to_uuid TEXT,
  edge_type TEXT,
  PRIMARY KEY (from_uuid, to_uuid, edge_type)
)
```

**Mapping:**
- edge.from → from_uuid
- edge.to → to_uuid
- edge.kind → edge_type
- edge.context → NOT STORED (future enhancement)

### Test Plan

#### Test 1: Insert edge
```lua
local types = require('lifemode.domain.types')
local index = require('lifemode.infra.index')

local edge_result = types.Edge_new(
  "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa",
  "bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb",
  "wikilink",
  nil
)
assert(edge_result.ok)

local insert_result = index.insert_edge(edge_result.value)
assert(insert_result.ok)
```

#### Test 2: Query outgoing edges
```lua
local edges_result = index.find_edges(
  "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa",
  "out",
  nil
)
assert(edges_result.ok)
assert(#edges_result.value == 1)
assert(edges_result.value[1].to == "bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb")
```

#### Test 3: Query backlinks (incoming edges)
```lua
local backlinks_result = index.find_edges(
  "bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb",
  "in",
  nil
)
assert(backlinks_result.ok)
assert(#backlinks_result.value == 1)
assert(backlinks_result.value[1].from == "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa")
```

#### Test 4: Filter by kind
```lua
-- Insert transclusion edge
local trans_edge = types.Edge_new(
  "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa",
  "cccccccc-cccc-4ccc-cccc-cccccccccccc",
  "transclusion",
  nil
)
index.insert_edge(trans_edge.value)

-- Query only wikilinks
local wikilinks_result = index.find_edges(
  "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa",
  "out",
  "wikilink"
)
assert(wikilinks_result.ok)
assert(#wikilinks_result.value == 1)
assert(wikilinks_result.value[1].kind == "wikilink")
```

#### Test 5: Delete edges from node
```lua
local delete_result = index.delete_edges_from("aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa")
assert(delete_result.ok)

local edges_after_result = index.find_edges(
  "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa",
  "out",
  nil
)
assert(edges_after_result.ok)
assert(#edges_after_result.value == 0)
```

#### Test 6: Query both directions
```lua
-- Setup: node A -> node B, node C -> node A
local edge1 = types.Edge_new("A_uuid", "B_uuid", "wikilink", nil)
local edge2 = types.Edge_new("C_uuid", "A_uuid", "wikilink", nil)
index.insert_edge(edge1.value)
index.insert_edge(edge2.value)

local both_result = index.find_edges("A_uuid", "both", nil)
assert(both_result.ok)
assert(#both_result.value == 2)
```

#### Test 7: Idempotent insert
```lua
local edge = types.Edge_new("A_uuid", "B_uuid", "wikilink", nil)
local insert1 = index.insert_edge(edge.value)
local insert2 = index.insert_edge(edge.value)

assert(insert1.ok)
assert(insert2.ok)  -- Should succeed even if already exists
```

#### Test 8: Invalid inputs
```lua
-- Invalid UUID
local invalid_result = index.find_edges("not-a-uuid", "out", nil)
assert(not invalid_result.ok)

-- Invalid direction
local invalid_dir = index.find_edges(valid_uuid, "sideways", nil)
assert(not invalid_dir.ok)

-- Invalid kind
local invalid_kind = index.find_edges(valid_uuid, "out", "invalid_kind")
assert(not invalid_kind.ok)
```

## Dependencies
- `lua/lifemode/domain/types.lua` (Edge_new) - Phase 26 ✓
- `lua/lifemode/infra/index/sqlite.lua` (adapter.exec, adapter.query) - Phase 20 ✓
- `lua/lifemode/infra/index/schema.lua` (edges table) - Phase 19 ✓

## Acceptance Criteria
- [ ] insert_edge() stores edges in database
- [ ] delete_edges_from() removes all outgoing edges
- [ ] find_edges() queries by direction (in/out/both)
- [ ] find_edges() filters by kind when specified
- [ ] Idempotent inserts (no error on duplicate)
- [ ] Proper validation (UUID format, direction, kind)
- [ ] Tests pass

## Design Decisions

### Decision: Context field not stored
**Rationale:** The edges table schema doesn't include a context column. For MVP, we'll ignore edge.context when persisting. This can be added in a future schema migration if needed. The domain Edge still has the context field for future use.

### Decision: Idempotent insert_edge
**Rationale:** Use INSERT OR IGNORE pattern. If edge already exists (same from/to/kind), treat as success. This prevents errors when re-parsing unchanged wikilinks and makes the API easier to use.

### Decision: delete_edges_from deletes only outgoing
**Rationale:** When re-parsing a node, we only need to delete edges FROM that node (outgoing). Edges TO that node (backlinks) should remain - they're owned by other nodes. This matches the ownership model: each node owns its outgoing edges.

### Decision: find_edges returns domain Edge objects
**Rationale:** Convert database rows to domain Edge objects using Edge_new. This maintains layer boundary - callers work with domain objects, not raw database rows. If database row is corrupted (invalid kind), return error.

### Decision: Validate kind parameter in find_edges
**Rationale:** Even though kind is optional, if provided it must be valid. This catches typos early ("wikilnk" → error) rather than silently returning empty results.

### Decision: "both" direction uses OR query
**Rationale:** Simple OR query is sufficient for MVP. For large graphs, this might be slow, but premature optimization is evil. Can add UNION query if profiling shows this is a bottleneck.
