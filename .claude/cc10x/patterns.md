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
- lua/lifemode/init.lua: Main plugin module
- plugin/lifemode.vim: Autoload guard
- tests/: Test files (manual tests for now)
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
- Buffer options: buftype=nofile, swapfile=false, bufhidden=wipe
- Command registration: nvim_create_user_command with callback
- Window buffer switch: nvim_win_set_buf(0, bufnr)
- **Buffer API can fail - check return values or use pcall**

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
