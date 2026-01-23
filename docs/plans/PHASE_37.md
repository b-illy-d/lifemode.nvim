# Phase 37: Citation Edges in Index

## Overview
Store citation relationships in the index. Track which nodes cite which external sources.

## Key Design Decision

Citations reference external sources (e.g., `@smith2020`) not nodes in the vault. The current edges table has `(from_uuid, to_uuid, edge_type)` structure.

**Solution:** Repurpose `to_uuid` field to store citation keys for citation edges.
- Wikilink edges: both fields are UUIDs
- Transclusion edges: both fields are UUIDs
- Citation edges: `from_uuid` is UUID, `to_uuid` is source key (not a UUID)

This avoids adding a new table while supporting citation tracking.

## Function Signatures

### `M.insert_citation_edge(node_uuid, source_key) → Result<()>`
Store a citation relationship.

**Parameters:**
- `node_uuid: string` - UUID of node containing the citation
- `source_key: string` - citation key (e.g., "smith2020")

**Returns:**
- `Result<()>` - Ok on success, Err on failure

**Logic:**
```lua
function M.insert_citation_edge(node_uuid, source_key)
  if not validate_uuid(node_uuid) then
    return Err("invalid node UUID")
  end

  if type(source_key) ~= "string" or source_key == "" then
    return Err("source_key must be non-empty string")
  end

  local edge = {
    from = node_uuid,
    to = source_key,  -- Not a UUID!
    kind = "citation"
  }

  return insert_edge(edge)  -- Reuse existing function
end
```

### `M.find_nodes_citing(source_key) → Result<Node[]>`
Find all nodes that cite a given source.

**Parameters:**
- `source_key: string` - citation key to search for

**Returns:**
- `Result<Node[]>` - array of nodes citing this source

**Logic:**
```lua
function M.find_nodes_citing(source_key)
  if type(source_key) ~= "string" or source_key == "" then
    return Err("source_key must be non-empty string")
  end

  -- Query edges where to_uuid = source_key AND edge_type = 'citation'
  local query_sql = [[
    SELECT from_uuid
    FROM edges
    WHERE to_uuid = ? AND edge_type = 'citation'
  ]]

  -- Execute query to get UUIDs
  -- For each UUID, fetch node via find_by_id()
  -- Collect into array
  -- Return Ok(nodes)
end
```

### Sidebar Integration (not in index module)

The ROADMAP mentions "Display in sidebar under Citations section" but that's UI layer work. For this phase, just provide the query function. Sidebar integration will use `find_nodes_citing()` to populate the Citations section.

## Data Flow

1. User writes `@smith2020` in a node
2. Parser extracts citation (Phase 36)
3. App layer calls `insert_citation_edge(node_uuid, "smith2020")`
4. Edge stored: `(node_uuid, "smith2020", "citation")`
5. Later: query `find_nodes_citing("smith2020")` returns all citing nodes

## Testing Strategy

Following the pattern from earlier index phases, tests are split into:
1. **Manual validation tests** (tests/manual_test_citation_edges_no_sqlite.lua) - test input validation without requiring sqlite.lua dependency
2. **Integration tests** - would require sqlite.lua installation, deferred to manual QA

## Manual Validation Tests

### Test 1: Insert citation edge - validation
```lua
local result = index.insert_citation_edge(valid_uuid, "smith2020")
assert(result.ok)
```

### Test 2: Find nodes citing source
```lua
-- Insert two citation edges
index.insert_citation_edge(uuid1, "smith2020")
index.insert_citation_edge(uuid2, "smith2020")

-- Query
local result = index.find_nodes_citing("smith2020")
assert(result.ok)
assert.equals(2, #result.value)
```

### Test 3: Empty result for unknown source
```lua
local result = index.find_nodes_citing("unknown_key")
assert(result.ok)
assert.equals(0, #result.value)
```

### Test 4: Validation errors
```lua
-- Invalid UUID
local result = index.insert_citation_edge("not-uuid", "smith2020")
assert.is_false(result.ok)

-- Empty source key
result = index.insert_citation_edge(valid_uuid, "")
assert.is_false(result.ok)

-- Invalid source key type
result = index.find_nodes_citing(nil)
assert.is_false(result.ok)
```

### Test 5: Idempotent insertion
```lua
-- Insert same citation edge twice
index.insert_citation_edge(uuid, "smith2020")
index.insert_citation_edge(uuid, "smith2020")

-- Should succeed both times (INSERT OR IGNORE)
local result = index.find_nodes_citing("smith2020")
assert.equals(1, #result.value)  -- Only one node
```

### Test 6: Delete node removes citation edges
```lua
-- Insert citation edge
index.insert_citation_edge(uuid, "smith2020")

-- Delete node
index.delete_node(uuid)

-- Citation edge should be gone
local result = index.find_nodes_citing("smith2020")
assert.equals(0, #result.value)
```

## Dependencies

**Existing:**
- `insert_edge()` - can be reused for citation edges
- `validate_uuid()` - validates node UUIDs
- `find_by_id()` - fetch nodes by UUID
- `delete_node()` - already deletes all edges (including citations)

**New:**
- None - just two new functions in index/init.lua

## Notes

- Citation keys are NOT validated as UUIDs (they're not)
- This design is pragmatic - repurposes to_uuid field for citation keys
- Alternative would be new `citations` table with `(node_uuid, source_key)` schema
- Current approach is simpler, reuses existing edges infrastructure
- Future: if citation edges need more metadata (page numbers, quote text), migrate to separate table
