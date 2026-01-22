# Phase 16: Narrow to Node - Implementation Plan

## Overview
Implement true narrowing: create a scratch buffer showing only a single node's content, hiding the rest of the file. This provides focused editing without distraction.

## Module: `lua/lifemode/app/narrow.lua`

### Function Signatures

#### 1. `narrow_to_current()`
**Purpose:** Narrow to the node at cursor position

**Parameters:** None (uses current buffer and cursor position)

**Returns:** `Result<()>`

**Behavior:**
1. Get node at cursor using `extmark.get_node_at_cursor()`
2. If no node found, return Err("Not on a node")
3. Extract node lines using `buf.get_lines(bufnr, node_start, node_end + 1)`
4. Get node title (first non-frontmatter line or "Untitled")
5. Create scratch buffer with name `*Narrow: <title>*`
6. Copy node content to scratch buffer
7. Store narrow context in buffer-local variable:
   ```lua
   vim.b.lifemode_narrow = {
     source_file = vim.api.nvim_buf_get_name(source_bufnr),
     source_bufnr = source_bufnr,
     source_uuid = node_uuid,
     source_range = {start = node_start, end = node_end},
     original_cursor = cursor_pos,
   }
   ```
8. Set buffer options:
   - `buftype = "nofile"`
   - `bufhidden = "hide"`
   - `swapfile = false`
   - `buflisted = false`
9. Set statusline: `vim.wo.statusline = "[NARROW: " .. title .. "]"`
10. Set window border to cyan (#5fd7ff)
11. Add virtual text hint at top: "↑ Context hidden. <leader>nw to widen"

**Edge cases:**
- Cursor not on a node: Return clear error
- Node at EOF: Handle node_end boundary correctly
- Empty node: Still narrow (show just frontmatter)

### Data Structures

**Narrow context (buffer-local):**
```lua
b:lifemode_narrow = {
  source_file = "/path/to/file.md",
  source_bufnr = 5,
  source_uuid = "a1b2c3d4-...",
  source_range = {start = 10, end = 50},
  original_cursor = {line = 15, col = 0},
}
```

**Scratch buffer naming:**
- Format: `*Narrow: <title>*`
- Title extracted from first heading or content line
- Fallback: "Untitled"

### UI Elements

**Statusline:**
```lua
vim.wo.statusline = "[NARROW: " .. title .. "]"
```

**Window border:**
```lua
vim.api.nvim_win_set_config(0, {
  border = "rounded",
  style = "minimal",
})
vim.api.nvim_set_hl(0, "FloatBorder", {fg = "#5fd7ff"})
```

Wait, that's not right for window borders. Let me check how to set window borders properly...

Actually, for Phase 16 we just need the statusline. Window borders and floating windows are more complex and may be for Phase 18 (Jump between contexts). Let me simplify to just:
- Statusline change
- Virtual text hint
- Buffer options

**Virtual text hint:**
```lua
local ns = vim.api.nvim_create_namespace("lifemode_narrow_hint")
vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
  virt_text = {{"↑ Context hidden. <leader>nw to widen", "Comment"}},
  virt_text_pos = "overlay",
})
```

### Helper Functions

#### `extract_title(lines)`
**Purpose:** Extract title from node content for buffer name

**Logic:**
1. Skip frontmatter lines (first `---` block)
2. Find first non-empty line
3. If line starts with `#`, extract heading text
4. Otherwise, take first 50 chars
5. Fallback: "Untitled"

### Integration Points

**Dependencies:**
- `infra.nvim.extmark.get_node_at_cursor()` - find node
- `infra.nvim.buf.get_lines(bufnr, start, end)` - extract content
- `infra.nvim.buf.set_lines(bufnr, start, end, lines)` - populate scratch

**Used by (future):**
- Phase 17 (Widen) - reads `b:lifemode_narrow` context
- Phase 18 (Jump) - switches between narrow and context

## UI Commands & Keymaps

**Command:**
```lua
:LifeModeNarrow
```

**Keymap:**
```lua
<leader>nn  (default, configurable via config.keymaps.narrow)
```

## Integration Tests

### Test 1: Narrow to Single Node
```lua
-- Create buffer with one node
local bufnr = create_buffer_with_content([[
---
id: test-uuid
created: 1234567890
---
# Test Node
Content here.
]])

-- Parse and mark (creates extmarks)
parse_buffer.parse_and_mark_buffer(bufnr)

-- Set cursor on node
vim.api.nvim_set_current_buf(bufnr)
vim.api.nvim_win_set_cursor(0, {5, 0})  -- On content line

-- Narrow
local result = narrow.narrow_to_current()
assert(result.ok)

-- Verify scratch buffer created
local narrow_bufnr = vim.api.nvim_get_current_buf()
assert(narrow_bufnr ~= bufnr, "Should be in new buffer")

-- Verify buffer name
local buf_name = vim.api.nvim_buf_get_name(narrow_bufnr)
assert(buf_name:match("*Narrow:"), "Buffer name should start with *Narrow:")

-- Verify content
local lines = vim.api.nvim_buf_get_lines(narrow_bufnr, 0, -1, false)
assert(#lines == 6, "Should have frontmatter + content")

-- Verify buffer options
assert(vim.bo[narrow_bufnr].buftype == "nofile")
assert(vim.bo[narrow_bufnr].swapfile == false)

-- Verify narrow context stored
assert(vim.b[narrow_bufnr].lifemode_narrow ~= nil)
assert(vim.b[narrow_bufnr].lifemode_narrow.source_uuid == "test-uuid")
```

### Test 2: Narrow with Multiple Nodes
```lua
-- Create buffer with 2 nodes
local bufnr = create_buffer_with_content([[
---
id: node-1
created: 1234567890
---
First node.

---
id: node-2
created: 1234567890
---
Second node.
]])

parse_buffer.parse_and_mark_buffer(bufnr)

-- Narrow to second node
vim.api.nvim_set_current_buf(bufnr)
vim.api.nvim_win_set_cursor(0, {10, 0})  -- On second node

local result = narrow.narrow_to_current()
assert(result.ok)

-- Verify only second node visible
local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false)
assert(#lines == 4)  -- Frontmatter + content of node-2 only
assert(not vim.fn.search("First node", "n"), "Should not see first node")
```

### Test 3: Error When Not On Node
```lua
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {"Just text", "No nodes"})
vim.api.nvim_set_current_buf(bufnr)

local result = narrow.narrow_to_current()
assert(not result.ok)
assert(result.error:match("no extmark") or result.error:match("Not on"))
```

### Test 4: Command and Keymap Registration
```lua
-- Setup commands
commands.setup_commands()

-- Verify command exists
local commands_list = vim.api.nvim_get_commands({})
assert(commands_list["LifeModeNarrow"] ~= nil)

-- Setup keymaps
keymaps.setup_keymaps()

-- Verify keymap exists
local maps = vim.api.nvim_get_keymap("n")
local found = false
for _, map in ipairs(maps) do
  if map.lhs == "<leader>nn" then
    found = true
    break
  end
end
assert(found, "Keymap should be registered")
```

## Dependencies
- `lifemode.infra.nvim.extmark` (get_node_at_cursor)
- `lifemode.infra.nvim.buf` (get_lines, set_lines)
- `lifemode.util` (Result type)
- `lifemode.config` (get keymaps)

## Acceptance Criteria
- [x] narrow_to_current() creates scratch buffer with node content only
- [x] Buffer name is `*Narrow: <title>*`
- [x] Narrow context stored in b:lifemode_narrow
- [x] Buffer options set correctly (nofile, no swap)
- [x] Statusline shows `[NARROW: <title>]`
- [x] Virtual text hint displayed
- [x] `:LifeModeNarrow` command works
- [x] `<leader>nn` keymap works
- [x] Error handling when not on node
- [x] Works with multiple nodes in buffer

## Deferred (Future Phases)
- Window border styling (may require floating window, not regular buffer)
- Widen functionality (Phase 17)
- Jump between narrow and context (Phase 18)
