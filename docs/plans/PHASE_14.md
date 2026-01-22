# Phase 14: Extmark Tracking - Implementation Plan

## Overview
Build extmark tracking infrastructure for node boundaries in buffers. Extmarks provide fast in-buffer queries for node detection and navigation.

## Module: `lua/lifemode/infra/nvim/extmark.lua`

### Function Signatures

#### 1. `set(bufnr, line, metadata)`
**Purpose:** Create extmark on specified line with node metadata

**Parameters:**
- `bufnr` (number): Buffer number
- `line` (number): Line number (0-indexed)
- `metadata` (table): Node metadata containing:
  - `node_id` (string): UUID of the node
  - `node_start` (number): Start line of node
  - `node_end` (number): End line of node

**Returns:** `Result<extmark_id>` where extmark_id is number

**Behavior:**
- Create namespace `lifemode_nodes` if not exists
- Set extmark at specified line with metadata
- Return extmark ID on success

#### 2. `query(bufnr, line)`
**Purpose:** Retrieve node metadata from extmark at line

**Parameters:**
- `bufnr` (number): Buffer number
- `line` (number): Line number (0-indexed)

**Returns:** `Result<metadata>` where metadata is table with:
- `node_id` (string)
- `node_start` (number)
- `node_end` (number)
- `extmark_id` (number)

**Behavior:**
- Get extmarks at specified line in `lifemode_nodes` namespace
- If no extmark found, return Err
- If extmark found, return metadata

#### 3. `delete(bufnr, extmark_id)`
**Purpose:** Remove extmark by ID

**Parameters:**
- `bufnr` (number): Buffer number
- `extmark_id` (number): Extmark ID to delete

**Returns:** `Result<()>`

**Behavior:**
- Delete extmark from `lifemode_nodes` namespace
- Return Ok(nil) on success, Err on failure

#### 4. `get_node_at_cursor()`
**Purpose:** Get node metadata at current cursor position

**Parameters:** None (uses current buffer and cursor position)

**Returns:** `Result<{uuid, start, end}>` where:
- `uuid` (string): Node UUID
- `start` (number): Start line
- `end` (number): End line

**Behavior:**
- Get current buffer number
- Get current cursor position (line, col)
- Query extmarks at cursor line
- Return node metadata if found

### Data Structures

**Metadata table:**
```lua
{
  node_id = "a1b2c3d4-...",
  node_start = 10,
  node_end = 50
}
```

**Namespace:** `lifemode_nodes` (global for this plugin)

### Implementation Notes

1. Namespace creation: Use `vim.api.nvim_create_namespace("lifemode_nodes")` once, store ID
2. Extmark creation: Use `vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, opts)`
3. Extmark query: Use `vim.api.nvim_buf_get_extmarks(bufnr, ns, {line, 0}, {line, -1}, {details = true})`
4. Extmark deletion: Use `vim.api.nvim_buf_del_extmark(bufnr, ns, extmark_id)`

### Edge Cases
- Buffer not loaded: Return Err
- Line out of range: Neovim API will fail, catch and return Err
- No extmark at line: query() returns Err with clear message
- Multiple extmarks at same line: Take first one (shouldn't happen with our usage)

## Integration Tests

### Test 1: Set and Query
```lua
local extmark = require('lifemode.infra.nvim.extmark')
local bufnr = vim.api.nvim_create_buf(false, true)

local result = extmark.set(bufnr, 5, {
  node_id = "test-uuid",
  node_start = 5,
  node_end = 10
})

assert(result.ok)
local extmark_id = result.value

local query_result = extmark.query(bufnr, 5)
assert(query_result.ok)
assert(query_result.value.node_id == "test-uuid")
```

### Test 2: Delete
```lua
local delete_result = extmark.delete(bufnr, extmark_id)
assert(delete_result.ok)

local query_after = extmark.query(bufnr, 5)
assert(not query_after.ok)
```

### Test 3: Get Node at Cursor
```lua
vim.api.nvim_set_current_buf(bufnr)
vim.api.nvim_win_set_cursor(0, {6, 0})  -- line 6 (1-indexed for cursor)

local cursor_result = extmark.get_node_at_cursor()
assert(cursor_result.ok)
assert(cursor_result.value.uuid == "test-uuid")
```

## Dependencies
- `lifemode.util` (Result type)
- Neovim extmark API (built-in)

## Acceptance Criteria
- [x] set() creates extmark with metadata
- [x] query() retrieves metadata by line
- [x] delete() removes extmark
- [x] get_node_at_cursor() finds node at current position
- [x] All functions return Result type
- [x] Error handling for invalid inputs
