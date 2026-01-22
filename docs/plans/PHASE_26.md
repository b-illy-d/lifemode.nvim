# Phase 26: Edge Value Object - Implementation Plan

## Overview
Define Edge structure for representing relationships between nodes (wikilinks, transclusions, citations). Pure domain value object with validation.

## Module: `lua/lifemode/domain/types.lua` (add to existing)

### Data Structure

```lua
Edge = {
  from: string,     -- UUID of source node
  to: string,       -- UUID of target node
  kind: string,     -- "wikilink", "transclusion", "citation"
  context: string?  -- Optional: surrounding text where link appears
}
```

### Function Signatures

#### `M.Edge_new(from, to, kind, context)`
**Purpose:** Create and validate Edge value object

**Parameters:**
- `from` (string): Source node UUID
- `to` (string): Target node UUID
- `kind` (string): Edge type ("wikilink", "transclusion", "citation")
- `context` (string, optional): Surrounding text for context

**Returns:** `Result<Edge>`

**Behavior:**
1. Validate `from` is valid UUID
2. Validate `to` is valid UUID
3. Validate `kind` is one of allowed values
4. Create immutable Edge table
5. Return Ok(edge)

**Error cases:**
- from not a string → Err("Edge from must be a string")
- from not valid UUID → Err("Edge from must be a valid UUID v4")
- to not a string → Err("Edge to must be a string")
- to not valid UUID → Err("Edge to must be a valid UUID v4")
- kind not a string → Err("Edge kind must be a string")
- kind not valid → Err("Edge kind must be wikilink, transclusion, or citation")
- context not string/nil → Err("Edge context must be a string or nil")

### Validation

**Valid edge kinds:**
- `"wikilink"` - [[Node Title]] links
- `"transclusion"` - ![[Node Title]] embeds
- `"citation"` - [@node-id] references (future)

**UUID validation:**
- Reuse existing `is_valid_uuid()` from types.lua
- Version 4 UUID format

**Context:**
- Optional field
- If provided, must be string
- Stores surrounding text for backlink preview

### Immutability

Edge objects are immutable - once created, fields cannot be changed. To "modify" an edge, create a new one.

```lua
local edge_result = types.Edge_new(from_id, to_id, "wikilink", "See also: [[Node Title]]")
if edge_result.ok then
  local edge = edge_result.value
  -- edge.from, edge.to, edge.kind, edge.context are read-only
end
```

### Test Plan

#### Test 1: Create valid wikilink edge
```lua
local types = require("lifemode.domain.types")

local from = "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa"
local to = "bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb"

local result = types.Edge_new(from, to, "wikilink", "See [[Node B]]")

assert(result.ok, "Should create valid edge")
assert(result.value.from == from)
assert(result.value.to == to)
assert(result.value.kind == "wikilink")
assert(result.value.context == "See [[Node B]]")
```

#### Test 2: Create edge without context
```lua
local result = types.Edge_new(from, to, "transclusion")

assert(result.ok, "Should create edge without context")
assert(result.value.context == nil)
```

#### Test 3: Invalid from UUID
```lua
local result = types.Edge_new("not-a-uuid", to, "wikilink")

assert(not result.ok, "Should reject invalid from UUID")
assert(result.error:match("valid UUID"))
```

#### Test 4: Invalid to UUID
```lua
local result = types.Edge_new(from, "not-a-uuid", "wikilink")

assert(not result.ok, "Should reject invalid to UUID")
assert(result.error:match("valid UUID"))
```

#### Test 5: Invalid edge kind
```lua
local result = types.Edge_new(from, to, "invalid-kind")

assert(not result.ok, "Should reject invalid kind")
assert(result.error:match("wikilink, transclusion, or citation"))
```

#### Test 6: All valid edge kinds
```lua
local kinds = {"wikilink", "transclusion", "citation"}

for _, kind in ipairs(kinds) do
  local result = types.Edge_new(from, to, kind)
  assert(result.ok, "Should accept " .. kind)
  assert(result.value.kind == kind)
end
```

#### Test 7: Context validation
```lua
-- Valid: string context
local r1 = types.Edge_new(from, to, "wikilink", "context text")
assert(r1.ok)

-- Valid: nil context
local r2 = types.Edge_new(from, to, "wikilink", nil)
assert(r2.ok)

-- Invalid: number context
local r3 = types.Edge_new(from, to, "wikilink", 123)
assert(not r3.ok)
assert(r3.error:match("context must be a string or nil"))
```

## Dependencies
- `lifemode.util` (Result type)
- Existing `is_valid_uuid()` function in types.lua

## Acceptance Criteria
- [ ] Edge_new() validates all fields
- [ ] Supports wikilink, transclusion, citation kinds
- [ ] Optional context field
- [ ] Immutable value object
- [ ] Tests pass

## Design Decisions

### Decision: Edge is pure value object
**Rationale:** No behavior, just data validation. Fits domain layer - no I/O, no side effects. Edge relationships are managed by index layer, not Edge itself.

### Decision: Three edge kinds (wikilink, transclusion, citation)
**Rationale:** Covers core linking patterns in knowledge management:
- Wikilinks: explicit connections between ideas
- Transclusions: embedded content
- Citations: academic-style references
More kinds can be added later if needed (e.g., "alias", "see-also").

### Decision: Context is optional
**Rationale:** Useful for backlink preview ("mentioned in: See [[Node B]]") but not required. Some edges may not have meaningful context. Keeps API flexible.

### Decision: Validate both UUIDs
**Rationale:** Edges reference nodes. Invalid UUIDs would cause database foreign key violations later. Fail early with clear error messages.

### Decision: Immutable after creation
**Rationale:** Value object semantics - edges represent facts about relationships. To "change" a relationship, delete old edge and create new one. Prevents accidental mutation bugs.

### Decision: Simple string kind, not enum
**Rationale:** Lua doesn't have enums. String is clear, extensible, and easy to store in database. Validation ensures only valid kinds accepted.
