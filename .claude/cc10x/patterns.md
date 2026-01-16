# Project Patterns

## Architecture Patterns
- Neovim plugin structure: plugin/ for autoload guard, lua/ for module
- State management: Local state table with getters, _reset_state() for tests
- Config merging: vim.tbl_deep_extend('force', defaults, user_opts)

## Code Conventions
- No comments unless absolutely necessary (user requirement)
- Error messages: Use error() for setup validation
- Notifications: Use vim.notify() with log levels
- Module pattern: M = {}, return M

## File Structure
- lua/lifemode/init.lua: Main plugin module (setup, commands, state)
- lua/lifemode/view.lua: View buffer creation utilities
- lua/lifemode/extmarks.lua: Extmark-based span tracking for metadata
- lua/lifemode/parser.lua: Markdown block parser (headings, tasks, list items)
- plugin/lifemode.vim: Autoload guard
- tests/: Test files (manual tests for now)
- test_*.lua: Root-level test files for each feature
- Makefile: Test runner automation

## Testing Patterns
- Manual tests via nvim --headless for T00
- Test structure: Test validation, config, and commands
- Future: Will add plenary.nvim integration tests
- **Edge case testing required**: Happy path tests miss silent failures
- **Test both success and failure paths**: Type errors, edge cases, invalid input

## Common Gotchas
- Commands must be created after setup() is called
- Config validation must check for empty string, not just nil
- Buffer options set via nvim_buf_set_option, not direct vim.bo
- **CRITICAL: vim.tbl_deep_extend does NOT validate types - manual validation required**
- **CRITICAL: Check for whitespace-only strings, not just empty strings**
- **CRITICAL: nvim_create_user_command allows duplicate registration without error**
- **nvim_buf_set_option deprecated in 0.10+, use vim.bo[bufnr].option instead**

## Dependencies
- None yet (pure Lua + Neovim API)
- Future: plenary.nvim, telescope.nvim per SPEC.md

## Error Handling
- Setup errors: error() for invalid config (halts execution)
- Runtime errors: vim.notify() with ERROR level (non-blocking)
- Missing config: Check state.config, notify user
- **CRITICAL: Buffer API calls can fail - wrap in pcall for graceful errors**
- **CRITICAL: Validate all config types after merge, before use**

## Neovim API Patterns
- Buffer creation: nvim_create_buf(false, true) for unlisted, scratch
- Buffer options: Use vim.bo[bufnr].option = value (NOT nvim_buf_set_option - deprecated 0.10+)
  - buftype=nofile (compiled view, not file-backed)
  - swapfile=false (no swap for view buffers)
  - bufhidden=wipe (auto-cleanup when hidden)
  - filetype=lifemode (clear marking, enables ftplugin/syntax)
- Command registration: nvim_create_user_command with callback
- Window buffer switch: nvim_win_set_buf(0, bufnr)
- **Buffer API can fail - check return values or use pcall**
- **Unique buffer names**: Use counter pattern to avoid E95 errors on multiple creates

## Config Validation Pattern (REQUIRED)
```lua
function M.setup(opts)
  opts = opts or {}

  -- Duplicate setup guard
  if state.initialized then
    error('setup() already called - duplicate setup not allowed')
  end

  -- Required field validation (check BEFORE merge)
  if not opts.vault_root or opts.vault_root == '' then
    error('vault_root is required')
  end

  -- Type validation for required fields (check BEFORE merge)
  if type(opts.vault_root) ~= 'string' then
    error('vault_root must be a string')
  end

  -- Whitespace validation for required fields (check BEFORE merge)
  if vim.trim(opts.vault_root) == '' then
    error('vault_root cannot be whitespace only')
  end

  -- Merge config
  state.config = vim.tbl_deep_extend('force', default_config, opts)

  -- Type + range validation for ALL config fields (check AFTER merge)
  if type(state.config.max_depth) ~= 'number' or state.config.max_depth <= 0 then
    error('max_depth must be a positive number')
  end

  if type(state.config.auto_index_on_startup) ~= 'boolean' then
    error('auto_index_on_startup must be a boolean')
  end

  -- Set initialized flag at end
  state.initialized = true
end

function M._reset_state()
  state.config = nil
  state.initialized = false
end
```

## Silent Failure Patterns to Avoid
1. **Type mismatch**: Accepting wrong types that fail later
2. **Range errors**: Accepting negative/zero for positive-only values
3. **Whitespace strings**: Empty after trim but not empty string
4. **Duplicate registration**: Not checking if already initialized
5. **Unchecked API calls**: Buffer/window operations without pcall
6. **Generic errors**: Not providing user-friendly error messages

## Buffer Creation Validation Pattern (REQUIRED)
```lua
function M.create_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- CRITICAL: Validate buffer creation succeeded
  if bufnr == 0 or not bufnr then
    error('Failed to create buffer')
  end

  -- Safe to proceed with buffer operations
  vim.bo[bufnr].buftype = 'nofile'
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].bufhidden = 'wipe'
  vim.bo[bufnr].filetype = 'lifemode'

  return bufnr
end
```

**Why this matters:**
- nvim_create_buf returns 0 on failure (not nil, not error)
- Using bufnr=0 with vim.bo[0] operates on CURRENT buffer
- Silent data corruption: current buffer settings get modified
- Always validate: `if bufnr == 0 or not bufnr then error()`

## Silent Failure Testing Pattern
```lua
-- Test API failure modes by mocking
local original_api = vim.api.nvim_create_buf
vim.api.nvim_create_buf = function()
  return 0  -- Simulate failure
end

local success, result = pcall(my_function)
-- Check: Did function detect failure?
-- Check: Was error raised or silent corruption?

vim.api.nvim_create_buf = original_api
```

**Testing checklist for buffer operations:**
1. Mock nvim_create_buf returning 0
2. Mock nvim_buf_set_name throwing error
3. Mock nvim_win_set_buf throwing error
4. Test rapid buffer creation (race conditions)
5. Test counter edge cases (overflow)
6. Verify buffer settings actually applied
7. Test state validation (functions without setup)

## Extmark-based Span Mapping Pattern

```lua
local M = {}
local ns_id = nil

function M.create_namespace()
  if not ns_id then
    ns_id = vim.api.nvim_create_namespace('namespace_name')
  end
  return ns_id
end

function M.set_instance_span(bufnr, start_line, end_line, metadata)
  if bufnr == 0 or not bufnr then
    error('Invalid buffer number')
  end

  local ns = M.create_namespace()
  local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns, start_line, 0, {
    end_line = end_line,
    end_col = 0,
    right_gravity = false,
    end_right_gravity = true,
  })

  if not mark_id then
    error('Failed to create extmark')
  end

  if not M._metadata_store then
    M._metadata_store = {}
  end
  if not M._metadata_store[bufnr] then
    M._metadata_store[bufnr] = {}
  end
  M._metadata_store[bufnr][mark_id] = metadata
end

function M.get_instance_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1

  if not M._metadata_store or not M._metadata_store[bufnr] then
    return nil
  end

  local ns = M.create_namespace()
  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {details = true})

  for _, mark in ipairs(extmarks) do
    local mark_id = mark[1]
    local mark_line = mark[2]
    local details = mark[4]

    if details and details.end_row then
      if line >= mark_line and line <= details.end_row then
        return M._metadata_store[bufnr][mark_id]
      end
    end
  end

  return nil
end
```

**Why this pattern:**
- Singleton namespace: All span tracking uses same namespace for simplicity
- Module-local metadata store: ext_data API incomplete/unreliable in Neovim
- Buffer validation: Check bufnr == 0 or not bufnr before using
- Extmark range tracking: Use end_line parameter for multiline spans
- Cursor position lookup: Iterate all extmarks, check if cursor within [start_row, end_row]

## Markdown Parser Pattern

```lua
local M = {}

function M.parse_buffer(bufnr)
  if bufnr == 0 or not bufnr then
    error('Invalid buffer number')
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = {}

  for line_idx, line in ipairs(lines) do
    local block = M._parse_line(line, line_idx - 1)
    if block then
      table.insert(blocks, block)
    end
  end

  return blocks
end

function M._parse_line(line, line_idx)
  local heading_match = line:match('^(#+)%s+(.*)$')
  if heading_match then
    return M._parse_heading(line, line_idx)
  end

  local task_match = line:match('^%s*%-%s+%[([%sxX])%]%s+(.*)$')
  if task_match then
    return M._parse_task(line, line_idx)
  end

  local list_match = line:match('^%s*%-%s+(.*)$')
  if list_match then
    return M._parse_list_item(line, line_idx)
  end

  return nil
end

function M._extract_id(text)
  local before_id, id = text:match('^(.-)%s*%^([%w%-]+)%s*$')
  if before_id and id then
    return vim.trim(before_id), id
  end
  return vim.trim(text), nil
end
```

**Lua Pattern Reference:**
- `^(#+)%s+(.*)$`: Matches headings (1-6 hashes + space + rest)
- `^%s*%-%s+%[([%sxX])%]%s+(.*)$`: Matches tasks (optional indent + dash + checkbox + rest)
- `^%s*%-%s+(.*)$`: Matches list items (optional indent + dash + rest)
- `^(.-)%s*%^([%w%-]+)%s*$`: Extracts ^id suffix at end of line
- `%s*`: Zero or more whitespace
- `(.-)`: Non-greedy capture (shortest match)
- `[%w%-]`: Word characters (alphanumeric + underscore) or hyphen
- `[%sxX]`: Space, lowercase x, or uppercase X

**Block structure:**
```lua
{
  type = 'heading' | 'task' | 'list_item',
  line = number,  -- 0-indexed line number
  level = number, -- heading level (1-6), only for headings
  text = string,  -- text content (^id suffix removed)
  state = 'todo' | 'done', -- only for tasks
  id = string | nil, -- extracted from ^id suffix
}
```
