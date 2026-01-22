# Phase 17: Widen from Narrow - Implementation Plan

## Overview
Implement widen operation: sync changes from narrow scratch buffer back to source file, updating extmarks if node size changed, and closing the narrow view.

## Module: `lua/lifemode/app/narrow.lua` (add to existing)

### Function Signatures

#### 1. `widen()`
**Purpose:** Sync narrow buffer changes back to source and close narrow view

**Parameters:** None (uses current buffer's narrow context)

**Returns:** `Result<()>`

**Behavior:**
1. Get current buffer number
2. Check if `vim.b.lifemode_narrow` exists
   - If not, return Err("Not in narrow view")
3. Read narrow context to get source info
4. Read all lines from narrow (scratch) buffer
5. Check if source buffer is still valid and loaded
   - If not loaded, open source file with `buf.open(source_file)`
6. Calculate node size change:
   - Old size: `original_end - original_start + 1`
   - New size: `#narrow_lines`
   - Delta: `new_size - old_size`
7. Update source buffer lines:
   - Replace lines from `node_start` to `node_end` with narrow_lines
   - Use `buf.set_lines(source_bufnr, node_start, node_end + 1, narrow_lines)`
8. Update extmark if node size changed:
   - Query extmark at `node_start` to get extmark_id
   - Delete old extmark
   - Create new extmark with updated `node_end`
9. Write source file to disk:
   - Use `:write` command on source buffer
10. Flash statusline (async):
    - Set `[Syncing...]` (300ms)
    - Set `[Saved]` (500ms)
    - Restore original statusline
11. Close narrow buffer:
    - Switch to source buffer
    - Delete narrow buffer
12. Restore cursor:
    - If possible, move to node_start line
    - Otherwise, use original_cursor position

**Edge cases:**
- Source buffer was closed: Reopen file
- Source file was modified externally: Still overwrite (trust narrow version)
- Node size changed: Update extmarks and shift subsequent nodes
- Empty narrow buffer: Error or allow?

### Helper Functions

#### `flash_statusline(messages, durations)`
**Purpose:** Show temporary statusline messages with timing

**Parameters:**
- `messages` (table): Array of status strings
- `durations` (table): Array of durations in ms

**Logic:**
```lua
local original_statusline = vim.wo.statusline
for i, msg in ipairs(messages) do
  vim.wo.statusline = msg
  vim.defer_fn(function()
    if i == #messages then
      vim.wo.statusline = original_statusline
    end
  end, durations[i])
end
```

Actually, this is tricky with async. Let me simplify to just set final status and let it restore naturally.

### Data Flow

```
Current Buffer (Narrow)
   ↓
[Check b:lifemode_narrow]
   ↓
[Read narrow lines]
   ↓
[Open/Get source buffer]
   ↓
[Update source buffer lines]
   ↓
[Update extmark if size changed]
   ↓
[Write source file]
   ↓
[Close narrow buffer]
   ↓
[Switch to source buffer]
   ↓
[Restore cursor]
```

### Integration Points

**Dependencies:**
- `infra.nvim.buf.set_lines()` - update source buffer
- `infra.nvim.buf.get_lines()` - read narrow buffer
- `infra.nvim.buf.open()` - reopen source file if needed
- `infra.nvim.extmark.query()` - find extmark for node
- `infra.nvim.extmark.delete()` - remove old extmark
- `infra.nvim.extmark.set()` - create updated extmark

**Used by:**
- UI commands (`:LifeModeWiden`)
- UI keymaps (`<leader>nw`)

## UI Commands & Keymaps

**Command:**
```lua
:LifeModeWiden
```

**Keymap:**
```lua
<leader>nw  (default, configurable via config.keymaps.widen)
```

## Integration Tests

### Test 1: Widen with Content Changes
```lua
-- Create source buffer with node
local uuid = "test-uuid-123"
local source_bufnr = create_buffer_with_content([[
---
id: ]] .. uuid .. [[

created: 1234567890
---
Original content.
]])

parse_buffer.parse_and_mark_buffer(source_bufnr)
vim.api.nvim_set_current_buf(source_bufnr)
vim.api.nvim_win_set_cursor(0, {5, 0})

-- Narrow to node
narrow.narrow_to_current()

-- Modify narrow buffer
local narrow_bufnr = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(narrow_bufnr, 4, 5, false, {"Modified content."})

-- Widen
local result = narrow.widen()
assert(result.ok, "widen should succeed")

-- Verify source buffer updated
local source_lines = vim.api.nvim_buf_get_lines(source_bufnr, 0, -1, false)
assert(source_lines[5] == "Modified content.", "source should be updated")

-- Verify back in source buffer
assert(vim.api.nvim_get_current_buf() == source_bufnr, "should be in source buffer")

-- Verify narrow buffer closed
assert(not vim.api.nvim_buf_is_valid(narrow_bufnr), "narrow buffer should be deleted")
```

### Test 2: Widen with Size Change (Add Lines)
```lua
-- Create and narrow
local source_bufnr = setup_source_and_narrow()
local narrow_bufnr = vim.api.nvim_get_current_buf()

-- Add lines to narrow buffer
vim.api.nvim_buf_set_lines(narrow_bufnr, -1, -1, false, {
  "New line 1",
  "New line 2"
})

-- Widen
narrow.widen()

-- Verify extmark updated with new end line
local extmark_result = extmark.query(source_bufnr, 0)
assert(extmark_result.ok)
assert(extmark_result.value.node_end == original_end + 2, "extmark end should increase")
```

### Test 3: Widen with Size Change (Remove Lines)
```lua
-- Create and narrow
local source_bufnr = setup_source_and_narrow()
local narrow_bufnr = vim.api.nvim_get_current_buf()

-- Remove lines from narrow buffer
vim.api.nvim_buf_set_lines(narrow_bufnr, 4, 5, false, {})

-- Widen
narrow.widen()

-- Verify extmark updated with new end line
local extmark_result = extmark.query(source_bufnr, 0)
assert(extmark_result.ok)
assert(extmark_result.value.node_end == original_end - 1, "extmark end should decrease")
```

### Test 4: Error When Not in Narrow View
```lua
local normal_bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(normal_bufnr)

local result = narrow.widen()
assert(not result.ok, "should fail when not in narrow view")
assert(result.error:match("Not in narrow"), "error should mention narrow")
```

### Test 5: Reopen Source File If Closed
```lua
-- Narrow to node
local source_bufnr = setup_source_and_narrow()
local source_file = vim.api.nvim_buf_get_name(source_bufnr)

-- Close source buffer
vim.api.nvim_buf_delete(source_bufnr, {force = true})

-- Widen should still work (reopens file)
local result = narrow.widen()
assert(result.ok, "should succeed even if source closed")

-- Verify file was reopened and updated
local new_source_bufnr = vim.fn.bufnr(source_file)
assert(new_source_bufnr ~= -1, "source should be reopened")
```

## Dependencies
- `lifemode.infra.nvim.buf` (get_lines, set_lines, open)
- `lifemode.infra.nvim.extmark` (query, delete, set)
- `lifemode.util` (Result type)
- `lifemode.config` (get keymaps)

## Acceptance Criteria
- [x] widen() syncs narrow buffer back to source
- [x] Source file written to disk
- [x] Extmark updated if node size changed
- [x] Narrow buffer closed after widen
- [x] Cursor restored to source buffer
- [x] Error handling when not in narrow view
- [x] Handles source buffer closed/reopened
- [x] `:LifeModeWiden` command works
- [x] `<leader>nw` keymap works
- [x] Status line flash (simplified: just show saved message)

## Design Decisions

### Decision: Trust narrow buffer as source of truth
**Rationale:** When user widens, narrow buffer is the canonical version. Overwrites source even if source was modified externally. User edited in narrow view, that's what they want saved.

### Decision: Update extmarks after buffer modification
**Rationale:** Extmarks may shift when lines added/removed. Query extmark to get ID, delete old, create new with updated boundaries. Keeps extmark system in sync.

### Decision: Reopen source file if closed
**Rationale:** User might have closed source buffer while in narrow view. Widen should still work - reopen file, update, save. Graceful handling.

### Decision: Simplify statusline flash for Phase 17
**Rationale:** Async statusline updates are complex (vim.defer_fn with timing coordination). For MVP, just show "[Saved]" briefly. Full animation sequence can be Phase 23+ polish.

### Decision: Write file to disk immediately
**Rationale:** User expects widen to persist changes. Don't rely on Neovim's auto-save. Explicit `:write` ensures changes on disk.

### Decision: Delete narrow buffer after widen
**Rationale:** Narrow buffer is ephemeral workspace. After syncing back, it's no longer needed. Clean up to avoid buffer clutter.
