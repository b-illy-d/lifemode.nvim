# Phase 18: Jump Between Narrow and Context - Implementation Plan

## Overview
Implement toggle functionality to jump between narrow view and source context, with visual highlighting of node boundaries in source.

## Module: `lua/lifemode/app/narrow.lua` (add to existing)

### Function Signatures

#### 1. `jump_context()`
**Purpose:** Toggle between narrow buffer and source buffer

**Parameters:** None (uses current buffer and context)

**Returns:** `Result<()>`

**Behavior:**

**Case 1: Currently in narrow buffer**
1. Check if `vim.b.lifemode_narrow` exists
2. If yes, extract source_bufnr and source_range
3. Switch to source buffer: `vim.api.nvim_set_current_buf(source_bufnr)`
4. Move cursor to node_start line
5. Highlight node boundaries (frontmatter to last line)
6. Store jump history: `vim.b[source_bufnr].lifemode_jump_from = narrow_bufnr`
7. Set up highlight timeout (2000ms to clear)

**Case 2: Currently in source buffer with jump history**
1. Check if `vim.b.lifemode_jump_from` exists
2. If yes, get narrow_bufnr from jump history
3. Verify narrow buffer still valid
4. Switch back to narrow buffer: `vim.api.nvim_set_current_buf(narrow_bufnr)`
5. Clear jump history
6. Position cursor at top of narrow buffer

**Case 3: Neither (regular buffer, no context)**
- Return Err("Not in narrow view or source with narrow history")

### Highlighting Implementation

**Highlight node boundaries:**
```lua
local ns = vim.api.nvim_create_namespace("lifemode_jump_highlight")

-- Add highlight extmark at node_start with end_row=node_end
vim.api.nvim_buf_set_extmark(bufnr, ns, node_start, 0, {
  end_row = node_end + 1,
  hl_group = "LifeModeNarrowContext",
  hl_eol = true,
})

-- Clear after 2 seconds
vim.defer_fn(function()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end, 2000)
```

**Highlight group definition:**
```lua
vim.api.nvim_set_hl(0, "LifeModeNarrowContext", {
  bg = "#2d3748",
  default = true
})
```

### Data Structures

**Jump history (buffer-local on source buffer):**
```lua
vim.b[source_bufnr].lifemode_jump_from = narrow_bufnr
```

This stores which narrow buffer we jumped from, enabling toggle back.

### State Machine

```
[Source Buffer]
    ↕ <leader>nj
[Narrow Buffer]

State tracking:
- Narrow buffer has: vim.b.lifemode_narrow
- Source buffer has: vim.b.lifemode_jump_from (when jumped from narrow)
```

### Integration Points

**Dependencies:**
- Current narrow.lua functions (narrow_to_current, widen)
- Neovim highlight API
- Buffer switching API

**Used by:**
- UI commands (`:LifeModeJumpContext`)
- UI keymaps (`<leader>nj`)

## UI Commands & Keymaps

**Command:**
```lua
:LifeModeJumpContext
```

**Keymap:**
```lua
<leader>nj  (default, configurable via config.keymaps.jump_context)
```

## Integration Tests

### Test 1: Jump from Narrow to Context
```lua
-- Create and narrow
local source_bufnr = setup_source_and_narrow()
local narrow_bufnr = vim.api.nvim_get_current_buf()

-- Jump to context
local result = narrow.jump_context()
assert(result.ok, "jump should succeed")

-- Verify in source buffer
assert(vim.api.nvim_get_current_buf() == source_bufnr, "should be in source")

-- Verify cursor at node start
local cursor = vim.api.nvim_win_get_cursor(0)
assert(cursor[1] == 1, "cursor should be at node start (line 1)")

-- Verify jump history stored
assert(vim.b[source_bufnr].lifemode_jump_from == narrow_bufnr, "jump history should be set")
```

### Test 2: Jump from Context Back to Narrow
```lua
-- Jump to context first
narrow.jump_context()
local source_bufnr = vim.api.nvim_get_current_buf()

-- Jump back to narrow
local result = narrow.jump_context()
assert(result.ok, "jump back should succeed")

-- Verify in narrow buffer
local current = vim.api.nvim_get_current_buf()
local is_narrow = vim.b[current].lifemode_narrow ~= nil
assert(is_narrow, "should be back in narrow buffer")

-- Verify jump history cleared
assert(vim.b[source_bufnr].lifemode_jump_from == nil, "jump history should be cleared")
```

### Test 3: Error When Not in Context
```lua
local normal_bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(normal_bufnr)

local result = narrow.jump_context()
assert(not result.ok, "should fail when no context")
assert(result.error:match("Not in narrow"), "error should mention context")
```

### Test 4: Highlighting Applied
```lua
-- Setup and jump to context
local source_bufnr = setup_source_and_narrow()
narrow.jump_context()

-- Check that highlight extmark exists
local ns = vim.api.nvim_create_namespace("lifemode_jump_highlight")
local extmarks = vim.api.nvim_buf_get_extmarks(source_bufnr, ns, 0, -1, {})
assert(#extmarks > 0, "highlight extmark should exist")

-- Wait for timeout
vim.wait(2100, function() return false end)

-- Verify highlight cleared
local extmarks_after = vim.api.nvim_buf_get_extmarks(source_bufnr, ns, 0, -1, {})
assert(#extmarks_after == 0, "highlight should be cleared after timeout")
```

### Test 5: Handle Closed Narrow Buffer
```lua
-- Jump to context
narrow.jump_context()
local source_bufnr = vim.api.nvim_get_current_buf()
local narrow_bufnr = vim.b[source_bufnr].lifemode_jump_from

-- Close narrow buffer
vim.api.nvim_buf_delete(narrow_bufnr, {force = true})

-- Try to jump back
local result = narrow.jump_context()
assert(not result.ok, "should fail when narrow buffer closed")
```

## Dependencies
- `lifemode.util` (Result type)
- `lifemode.config` (get keymaps)
- Neovim highlight API
- Neovim extmark API

## Acceptance Criteria
- [x] jump_context() toggles between narrow and source
- [x] Jumping from narrow to source highlights node boundaries
- [x] Highlight clears after 2 seconds
- [x] Jumping from source to narrow works if history exists
- [x] Jump history tracked in buffer-local variable
- [x] Error handling when not in context
- [x] Handle closed narrow buffer gracefully
- [x] `:LifeModeJumpContext` command works
- [x] `<leader>nj` keymap works

## Design Decisions

### Decision: Use buffer-local variable for jump history
**Rationale:** `vim.b[bufnr].lifemode_jump_from` ties history to specific buffer. When buffer deleted, history automatically cleared. Simple, no global state, no cleanup needed.

### Decision: Highlight via extmark with end_row
**Rationale:** Extmarks support range highlighting with `end_row` parameter. Creates highlight from node_start to node_end. Clean, built-in solution. Alternative (virtual text everywhere) would be complex and ugly.

### Decision: Clear highlight after 2s with vim.defer_fn
**Rationale:** User needs visual feedback of node boundaries, but persistent highlight would be distracting. 2 seconds (per SPEC) is enough to register location, then fade. Use `vim.defer_fn()` for async timeout.

### Decision: Toggle behavior not stack-based
**Rationale:** Simple toggle (narrow ↔ source) is intuitive. Stack-based (track multiple jumps) would be complex and likely unused. Keep it simple - one level of "jump back" is enough.

### Decision: Cursor to node_start when jumping to context
**Rationale:** User wants to see the node they were editing. Put cursor at first line of node (frontmatter). Predictable, consistent with narrow behavior.

### Decision: Error when narrow buffer no longer valid
**Rationale:** If user deleted narrow buffer while in source, jump back impossible. Return Err with clear message. Don't try to recreate narrow buffer - user probably closed it intentionally.
