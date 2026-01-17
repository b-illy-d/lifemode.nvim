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
- lua/lifemode/vault.lua: Vault file discovery
- lua/lifemode/index.lua: Index system for fast lookups
- lua/lifemode/lens.lua: Lens renderers for view display
- plugin/lifemode.vim: Autoload guard
- tests/: **ALL test files go here - NEVER at root level**
- Makefile: Test runner automation

## CRITICAL: Test File Location
**ALL test files MUST be placed in the `tests/` directory.**
- Correct: `tests/test_foo.lua`
- WRONG: `test_foo.lua` (root level)
Never create test files at the project root. This is a hard requirement.

## Testing Patterns
- Manual tests via nvim --headless for T00
- Test structure: Test validation, config, and commands
- Future: Will add plenary.nvim integration tests
- **Edge case testing required**: Happy path tests miss silent failures
- **Test both success and failure paths**: Type errors, edge cases, invalid input
- **CRITICAL: Run tests with `nvim --headless -c "set runtimepath+=." -c "luafile test.lua"`**

## Common Gotchas
- Commands must be created after setup() is called
- Config validation must check for empty string, not just nil
- Buffer options set via nvim_buf_set_option, not direct vim.bo
- **CRITICAL: vim.tbl_deep_extend does NOT validate types - manual validation required**
- **CRITICAL: Check for whitespace-only strings, not just empty strings**
- **CRITICAL: nvim_create_user_command allows duplicate registration without error**
- **nvim_buf_set_option deprecated in 0.10+, use vim.bo[bufnr].option instead**
- **CRITICAL: Autocmds can be registered multiple times - track IDs and delete before re-registering**
- **CRITICAL: Path prefix matching needs trailing slash - /vault matches /vault2 without it**
- **CRITICAL: Use vim.startswith() for path prefix checks, not string.find()**

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

## Autocmd Management Pattern (REQUIRED)
```lua
local _autocmd_id = nil

function M.setup_autocommands(vault_root)
  if _autocmd_id then
    vim.api.nvim_del_autocmd(_autocmd_id)
    _autocmd_id = nil
  end

  local normalized_vault = vim.fn.simplify(vault_root)
  if not vim.endswith(normalized_vault, '/') then
    normalized_vault = normalized_vault .. '/'
  end

  _autocmd_id = vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = '*.md',
    callback = function(args)
      local file_path = vim.fn.simplify(args.file)
      if not vim.startswith(file_path, normalized_vault) then
        return
      end
      -- Handle file
    end,
  })
end

function M._reset_state()
  if _autocmd_id then
    pcall(vim.api.nvim_del_autocmd, _autocmd_id)
    _autocmd_id = nil
  end
end
```

**Why this pattern:**
- Track autocmd ID in module-local variable
- Delete existing autocmd before creating new one (prevents duplicates)
- Add trailing slash to vault path for prefix matching (prevents /vault matching /vault2)
- Use vim.startswith() instead of string.find() for path prefix check
- Provide _reset_state() for test cleanup

## Config Validation Pattern (REQUIRED)
```lua
function M.setup(opts)
  opts = opts or {}

  if state.initialized then
    error('setup() already called - duplicate setup not allowed')
  end

  if not opts.vault_root or opts.vault_root == '' then
    error('vault_root is required')
  end

  if type(opts.vault_root) ~= 'string' then
    error('vault_root must be a string')
  end

  if vim.trim(opts.vault_root) == '' then
    error('vault_root cannot be whitespace only')
  end

  state.config = vim.tbl_deep_extend('force', default_config, opts)

  if type(state.config.max_depth) ~= 'number' or state.config.max_depth <= 0 then
    error('max_depth must be a positive number')
  end

  if type(state.config.auto_index_on_startup) ~= 'boolean' then
    error('auto_index_on_startup must be a boolean')
  end

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
7. **Duplicate autocmds**: Not tracking and deleting before re-registering
8. **Path prefix false positives**: Using string.find() instead of vim.startswith() with trailing slash

## Buffer Creation Validation Pattern (REQUIRED)
```lua
function M.create_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)

  if bufnr == 0 or not bufnr then
    error('Failed to create buffer')
  end

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
local original_api = vim.api.nvim_create_buf
vim.api.nvim_create_buf = function()
  return 0
end

local success, result = pcall(my_function)

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
  line = number,
  level = number,
  text = string,
  state = 'todo' | 'done',
  id = string | nil,
}
```

## Index System Pattern

```lua
local M = {}
local vault = require('lifemode.vault')
local parser = require('lifemode.parser')

local _index = nil
local _vault_root = nil
local _autocmd_id = nil

function M.create()
  return {
    node_locations = {},
    tasks_by_state = { todo = {}, done = {} },
    nodes_by_date = {},
  }
end

function M.add_node(idx, node, file_path, mtime)
  if node.id then
    idx.node_locations[node.id] = {
      file = file_path,
      line = node.line,
      mtime = mtime,
    }
  end

  if node.type == 'task' then
    local state = node.state or 'todo'
    local task_entry = vim.tbl_extend('force', node, { _file = file_path })
    table.insert(idx.tasks_by_state[state], task_entry)
  end

  local date_str = os.date('%Y-%m-%d', mtime)
  if not idx.nodes_by_date[date_str] then
    idx.nodes_by_date[date_str] = {}
  end

  if node.id then
    table.insert(idx.nodes_by_date[date_str], { id = node.id, file = file_path })
  else
    table.insert(idx.nodes_by_date[date_str], { node = node, file = file_path })
  end

  return idx
end

function M.setup_autocommands(vault_root)
  if _autocmd_id then
    vim.api.nvim_del_autocmd(_autocmd_id)
    _autocmd_id = nil
  end

  local normalized_vault = vim.fn.simplify(vault_root)
  if not vim.endswith(normalized_vault, '/') then
    normalized_vault = normalized_vault .. '/'
  end

  _autocmd_id = vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = '*.md',
    callback = function(args)
      local file_path = vim.fn.simplify(args.file)
      if not vim.startswith(file_path, normalized_vault) then
        return
      end

      local stat = vim.loop.fs_stat(file_path)
      if stat and stat.type == 'file' then
        M.update_file(file_path, stat.mtime.sec)
      end
    end,
  })
end

function M._reset_state()
  _index = nil
  _vault_root = nil
  if _autocmd_id then
    pcall(vim.api.nvim_del_autocmd, _autocmd_id)
    _autocmd_id = nil
  end
end
```

**Why this pattern:**
- Module-level state (_index, _vault_root, _autocmd_id) for lazy initialization
- Track autocmd ID and delete before re-registering (prevents duplicates)
- Add trailing slash to vault path for prefix matching (prevents /vault matching /vault2)
- Use vim.startswith() for path prefix check (not string.find())
- node_locations: Maps node IDs to file locations (file, line, mtime)
- tasks_by_state: Stores tasks with _file field for incremental updates
- nodes_by_date: Stores {id, file} or {node, file} for date-based views
- vim.fn.simplify() for path normalization (handles // vs / properly)
- Incremental update removes all entries from file, then re-parses
- BufWritePost autocmd triggers index updates on file save

**Index structure:**
```lua
{
  node_locations = {
    ['node-id'] = { file = '/path/file.md', line = 5, mtime = 1705363200 }
  },
  tasks_by_state = {
    todo = { { type = 'task', id = 'task-1', _file = '/path/file.md', ... } },
    done = { { type = 'task', id = 'task-2', _file = '/path/file.md', ... } }
  },
  nodes_by_date = {
    ['2026-01-16'] = {
      { id = 'node-id', file = '/path/file.md' },
      { node = { ... }, file = '/path/file.md' }
    }
  }
}
```

## Lens Renderer Pattern

```lua
local M = {}

function M.render(node, lens_name, params)
  if not node then
    error('node is required')
  end
  if not lens_name then
    error('lens_name is required')
  end

  if lens_name == 'task/brief' then
    return M._render_task_brief(node)
  elseif lens_name == 'node/raw' then
    return M._render_node_raw(node)
  else
    error('Unknown lens: ' .. lens_name)
  end
end

function M._render_task_brief(node)
  local state_icon = node.state == 'done' and '[x]' or '[ ]'
  local parts = {state_icon, node.text}

  if node.priority then
    table.insert(parts, '!' .. node.priority)
  end

  if node.due then
    table.insert(parts, '@due(' .. node.due .. ')')
  end

  local line = table.concat(parts, ' ')
  local highlights = {}

  if node.state == 'done' then
    table.insert(highlights, {
      line = 0,
      col_start = 0,
      col_end = #line,
      hl_group = 'LifeModeDone',
    })
  else
    if node.priority and (node.priority == 1 or node.priority == 2) then
      local priority_text = '!' .. node.priority
      local priority_start = line:find(priority_text, 1, true)
      if priority_start then
        table.insert(highlights, {
          line = 0,
          col_start = priority_start - 1,
          col_end = priority_start + #priority_text - 1,
          hl_group = 'LifeModePriorityHigh',
        })
      end
    end
  end

  return {
    lines = {line},
    highlights = highlights,
  }
end

function M.get_available_lenses(node_type)
  if node_type == 'task' then
    return {'task/brief', 'node/raw'}
  elseif node_type == 'heading' then
    return {'heading/brief', 'node/raw'}
  else
    return {'node/raw'}
  end
end
```

**Why this pattern:**
- Module pattern (M = {}, return M) for consistency
- Dispatcher function (render) routes to specific lens renderers
- Each lens returns {lines, highlights} structure
- Highlights use 0-based column indices (Neovim API convention)
- string.find() with plain=true (3rd arg) for exact text search
- Done state overrides all other highlights (simplifies visual hierarchy)
- Priority highlighting only for extremes (!1-!2 high, !4-!5 low)
- get_available_lenses() for lens discovery by node type

**Render output structure:**
```lua
{
  lines = { "[ ] Task text !2 @due(2026-01-20)" },
  highlights = {
    { line = 0, col_start = 12, col_end = 14, hl_group = "LifeModePriorityHigh" },
    { line = 0, col_start = 15, col_end = 32, hl_group = "LifeModeDue" }
  }
}
```

**Highlight groups used:**
- LifeModeDone: Entire line for completed tasks
- LifeModePriorityHigh: !1 and !2 priorities
- LifeModePriorityLow: !4 and !5 priorities
- LifeModeDue: @due(...) date markers
- LifeModeHeading: Heading lines
