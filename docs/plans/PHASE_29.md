# Phase 29: Backlinks in Sidebar - Implementation Plan

## Overview
Create a sidebar window that displays contextual information about the node at cursor, including metadata, backlinks, and outgoing links. The sidebar is a floating window on the right side showing "Relations" section with clickable links.

## Module: `lua/lifemode/ui/sidebar.lua` (new module)

### Function Signatures

#### `M.toggle_sidebar()`
**Purpose:** Show or hide the sidebar window

**Parameters:** None

**Returns:** `Result<()>`

**Behavior:**
1. Check if sidebar window already exists (stored in module state)
2. If exists and valid: close it, return Ok
3. If doesn't exist: create it, return Ok
4. Window state stored in module-level variable

**Error handling:**
- Window creation failure
- Invalid buffer/window handles

#### `M.render_sidebar(uuid)`
**Purpose:** Populate sidebar with node information

**Parameters:**
- `uuid` (string): UUID of the node to display info for

**Returns:** `Result<()>`

**Behavior:**
1. Validate UUID format
2. Query index for node metadata (find_by_id)
3. Query edges:
   - Backlinks: find_edges(uuid, "in", nil)
   - Outgoing: find_edges(uuid, "out", nil)
4. Build sidebar content:
   - Header: "Relations for <node_id>"
   - Section: "Backlinks (<count>)"
   - List backlinks with file paths
   - Section: "Outgoing Links (<count>)"
   - List outgoing links with file paths
5. Set buffer content
6. Apply syntax highlighting
7. Store node UUID in buffer variable for jump actions

**Rendering format:**
```
# Relations

## Backlinks (2)
- /path/to/node1.md
- /path/to/node2.md

## Outgoing (1)
- /path/to/node3.md
```

#### `M.create_sidebar_window()`
**Purpose:** Create the floating window for sidebar

**Parameters:** None

**Returns:** `Result<{bufnr, winnr}>`

**Behavior:**
1. Create scratch buffer (nofile, noswapfile, bufhidden=wipe)
2. Set buffer options:
   - buftype = "nofile"
   - swapfile = false
   - modifiable = false initially
3. Calculate window dimensions:
   - Width: 30% of editor width
   - Height: full editor height
   - Column: right edge (100% - width)
   - Row: 0
4. Create floating window with nvim_open_win
5. Set window options:
   - wrap = false
   - cursorline = true
   - number = false
   - relativenumber = false
6. Set window highlight: border with title "LifeMode Sidebar"
7. Store bufnr/winnr in module state
8. Return Ok({bufnr, winnr})

**Window config:**
```lua
{
  relative = "editor",
  width = math.floor(vim.o.columns * 0.3),
  height = vim.o.lines - 2,
  col = math.floor(vim.o.columns * 0.7),
  row = 0,
  style = "minimal",
  border = "rounded",
  title = " LifeMode ",
  title_pos = "center"
}
```

#### `M.jump_to_node()`
**Purpose:** Jump to the node under cursor in sidebar

**Parameters:** None

**Returns:** `Result<()>`

**Behavior:**
1. Get current line in sidebar buffer
2. Parse line to extract node UUID (stored in buffer variable as list)
3. Get line number (1-indexed), map to UUID in list
4. Query index for node by UUID to get file_path
5. Open file in main window
6. Focus main window
7. Return Ok

**Line mapping:**
- Store array of UUIDs in buffer variable
- Line → UUID mapping stored alongside rendered content
- When user presses <CR>, look up UUID for that line

#### Module State
```lua
local sidebar_state = {
  winnr = nil,      -- Window ID
  bufnr = nil,      -- Buffer ID
  current_uuid = nil  -- UUID of node currently displayed
}
```

### Integration with UI Layer

**Command:** `:LifeModeSidebar`
- Calls `sidebar.toggle_sidebar()`

**Keymap:** `<leader>ns`
- Maps to `:LifeModeSidebar`

**Buffer-local keymap in sidebar:** `<CR>`
- Calls `sidebar.jump_to_node()`
- Only active when cursor in sidebar buffer

### Test Plan

#### Test 1: Toggle sidebar
```lua
local sidebar = require('lifemode.ui.sidebar')

-- Open sidebar
local result1 = sidebar.toggle_sidebar()
assert(result1.ok)

-- Close sidebar
local result2 = sidebar.toggle_sidebar()
assert(result2.ok)
```

#### Test 2: Render sidebar with node
```lua
-- Assume node exists in index with UUID
local uuid = "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa"

-- Create sidebar and render
sidebar.toggle_sidebar()
local render_result = sidebar.render_sidebar(uuid)
assert(render_result.ok)

-- Check buffer has content
-- (Manual inspection - should show Relations section)
```

#### Test 3: Show backlinks
```lua
-- Setup: Create two nodes with edges
-- Node A -> Node B (wikilink)
-- Node C -> Node B (wikilink)
-- Open sidebar for Node B

sidebar.toggle_sidebar()
sidebar.render_sidebar(node_b_uuid)

-- Sidebar should show:
-- Backlinks (2)
-- - path/to/nodeA.md
-- - path/to/nodeC.md
```

#### Test 4: Jump to node from sidebar
```lua
-- Open sidebar with backlinks
sidebar.toggle_sidebar()
sidebar.render_sidebar(uuid)

-- Move cursor to backlink line
-- Press <CR>
local jump_result = sidebar.jump_to_node()
assert(jump_result.ok)

-- Should open the linked file in main window
```

#### Test 5: Empty backlinks
```lua
-- Node with no backlinks
local isolated_uuid = "bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb"

sidebar.render_sidebar(isolated_uuid)

-- Should show:
-- Backlinks (0)
-- (empty)
```

#### Test 6: Window dimensions
```lua
sidebar.toggle_sidebar()

-- Check window width is ~30% of editor
local winnr = sidebar_state.winnr
local width = vim.api.nvim_win_get_width(winnr)
local expected = math.floor(vim.o.columns * 0.3)
assert(math.abs(width - expected) < 5)  -- Allow small variance
```

## Dependencies
- `lua/lifemode/infra/index/init.lua` (find_by_id, find_edges) - Phase 28 ✓
- `lua/lifemode/infra/nvim/extmark.lua` (get_node_at_cursor) - Phase 14 ✓
- `lua/lifemode/domain/types.lua` (Edge) - Phase 26 ✓
- `lua/lifemode/ui/commands.lua` (for adding command) - Phase 12 ✓
- `lua/lifemode/ui/keymaps.lua` (for adding keymap) - Phase 13 ✓

## Acceptance Criteria
- [ ] toggle_sidebar() creates/closes floating window
- [ ] Window is 30% width, right side of editor
- [ ] render_sidebar() displays backlinks count and list
- [ ] render_sidebar() displays outgoing links count and list
- [ ] <CR> on link jumps to that node's file
- [ ] `:LifeModeSidebar` command works
- [ ] `<leader>ns` keymap works
- [ ] Empty backlinks handled gracefully

## Design Decisions

### Decision: Simple markdown-style rendering
**Rationale:** Use markdown-style headers (##) and lists (-) for sidebar content. This is readable, easy to generate, and can leverage built-in markdown syntax highlighting. No need for custom renderer for MVP.

### Decision: No Context section for MVP
**Rationale:** ROADMAP mentions "Context: metadata (type, created, tags)" section, but nodes don't have types or tags yet. Skip this section for Phase 29, add it when those features exist. Focus on Relations (backlinks/outgoing) which are immediately useful.

### Decision: Single module, no separate app/sidebar.lua
**Rationale:** Phase 30 mentions `lua/lifemode/app/sidebar.lua` for auto-refresh logic, but Phase 29 is just UI. Keep all sidebar logic in ui/sidebar.lua for now. If separation needed later for auto-refresh, can refactor in Phase 30.

### Decision: Store line → UUID mapping in buffer variable
**Rationale:** When rendering sidebar, store a mapping like `b:lifemode_sidebar_links = {line_num: uuid}`. This makes <CR> jump action simple - just look up current line number. Alternative (parsing line text) is fragile and slow.

### Decision: Floating window, not split
**Rationale:** ROADMAP specifies "floating window (right side, 30% width)". This provides better UX - doesn't mess with window layout, easily toggleable, visually distinct. Use nvim_open_win with relative="editor".

### Decision: Show file paths, not node titles
**Rationale:** For MVP, showing file_path from index is simplest. Extracting node titles would require parsing frontmatter or content, adding complexity. File paths are unambiguous and sufficient for navigation. Can enhance to show titles in future phase.

### Decision: No accordion/folds for MVP
**Rationale:** ROADMAP mentions "accordion-style folds" but that's complex UI. For MVP, just show both sections (Backlinks, Outgoing) always expanded. Folds can be added later if sidebar gets crowded with more sections.

### Decision: Module-level state for window handles
**Rationale:** Store sidebar winnr/bufnr in module-level variable (not global). This prevents multiple sidebars, makes toggle work correctly, and is simple. If multi-window support needed later, can refactor to per-tabpage state.
