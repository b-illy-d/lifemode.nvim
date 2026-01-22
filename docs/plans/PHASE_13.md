# Phase 13: Keymaps Setup

## Overview

UI layer module for setting up user keymaps.
Registers keyboard shortcuts for LifeMode commands, respecting user configuration.

## Function Signatures

### `setup_keymaps() → ()`

Registers all LifeMode keymaps based on config.

**Parameters:** None

**Returns:** Nothing (side effects: creates keymaps)

**Process:**
1. Get keymaps config via `config.get("keymaps")`
2. For each configured keymap:
   - `new_node`: map to `:LifeModeNewNode<CR>`
3. Use `vim.keymap.set()` with mode "n" (normal mode)
4. Set opts: `{ noremap = true, silent = true, desc = "LifeMode: <description>" }`

**Keymaps to register:**
- `new_node` → `:LifeModeNewNode<CR>` (desc: "LifeMode: Create new node")
- (Future phases will add: narrow, widen, jump_context, sidebar)

**Error handling:**
- Config not initialized: error (config.get will throw)
- Invalid keymap value: skip silently (allow empty string or nil to disable)

## Data Structures

None (pure UI registration).

## Integration Tests

### Test 1: Keymap registered successfully
```lua
-- Given: config with default keymaps
-- When: setup_keymaps() called
-- Then:
--   - <leader>nc keymap exists
--   - Triggering keymap executes :LifeModeNewNode
--   - File created, buffer opened
```

### Test 2: Custom keymap respected
```lua
-- Given: config with custom keymap { new_node = "<leader>nn" }
-- When: setup_keymaps() called
-- Then:
--   - <leader>nn keymap exists
--   - <leader>nc keymap does NOT exist
--   - Custom keymap triggers command
```

### Test 3: Disabled keymap
```lua
-- Given: config with { new_node = "" }
-- When: setup_keymaps() called
-- Then:
--   - No keymap registered
--   - No errors
```

## Integration Point

This phase requires updating `init.lua` to call `setup_keymaps()` and `setup_commands()`.

**Updated setup() flow:**
1. Validate config
2. Create augroup
3. Call `ui.commands.setup_commands()`
4. Call `ui.keymaps.setup_keymaps()`
5. Set _initialized flag

## Dependencies

- `lifemode.config` (get keymaps config)
- `lifemode.ui.commands` (commands must be registered first)
- Neovim API: `vim.keymap.set`

## Notes

- This is UI layer (user interaction)
- Keymaps are optional (user can disable by setting to empty string)
- Only register `new_node` keymap for now (other keymaps for future phases)
- Use silent=true to avoid command line noise
- Use desc= for which-key compatibility
- Must be called AFTER commands are registered
