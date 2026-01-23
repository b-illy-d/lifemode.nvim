# Phase 32: Transclusion Expansion

## Overview
Implement recursive transclusion expansion in the domain layer. This is pure logic with no I/O.

## Function Signatures

### `M.expand(content, visited, depth, max_depth, fetch_fn) → Result<string>`
Main expansion function.

**Parameters:**
- `content: string` - text containing transclusion tokens
- `visited: {[uuid] = true}` - set of UUIDs in current path (for cycle detection)
- `depth: number` - current recursion depth (0 = root call)
- `max_depth: number` - maximum recursion depth allowed (default 10)
- `fetch_fn: function(uuid) → Result<Node>` - dependency injection for fetching nodes

**Returns:**
- `Result<string>` - expanded content or error

**Logic:**
1. Parse transclusion tokens from content using existing `M.parse()`
2. For each token:
   - Check cycle: if UUID in visited set, replace with cycle warning
   - Check depth: if depth >= max_depth, replace with depth warning
   - Add UUID to visited set (path-local copy)
   - Fetch node via fetch_fn
   - Recursively expand node content
   - Replace token with expanded content
   - Remove UUID from visited (backtrack)
3. Return fully expanded content

### Helper: `expand_token(token, content, visited, depth, max_depth, fetch_fn) → Result<string>`
Expands a single token within content.

**Parameters:**
- `token: {uuid, depth?, start_pos, end_pos}` - token to expand
- `content: string` - full content string (needed for replacement)
- `visited: {[uuid] = true}` - visited set
- `depth: number` - current depth
- `max_depth: number` - max depth
- `fetch_fn: function(uuid) → Result<Node>` - node fetcher

**Returns:**
- `Result<string>` - expanded token content

**Logic:**
1. Check cycle: `if visited[token.uuid]` → return `"⚠️ Cycle detected: {{uuid}}"`
2. Check depth: `if depth >= max_depth` → return `"⚠️ Max depth reached"`
3. Copy visited set (path-local)
4. Add `visited[token.uuid] = true`
5. Fetch node: `fetch_fn(token.uuid)`
   - If Err or nil → return `"⚠️ Node not found: {{uuid}}"`
6. Get node content (ignore depth for now, Phase 32 is just basic expansion)
7. Recursively expand: `M.expand(node.content, visited, depth + 1, max_depth, fetch_fn)`
8. Return expanded content

### Helper: `replace_token(content, token, replacement) → string`
String replacement utility.

**Parameters:**
- `content: string` - original content
- `token: {start_pos, end_pos}` - position to replace
- `replacement: string` - text to insert

**Returns:**
- `string` - content with token replaced

**Logic:**
- Use `string.sub` to splice:
  - `before = content:sub(1, token.start_pos - 1)`
  - `after = content:sub(token.end_pos + 1)`
  - `return before .. replacement .. after`

## Data Flow

```
expand(content, visited, depth, max_depth, fetch_fn)
  ↓
parse(content) → tokens[]
  ↓
for each token:
  ↓
  expand_token(token, ...) → expanded_content
    ↓
    visited[uuid] check (cycle)
    depth check (max)
    fetch_fn(uuid) → node
    expand(node.content, visited+uuid, depth+1, ...) [RECURSIVE]
  ↓
  replace_token(content, token, expanded_content)
  ↓
return fully expanded content
```

## Error Handling

**Cycle detected:**
- Replace token with: `"⚠️ Cycle detected: {{<uuid>}}"`
- Continue processing (non-fatal)

**Max depth reached:**
- Replace token with: `"⚠️ Max depth reached"`
- Continue processing (non-fatal)

**Node not found:**
- Replace token with: `"⚠️ Node not found: {{<uuid>}}"`
- Continue processing (non-fatal)

**All errors are inline replacements** - expansion never fails entirely.

## Integration Tests

### Test 1: Single transclusion
```lua
-- Given node A with content "Hello {{uuid-b}}"
-- And node B with content "World"
-- When expand(A.content, {}, 0, 10, fetch)
-- Then result = "Hello World"
```

### Test 2: Nested transclusion
```lua
-- Given node A: "Start {{uuid-b}}"
-- And node B: "Middle {{uuid-c}}"
-- And node C: "End"
-- When expand(A.content, {}, 0, 10, fetch)
-- Then result = "Start Middle End"
```

### Test 3: Cycle detection
```lua
-- Given node A: "A {{uuid-b}}"
-- And node B: "B {{uuid-a}}"
-- When expand(A.content, {}, 0, 10, fetch)
-- Then result contains "⚠️ Cycle detected"
```

### Test 4: Max depth enforcement
```lua
-- Given chain: A → B → C → D → ... (11 levels deep)
-- When expand(A.content, {}, 0, 10, fetch)
-- Then result contains "⚠️ Max depth reached"
```

### Test 5: Missing node
```lua
-- Given node A: "Hello {{missing-uuid}}"
-- When expand(A.content, {}, 0, 10, fetch)
-- Then result = "Hello ⚠️ Node not found: {{missing-uuid}}"
```

## Dependencies

**Existing:**
- `M.parse()` from Phase 31 (parse transclusion tokens)
- `util.Ok()`, `util.Err()` from util module

**Injected:**
- `fetch_fn(uuid) → Result<Node>` - provided by caller (app layer)
  - In tests: mock function
  - In production: `require("lifemode.infra.index").find_by_id`

## Notes

- Pure function, no I/O in this module
- Visited set is path-local (copied on recursion, backtracked after)
- Token depth field (`:N` syntax) is parsed but **not used yet** - just expand full node content
- Subtree expansion (respecting depth) will be Phase 33 or later
- This phase establishes the core recursive algorithm
