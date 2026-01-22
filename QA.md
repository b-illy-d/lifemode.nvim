# Manual QA Testing Instructions

This document provides manual testing instructions for each phase of the LifeMode plugin. Use these to verify functionality beyond what automated tests cover.

## Prerequisites

Before testing, ensure you have:
- Neovim installed with Lua support
- plenary.nvim installed (for automated tests)
- The plugin directory in your runtimepath

## Phase 1: Result Type & Utilities

### UUID Generation

**Test 1: Basic UUID generation**
```vim
:lua print(require('lifemode.util').uuid())
```
- Expected: UUID in format `xxxxxxxx-xxxx-4xxx-xxxx-xxxxxxxxxxxx`
- Expected: All hex characters (0-9, a-f) lowercase
- Expected: Version nibble (15th character) is '4'

**Test 2: UUID uniqueness**
```vim
:lua for i=1,5 do print(require('lifemode.util').uuid()) end
```
- Expected: 5 different UUIDs printed
- Expected: All follow same format
- Expected: No duplicates

### Date Parsing

**Test 3: Valid date parsing**
```vim
:lua local result = require('lifemode.util').parse_date('2024-01-21'); print(vim.inspect(result))
```
- Expected: `{ ok = true, value = <timestamp> }`
- Expected: Timestamp is a number

**Test 4: Invalid date format**
```vim
:lua local result = require('lifemode.util').parse_date('01/21/2024'); print(vim.inspect(result))
```
- Expected: `{ ok = false, error = "Invalid date format: expected YYYY-MM-DD" }`

**Test 5: Invalid date values**
```vim
:lua local result = require('lifemode.util').parse_date('2024-13-01'); print(vim.inspect(result))
:lua local result = require('lifemode.util').parse_date('2024-01-32'); print(vim.inspect(result))
```
- Expected: Error messages about invalid month/day

### Result Type

**Test 6: Ok unwrap**
```vim
:lua local ok = require('lifemode.util').Ok(42); print(ok:unwrap())
```
- Expected: `42`

**Test 7: Err unwrap (should error)**
```vim
:lua local err = require('lifemode.util').Err('boom'); print(err:unwrap())
```
- Expected: Error message containing "boom"

**Test 8: unwrap_or with Err**
```vim
:lua local err = require('lifemode.util').Err('boom'); print(err:unwrap_or(999))
```
- Expected: `999`

## Phase 2: Configuration Schema

### Setup

Create a test vault directory:
```bash
mkdir -p /tmp/test_vault
```

### Config Validation

**Test 9: Valid configuration**
```vim
:lua require('lifemode').setup({vault_path = '/tmp/test_vault'})
```
- Expected: No errors
- Expected: Plugin initializes successfully

**Test 10: Config retrieval**
```vim
:lua print(require('lifemode.config').get('vault_path'))
```
- Expected: `/tmp/test_vault`

**Test 11: Nested config retrieval**
```vim
:lua print(require('lifemode.config').get('sidebar.width_percent'))
```
- Expected: `30` (default value)

**Test 12: Invalid vault path**

Start fresh Neovim session:
```vim
:lua require('lifemode').setup({vault_path = '/nonexistent/directory'})
```
- Expected: Error message with "[LifeMode]" prefix
- Expected: Error mentions directory does not exist

**Test 13: Tilde expansion**

Start fresh Neovim session and create `~/test_vault`:
```bash
mkdir -p ~/test_vault
```
```vim
:lua require('lifemode').setup({vault_path = '~/test_vault'})
:lua print(require('lifemode.config').get('vault_path'))
```
- Expected: Full path with $HOME expanded (e.g., `/home/user/test_vault`)

**Test 14: Config pre-initialization error**

Start fresh Neovim session:
```vim
:lua print(require('lifemode.config').get('vault_path'))
```
- Expected: Error "Config not initialized. Call validate_config() first."

## Phase 3: Plugin Entry Point

### Setup Guard

**Test 15: Double setup detection**

Start fresh Neovim session:
```vim
:lua require('lifemode').setup({vault_path = '/tmp/test_vault'})
:lua require('lifemode').setup({vault_path = '/tmp/test_vault'})
```
- Expected: Second call errors with "already initialized"
- Expected: Error mentions calling setup() only once

### Autocommand Group

**Test 16: Autocommand group creation**
```vim
:lua require('lifemode').setup({vault_path = '/tmp/test_vault'})
:augroup LifeMode
```
- Expected: Shows "LifeMode" autocommand group exists
- Expected: No errors

**Test 17: Config propagation**

Start fresh Neovim session:
```vim
:lua require('lifemode').setup({vault_path = '/tmp/test_vault', sidebar = {width_percent = 50}})
:lua print(require('lifemode.config').get('sidebar.width_percent'))
```
- Expected: `50`

## Phase 4: Node Value Object

### Node Creation

**Test 18: Valid node creation**
```vim
:lua local types = require('lifemode.domain.types')
:lua local util = require('lifemode.util')
:lua local meta = {id = util.uuid(), created = os.time()}
:lua local result = types.Node_new('test content', meta)
:lua print(vim.inspect(result))
```
- Expected: `{ ok = true, value = { id = "...", content = "test content", meta = {...}, bounds = nil } }`
- Expected: `meta.modified` equals `meta.created`

**Test 19: Invalid UUID rejection**
```vim
:lua local types = require('lifemode.domain.types')
:lua local result = types.Node_new('test', {id = 'invalid-uuid', created = os.time()})
:lua print(vim.inspect(result))
```
- Expected: `{ ok = false, error = "Node meta.id must be a valid UUID v4" }`

**Test 20: UUID v1/v3/v5 rejection**
```vim
:lua local types = require('lifemode.domain.types')
:lua local result = types.Node_new('test', {id = '12345678-1234-1abc-9def-123456789abc', created = os.time()})
:lua print(vim.inspect(result))
```
- Expected: Error about "valid UUID v4"
- Repeat with version nibble 3 and 5

**Test 21: Missing required fields**
```vim
:lua local types = require('lifemode.domain.types')
:lua local result = types.Node_new('test', {id = require('lifemode.util').uuid()})
:lua print(vim.inspect(result))
```
- Expected: Error about "meta.created is required"

**Test 22: Immutability check**
```vim
:lua local types = require('lifemode.domain.types')
:lua local util = require('lifemode.util')
:lua local meta = {id = util.uuid(), created = os.time(), custom = 'original'}
:lua local result = types.Node_new('test', meta)
:lua meta.custom = 'modified'
:lua print(result.value.meta.custom)
```
- Expected: `original` (not modified)

### Deep Copy

**Test 23: Deep copy functionality**
```vim
:lua local types = require('lifemode.domain.types')
:lua local original = {a = {b = {c = 1}}}
:lua local copy = types.deep_copy(original)
:lua copy.a.b.c = 999
:lua print(original.a.b.c)
```
- Expected: `1` (original unchanged)

## Running Automated Tests

### Unit Tests
```bash
nvim --headless -c "PlenaryBustedDirectory lua/lifemode/" -c "qa!"
```

### Integration Tests
```bash
nvim --headless -c "PlenaryBustedDirectory tests/" -c "qa!"
```

### All Tests
```bash
nvim --headless -c "PlenaryBustedDirectory lua/lifemode/" -c "qa!" && \
nvim --headless -c "PlenaryBustedDirectory tests/" -c "qa!"
```

### Single File
```bash
nvim --headless -c "PlenaryBustedFile lua/lifemode/util_spec.lua" -c "qa!"
```

### From Within Neovim
Open a test file and run:
```vim
:PlenaryBustedFile %
```

Or run a directory:
```vim
:PlenaryBustedDirectory lua/lifemode/
:PlenaryBustedDirectory tests/
```

## Common Issues

### Test Failures

**Issue**: Config tests fail with "already initialized"
- **Solution**: Ensure `package.loaded` is properly reset in `before_each()`

**Issue**: Directory not found errors in tests
- **Solution**: Check that temp directories are created in `before_each()`

**Issue**: UUID validation tests fail
- **Solution**: Verify the version nibble (15th character) is '4' in the pattern

### Manual Testing

**Issue**: "module not found" errors
- **Solution**: Add plugin directory to runtimepath: `:set rtp+=/path/to/lifemode.nvim`

**Issue**: Config persists between manual tests
- **Solution**: Restart Neovim or manually reset: `:lua package.loaded["lifemode.init"] = nil; package.loaded["lifemode.config"] = nil`

## Success Criteria

All phases pass manual QA when:
- ✓ All automated tests pass (green output)
- ✓ Manual tests produce expected results
- ✓ Error messages are clear and helpful
- ✓ No state leaks between test runs
- ✓ Edge cases behave as documented
