# Phase 15: Parse Buffer for Nodes - Implementation Plan

## Overview
Parse open markdown buffers to identify all nodes (each with frontmatter) and create extmarks to track their boundaries. This enables fast node lookups for navigation and narrowing.

## Module: `lua/lifemode/app/parse_buffer.lua`

### Function Signatures

#### 1. `parse_and_mark_buffer(bufnr)`
**Purpose:** Parse buffer to find all nodes and create extmarks for each

**Parameters:**
- `bufnr` (number): Buffer number to parse

**Returns:** `Result<Node[]>` where Node[] is array of parsed nodes

**Behavior:**
1. Read all lines from buffer via `infra.nvim.buf.get_lines(bufnr, 0, -1)`
2. Find all frontmatter blocks (lines starting with `---`)
3. For each frontmatter block:
   a. Identify node boundaries (frontmatter line to next `---` or EOF)
   b. Extract text for this node
   c. Parse node using `domain.node.parse(text)`
   d. If parse succeeds:
      - Create extmark at frontmatter line
      - Store node UUID and boundaries in extmark metadata
   e. If parse fails:
      - Log warning
      - Continue to next node
4. Return array of successfully parsed nodes

**Node Boundary Detection:**
- Node starts at line with `---` (beginning of frontmatter)
- Node ends at:
  - Line before next `---` (if another node follows), OR
  - Last line of buffer (if this is last node)

#### 2. `setup_autocommand()`
**Purpose:** Register autocommand to auto-parse buffers on load

**Parameters:** None

**Returns:** `Result<()>`

**Behavior:**
- Create autocommand group `LifeModeParsing`
- Register `BufReadPost *.md` → calls `parse_and_mark_buffer(bufnr)`
- Async execution (don't block buffer loading)
- Log errors but don't interrupt user

### Data Structures

**Node boundary:**
```lua
{
  start_line = 5,   -- Line where frontmatter starts (0-indexed)
  end_line = 42,    -- Last line of node content (0-indexed)
  uuid = "a1b2c3d4-...",
}
```

### Algorithm: Find All Nodes

```lua
function find_node_boundaries(lines)
  local boundaries = {}
  local current_start = nil

  for i, line in ipairs(lines) do
    if line:match("^%-%-%-%s*$") then
      if current_start then
        -- Found next node, close previous node
        table.insert(boundaries, {
          start_line = current_start - 1,  -- Convert to 0-indexed
          end_line = i - 2,  -- Line before this frontmatter (0-indexed)
        })
      end
      current_start = i
    end
  end

  -- Close last node
  if current_start then
    table.insert(boundaries, {
      start_line = current_start - 1,
      end_line = #lines - 1,  -- Last line (0-indexed)
    })
  end

  return boundaries
end
```

### Implementation Notes

1. **Line indexing:** Lua arrays are 1-indexed, Neovim line numbers are 0-indexed
   - Buffer lines from `get_lines`: 1-indexed array
   - Extmark positions: 0-indexed
   - **Always subtract 1 when converting to extmark line numbers**

2. **Error handling:** If individual node parse fails, log warning but continue
   - Don't fail entire buffer parse due to one malformed node
   - Graceful degradation

3. **Performance:** For large buffers, parsing may be slow
   - Run async in autocommand (don't block UI)
   - Future: lazy parsing (only parse visible nodes)

4. **Extmark cleanup:** Before creating new extmarks, optionally clear old ones
   - Or update existing extmarks if UUID matches
   - For Phase 15, just create new (simpler)

### Integration Points

**Dependencies:**
- `domain.node.parse(text)` - parse markdown to node
- `infra.nvim.buf.get_lines(bufnr, start, end)` - read buffer
- `infra.nvim.extmark.set(bufnr, line, metadata)` - create extmark

**Used by (future):**
- Phase 16 (Narrow to Node) - uses extmarks to find node at cursor
- Phase 17 (Widen) - uses extmarks to update node boundaries

## Integration Tests

### Test 1: Parse Single Node
```lua
local bufnr = create_buffer_with_content([[
---
id: test-uuid-1
created: 1234567890
---
This is node content.
]])

local result = parse_and_mark_buffer(bufnr)
assert(result.ok)
assert(#result.value == 1)
assert(result.value[1].id == "test-uuid-1")

-- Verify extmark created
local query = extmark.query(bufnr, 0)  -- Line 0 is frontmatter
assert(query.ok)
assert(query.value.node_id == "test-uuid-1")
assert(query.value.node_start == 0)
assert(query.value.node_end == 3)  -- Last line of content
```

### Test 2: Parse Multiple Nodes
```lua
local bufnr = create_buffer_with_content([[
---
id: node-1
created: 1234567890
---
First node content.

---
id: node-2
created: 1234567890
---
Second node content.
]])

local result = parse_and_mark_buffer(bufnr)
assert(result.ok)
assert(#result.value == 2)

-- Verify first extmark
local query1 = extmark.query(bufnr, 0)
assert(query1.ok)
assert(query1.value.node_id == "node-1")

-- Verify second extmark
local query2 = extmark.query(bufnr, 6)  -- Second frontmatter line
assert(query2.ok)
assert(query2.value.node_id == "node-2")
```

### Test 3: Handle Malformed Node
```lua
local bufnr = create_buffer_with_content([[
---
id: good-node
created: 1234567890
---
Good content.

---
missing: id
created: 1234567890
---
Bad node (no id).

---
id: another-good-node
created: 1234567890
---
More good content.
]])

local result = parse_and_mark_buffer(bufnr)
assert(result.ok)
assert(#result.value == 2)  -- Only good nodes parsed
assert(result.value[1].id == "good-node")
assert(result.value[2].id == "another-good-node")
```

### Test 4: Autocommand Setup
```lua
setup_autocommand()

-- Create markdown file and open
local file = write_temp_file([[
---
id: auto-uuid
created: 1234567890
---
Auto-parsed content.
]])

vim.cmd.edit(file)
local bufnr = vim.api.nvim_get_current_buf()

-- Wait for autocmd to fire (async)
vim.wait(100)

-- Verify extmark created
local query = extmark.query(bufnr, 0)
assert(query.ok)
assert(query.value.node_id == "auto-uuid")
```

## Dependencies
- `lifemode.domain.node` (parse)
- `lifemode.infra.nvim.buf` (get_lines)
- `lifemode.infra.nvim.extmark` (set)
- `lifemode.util` (Result type)

## Acceptance Criteria
- [x] parse_and_mark_buffer() finds all nodes in buffer
- [x] Creates extmark for each node at frontmatter line
- [x] Handles multiple nodes correctly
- [x] Handles malformed nodes gracefully (continues parsing)
- [x] Autocommand registered for BufReadPost *.md
- [x] All functions return Result type
- [x] Comprehensive error handling

## Edge Cases
- Empty buffer: Return Ok([])
- Buffer with no frontmatter: Return Ok([])
- Malformed frontmatter: Log warning, continue
- Very large buffer: Still parse (performance optimization is future work)
