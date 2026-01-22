# Phase 11: Open Node in Buffer

## Overview

Infrastructure layer module for Neovim buffer operations.
Provides core primitives for opening files, reading, and modifying buffer content.

## Function Signatures

### `open(file_path) → Result<bufnr>`

Opens a file in a buffer and focuses it.

**Parameters:**
- `file_path` (string): Absolute path to file to open

**Returns:**
- `Ok(bufnr)` where bufnr is the buffer number (integer)
- `Err(<error_message>)` if file doesn't exist or can't be opened

**Process:**
1. Validate file_path is non-empty string
2. Check if file exists (use infra.fs.write.exists)
3. Use `vim.cmd.edit(file_path)` to open file
4. Get current buffer number with `vim.api.nvim_get_current_buf()`
5. Return buffer number

**Error handling:**
- File doesn't exist: return Err
- Invalid path: return Err
- vim.cmd.edit fails: wrap in pcall, return Err

### `get_lines(bufnr, start_line, end_line) → string[]`

Reads lines from a buffer.

**Parameters:**
- `bufnr` (number): Buffer number
- `start_line` (number): Start line (0-indexed)
- `end_line` (number): End line (0-indexed, exclusive)

**Returns:**
- Array of strings (lines)
- Empty array if buffer invalid or range invalid

**Process:**
1. Use `vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)`
2. Return result directly (Neovim API handles validation)

**Notes:**
- This function does NOT return Result<T> because Neovim API will error on invalid input
- Let Lua error propagate naturally for invalid bufnr
- Caller should handle errors with pcall if needed

### `set_lines(bufnr, start_line, end_line, lines) → Result<()>`

Writes lines to a buffer.

**Parameters:**
- `bufnr` (number): Buffer number
- `start_line` (number): Start line (0-indexed)
- `end_line` (number): End line (0-indexed, exclusive)
- `lines` (string[]): Lines to write

**Returns:**
- `Ok(nil)` on success
- `Err(<error_message>)` on failure

**Process:**
1. Validate lines is table
2. Wrap `vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, lines)` in pcall
3. If success: return Ok(nil)
4. If failure: return Err with error message

**Error handling:**
- Invalid bufnr: return Err
- Invalid range: return Err
- Buffer not modifiable: return Err

## Data Structures

None (simple primitives).

## Integration Tests

### Test 1: Open existing file
```lua
-- Given: file exists at path
-- When: open(file_path) called
-- Then:
--   - Returns Ok(bufnr)
--   - bufnr is valid buffer number
--   - Buffer is loaded and current
```

### Test 2: Open non-existent file
```lua
-- Given: file doesn't exist
-- When: open(file_path) called
-- Then:
--   - Returns Err with message about missing file
```

### Test 3: Get lines from buffer
```lua
-- Given: buffer with known content
-- When: get_lines(bufnr, 0, -1) called
-- Then:
--   - Returns array of all lines
--   - Content matches expected
```

### Test 4: Set lines in buffer
```lua
-- Given: valid buffer
-- When: set_lines(bufnr, 0, -1, new_lines) called
-- Then:
--   - Returns Ok(nil)
--   - Buffer content updated
--   - get_lines returns new content
```

### Test 5: Set lines with invalid buffer
```lua
-- Given: invalid bufnr (999999)
-- When: set_lines(999999, 0, 1, ["test"]) called
-- Then:
--   - Returns Err with meaningful message
```

## Dependencies

- `lifemode.util` (Ok, Err)
- `lifemode.infra.fs.write` (exists helper)
- Neovim API: `vim.cmd.edit`, `vim.api.nvim_get_current_buf`, `vim.api.nvim_buf_get_lines`, `vim.api.nvim_buf_set_lines`

## Notes

- This is INFRASTRUCTURE layer (Neovim API adapter)
- Keep it simple: thin wrapper around Neovim buffer API
- get_lines doesn't use Result<T> pattern (follows Neovim conventions)
- open() and set_lines() use Result<T> for error propagation
- No business logic here, just safe API access
