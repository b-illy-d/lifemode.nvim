# Phase 30: Update Sidebar on Cursor Move - Implementation Plan

## Overview
Add autocommand to automatically refresh the sidebar when the cursor moves to a different node. This provides a dynamic, context-aware sidebar that follows the user's focus.

## Module: `lua/lifemode/app/sidebar.lua` (new module)

Wait, the ROADMAP says `lua/lifemode/app/sidebar.lua`, but Phase 29 created `lua/lifemode/ui/sidebar.lua`. Let me check DECISIONS.md to understand the rationale.

Actually, based on Phase 29's decision, all sidebar logic is in ui/sidebar.lua. For Phase 30, I'll create app/sidebar.lua as a thin application layer that orchestrates the auto-update logic.

### Function Signatures

#### `M.setup_auto_update()`
**Purpose:** Register autocommand for sidebar auto-refresh

**Parameters:** None

**Returns:** `Result<()>`

**Behavior:**
1. Create autocommand for `CursorHold` event
2. Pattern: `*.md` (markdown files only)
3. Callback:
   - Check if sidebar is open (ui.sidebar state)
   - If not open, do nothing (no-op for performance)
   - Get node UUID at cursor via extmark.get_node_at_cursor()
   - Compare to sidebar_state.current_uuid (from ui.sidebar)
   - If UUID changed: call ui.sidebar.render_sidebar(new_uuid)
   - If unchanged: do nothing (no-op for performance)
4. Debouncing: CursorHold has built-in delay (updatetime setting, default 4000ms)
   - ROADMAP says 500ms debounce, but CursorHold is triggered after updatetime
   - We can set updatetime, but that affects all Neovim plugins
   - Decision: Use CursorHold as-is (respects user's updatetime setting)
   - Document this in DECISIONS.md

**Error handling:**
- If get_node_at_cursor fails (cursor not in node), do nothing silently
- If render_sidebar fails, log warning but don't throw error

#### `M.refresh_if_needed()`
**Purpose:** Check if sidebar needs refresh and update if so

**Parameters:** None

**Returns:** `Result<()>`

**Behavior:**
1. Check if sidebar is open (access ui.sidebar state - need to expose getter)
2. If not open, return Ok immediately
3. Get node UUID at cursor
4. If fails (no node at cursor), return Ok silently
5. Get current UUID from sidebar state
6. Compare UUIDs
7. If different: call ui.sidebar.render_sidebar(new_uuid)
8. If same: return Ok (no-op)

**Performance:** This is called on CursorHold, so should be fast (<50ms)

### Integration with ui/sidebar.lua

Need to expose sidebar state checking:

#### In `ui/sidebar.lua`, add:
```lua
function M.is_open()
    return is_sidebar_open()
end

function M.get_current_uuid()
    return sidebar_state.current_uuid
end
```

### Autocommand Setup

**Where to call setup_auto_update():**
- In `lua/lifemode/init.lua` during plugin setup
- After ui commands/keymaps are set up

**Autocommand structure:**
```lua
vim.api.nvim_create_autocmd("CursorHold", {
    group = "LifeMode",  -- Existing augroup from init.lua
    pattern = "*.md",
    callback = function()
        M.refresh_if_needed()
    end,
})
```

### Test Plan

#### Test 1: Sidebar updates on cursor move
```lua
local app_sidebar = require('lifemode.app.sidebar')
local ui_sidebar = require('lifemode.ui.sidebar')

-- Open sidebar on node A
ui_sidebar.toggle_sidebar()

-- Move cursor to node B
-- Trigger CursorHold (wait for updatetime or :doautocmd)
vim.cmd('doautocmd CursorHold')

-- Sidebar should now show info for node B
```

#### Test 2: No-op when UUID unchanged
```lua
-- Open sidebar
ui_sidebar.toggle_sidebar()

-- Stay on same node
-- Trigger CursorHold
vim.cmd('doautocmd CursorHold')

-- Sidebar content unchanged (no flickering)
```

#### Test 3: No-op when sidebar closed
```lua
-- Sidebar is closed
-- Move cursor to different node
vim.cmd('doautocmd CursorHold')

-- No errors, sidebar stays closed
```

#### Test 4: Graceful handling when cursor not in node
```lua
-- Open sidebar
ui_sidebar.toggle_sidebar()

-- Move cursor to empty area (no node)
vim.cmd('doautocmd CursorHold')

-- No errors, sidebar keeps showing last node
```

#### Test 5: Auto-update after manual open
```lua
-- Open sidebar with <leader>ns
-- Sidebar shows node A

-- Move cursor to node B
-- Wait for CursorHold
-- Sidebar automatically updates to node B
```

## Dependencies
- `lua/lifemode/ui/sidebar.lua` (Phase 29) ✓
- `lua/lifemode/infra/nvim/extmark.lua` (get_node_at_cursor) - Phase 14 ✓
- Neovim autocommands system ✓

## Acceptance Criteria
- [ ] setup_auto_update() registers CursorHold autocommand
- [ ] Sidebar refreshes when cursor moves to different node
- [ ] No refresh when UUID unchanged (performance)
- [ ] No errors when sidebar closed
- [ ] No errors when cursor not in node
- [ ] Works in markdown files only (*.md pattern)

## Design Decisions

### Decision: Use CursorHold, not custom debouncing
**Rationale:** CursorHold is triggered after updatetime milliseconds of no cursor movement. This provides natural debouncing without custom timers. ROADMAP specifies 500ms, but CursorHold respects user's updatetime setting (default 4000ms). This is better UX - respects user configuration. If user wants faster updates, they can set updatetime globally. Alternative (vim.defer_fn custom debounce) adds complexity for marginal benefit.

### Decision: Create app/sidebar.lua, keep ui/sidebar.lua separate
**Rationale:** ROADMAP specifies lua/lifemode/app/sidebar.lua for auto-refresh logic. This follows layer separation - ui/sidebar.lua handles UI rendering, app/sidebar.lua handles application orchestration (when to refresh). Keeps concerns separate. ui/sidebar.lua is pure UI (toggle, render, jump), app/sidebar.lua is workflow (auto-update on cursor move).

### Decision: Silently ignore errors in auto-update
**Rationale:** Auto-update is background functionality. If cursor moves to non-node area, or sidebar render fails for some reason, don't spam user with errors. Just keep showing last valid state. Only explicit user actions (toggle sidebar, jump) should show errors. Background automation should be invisible when it fails.

### Decision: Expose is_open() and get_current_uuid() from ui/sidebar
**Rationale:** app/sidebar.lua needs to check if sidebar is open and what UUID is currently displayed. Rather than duplicating state, expose getters from ui/sidebar.lua. Single source of truth for sidebar state. Clean layer boundary - app layer queries ui layer state.

### Decision: No custom updatetime setting
**Rationale:** Don't override user's updatetime setting. This affects other plugins (like LSP hover, diagnostics). Respect user configuration. If they want faster sidebar updates, they can set updatetime globally in their config. Don't be opinionated about timing - let user control it.

### Decision: Only *.md files
**Rationale:** LifeMode is a markdown-based note system. Only .md files have nodes with extmarks. No point triggering auto-update in other file types. Pattern filter (*.md) makes autocommand more efficient.
