# Phase 12: NewNode Command

## Overview

UI layer that exposes the capture workflow as a user-facing command.
First end-to-end user interaction: create node, save to disk, open in buffer.

## Function Signatures

### `new_node() → ()`

Command handler for `:LifeModeNewNode`.

**Parameters:** None

**Returns:** Nothing (side effects: creates file, opens buffer, shows notifications)

**Process:**
1. Call `app.capture.capture_node()` with empty content
2. If error: show vim.notify with error message at ERROR level, return early
3. If success: extract file_path from result
4. Call `infra.nvim.buf.open(file_path)` to open file
5. If error: show vim.notify with error message at ERROR level, return early
6. If success: show vim.notify with success message at INFO level
7. Position cursor on first line after frontmatter (line 4, column 0)

**Error handling:**
- Capture failure: notify user with error, don't open buffer
- Buffer open failure: notify user (file was created but can't be opened)
- All errors use vim.notify with vim.log.levels.ERROR

**Notifications:**
- Success: "[LifeMode] Created new node" (INFO level)
- Capture error: "[LifeMode] ERROR: {error_message}" (ERROR level)
- Open error: "[LifeMode] ERROR: Failed to open file: {error_message}" (ERROR level)

### `setup_commands() → ()`

Registers all LifeMode commands.

**Parameters:** None

**Returns:** Nothing

**Process:**
1. Create `:LifeModeNewNode` user command
2. Command calls `new_node()` function
3. Command has no arguments (nargs = 0)

## Data Structures

None (UI layer coordinates existing modules).

## Integration Tests

### Test 1: Successful command execution
```lua
-- Given: valid config with vault_path
-- When: `:LifeModeNewNode` executed
-- Then:
--   - File created in correct date directory
--   - File has valid frontmatter
--   - Buffer opened with file content
--   - Cursor positioned after frontmatter
--   - Success notification shown
```

### Test 2: Command with vault not configured
```lua
-- Given: config.get("vault_path") returns nil
-- When: `:LifeModeNewNode` executed
-- Then:
--   - Error notification shown
--   - No file created
--   - No buffer opened
--   - Original buffer remains current
```

### Test 3: Cursor positioning
```lua
-- Given: new node created
-- When: buffer opens
-- Then:
--   - Cursor on line 4 (first line after frontmatter)
--   - Cursor column 0
--   - User can immediately start typing content
```

## QA Manual Testing

Since this is the first user-facing command, add QA steps to `docs/QA.md`.

**QA Steps:**
1. Start Neovim with plugin loaded
2. Execute `:LifeModeNewNode`
3. Verify:
   - New buffer opens
   - Frontmatter visible (lines 1-3: ---, id: ..., created: ..., ---)
   - Cursor on line 4 (ready to type)
   - File created in vault at correct date path
   - Notification shows "Created new node"
4. Type some content
5. Save with `:w`
6. Check file on disk has frontmatter + content

## Dependencies

- `lifemode.app.capture` (capture_node)
- `lifemode.infra.nvim.buf` (open)
- Neovim API: `vim.api.nvim_create_user_command`, `vim.notify`, `vim.log.levels`, `vim.api.nvim_win_set_cursor`

## Notes

- This is UI layer (user-facing commands)
- No business logic here, pure coordination
- For now, command doesn't auto-narrow (that's Phase 16)
- Just creates file and opens it normally
- Notifications use Neovim's built-in vim.notify (respects user's notify config)
- Cursor positioning puts user immediately in edit mode after frontmatter
