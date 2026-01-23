# Phase 38: Jump to Source (`gd`)

## Overview
Enable jumping from citation to source file with `gd` keymap. If source file doesn't exist, offer to create it.

## Architecture

This phase needs multiple layers:
1. **Application layer** (`lua/lifemode/app/citation.lua`): Business logic for finding citation under cursor
2. **UI layer** (`lua/lifemode/ui/keymaps.lua`): Register `gd` keymap
3. **UI layer** (`lua/lifemode/ui/commands.lua`): `:LifeModeEditSource` command

## Function Signatures

### `app/citation.lua` (new file)

#### `M.get_citation_under_cursor() → Result<{key: string, scheme: string}>`
Detect if cursor is on a citation and extract its key.

**Logic:**
```lua
function M.get_citation_under_cursor()
  -- Get current line
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1  -- 0-indexed to 1-indexed

  -- Parse citations from line
  local citations = domain_citation.parse_citations(line)

  -- Find citation containing cursor position
  for _, cit in ipairs(citations) do
    -- Calculate position of @key in line
    local start_pos = line:find("@" .. cit.key, 1, true)
    if start_pos then
      local end_pos = start_pos + #cit.raw - 1
      if col >= start_pos and col <= end_pos then
        return Ok({key = cit.key, scheme = cit.scheme})
      end
    end
  end

  return Err("No citation under cursor")
end
```

#### `M.get_source_path(key) → string`
Compute path to source file for a citation key.

**Logic:**
```lua
function M.get_source_path(key)
  local vault_path = config.get("vault_path")
  return vault_path .. "/.lifemode/sources/" .. key .. ".yaml"
end
```

#### `M.jump_to_source() → Result<()>`
Main orchestration function - find citation, jump to source or offer to create.

**Logic:**
```lua
function M.jump_to_source()
  -- Get citation under cursor
  local cit_result = get_citation_under_cursor()
  if not cit_result.ok then
    return Err(cit_result.error)
  end

  local citation = cit_result.value
  local source_path = get_source_path(citation.key)

  -- Check if source exists
  if vim.fn.filereadable(source_path) == 1 then
    -- Open existing source
    vim.cmd.edit(source_path)
    return Ok(nil)
  end

  -- Source doesn't exist - ask user
  local choice = vim.fn.confirm(
    "Source file not found: " .. citation.key .. ".yaml\nCreate it?",
    "&Yes\n&No",
    2  -- default to No
  )

  if choice == 1 then
    -- Create source file
    local create_result = create_source_file(source_path, citation.key)
    if not create_result.ok then
      return Err(create_result.error)
    end
    vim.cmd.edit(source_path)
    return Ok(nil)
  end

  return Err("Source file not found and user declined to create")
end
```

#### `M.create_source_file(path, key) → Result<()>`
Create a new source YAML file with template.

**Logic:**
```lua
function M.create_source_file(path, key)
  -- Ensure .lifemode/sources directory exists
  local dir = vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  -- Create template YAML
  local template = string.format([[---
key: %s
title: ""
author: ""
year: ""
type: article
url: ""
notes: ""
]], key)

  -- Write file
  local file = io.open(path, "w")
  if not file then
    return Err("Failed to create source file: " .. path)
  end
  file:write(template)
  file:close()

  return Ok(nil)
end
```

### `ui/commands.lua`

#### `:LifeModeEditSource` command
User can invoke this command to jump to source under cursor.

```lua
vim.api.nvim_create_user_command("LifeModeEditSource", function()
  local citation_app = require("lifemode.app.citation")
  local result = citation_app.jump_to_source()

  if not result.ok then
    vim.notify("[LifeMode] " .. result.error, vim.log.levels.ERROR)
  end
end, {})
```

### `ui/keymaps.lua`

#### `gd` keymap
Map `gd` to jump to source (only in markdown files).

```lua
-- In setup_keymaps(), add:
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.keymap.set("n", "gd", ":LifeModeEditSource<CR>", {
      buffer = true,
      noremap = true,
      silent = true,
      desc = "LifeMode: Jump to citation source",
    })
  end,
})
```

## Data Flow

1. User presses `gd` on citation `@smith2020`
2. Keymap triggers `:LifeModeEditSource`
3. Command calls `citation_app.jump_to_source()`
4. App detects citation under cursor → `{key="smith2020", scheme="bibtex"}`
5. App computes path: `~/vault/.lifemode/sources/smith2020.yaml`
6. If exists: open file
7. If not exists: prompt user to create
8. If user says yes: create template file and open

## Integration Tests

Manual QA required (vim.fn.confirm() is interactive):

### Test 1: Jump to existing source
1. Create source file: `~/vault/.lifemode/sources/test123.yaml`
2. In a markdown file, write `@test123`
3. Move cursor to `@test123`
4. Press `gd`
5. Expected: Opens `test123.yaml`

### Test 2: Create missing source
1. In markdown file, write `@newkey`
2. Move cursor to `@newkey`
3. Press `gd`
4. Expected: Prompt "Create it?"
5. Choose Yes
6. Expected: Creates file with template, opens it

### Test 3: Not on citation
1. Move cursor to plain text (not a citation)
2. Press `gd`
3. Expected: Error notification "No citation under cursor"

### Test 4: Command invocation
1. Move cursor to `@smith2020`
2. Run `:LifeModeEditSource`
3. Expected: Same behavior as `gd`

## Dependencies

**Existing:**
- `domain/citation.parse_citations()` - parse citations from text (Phase 36)
- `config.get("vault_path")` - get vault root
- `vim.fn.confirm()` - prompt user
- `vim.cmd.edit()` - open file

**New:**
- `app/citation.lua` - new file with business logic
- Update `ui/commands.lua` - add `:LifeModeEditSource`
- Update `ui/keymaps.lua` - add `gd` autocmd

## Notes

- `gd` is Vim's built-in "go to definition" - we override it for markdown files only
- Buffer-local keymap (only active in markdown buffers)
- Source files stored in `.lifemode/sources/{key}.yaml`
- Template YAML has common bibliography fields
- User can manually edit/enhance template after creation
- Future: Phase 39 will load custom citation schemes from these YAML files
