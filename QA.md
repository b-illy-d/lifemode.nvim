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

## Phase 5: Node Operations (Create)

### Node Creation

**Test 24: Create node with minimal arguments**
```vim
:lua local node = require('lifemode.domain.node')
:lua local result = node.create('My first thought')
:lua print(vim.inspect(result))
```
- Expected: `{ ok = true, value = { id = "...", content = "My first thought", meta = {...} } }`
- Expected: UUID is auto-generated (valid v4)
- Expected: `meta.created` and `meta.modified` are timestamps (numbers)
- Expected: `meta.created` equals `meta.modified`

**Test 25: Create node with custom metadata**
```vim
:lua local node = require('lifemode.domain.node')
:lua local meta = {type = 'task', status = 'todo', tags = {'work', 'urgent'}}
:lua local result = node.create('Complete documentation', meta)
:lua print(vim.inspect(result.value.meta))
```
- Expected: `meta.type = 'task'`
- Expected: `meta.status = 'todo'`
- Expected: `meta.tags` is preserved
- Expected: `id`, `created`, `modified` are auto-generated

**Test 26: Create node with provided UUID and timestamp**
```vim
:lua local node = require('lifemode.domain.node')
:lua local meta = {id = require('lifemode.util').uuid(), created = 1234567890}
:lua local result = node.create('test', meta)
:lua print(result.value.id, result.value.meta.created)
```
- Expected: Uses provided UUID and timestamp
- Expected: `modified` defaults to `created` (1234567890)

**Test 27: Error on invalid content**
```vim
:lua local node = require('lifemode.domain.node')
:lua local result = node.create(123)
:lua print(vim.inspect(result))
```
- Expected: `{ ok = false, error = "content must be a string" }`

**Test 28: Error on invalid meta type**
```vim
:lua local node = require('lifemode.domain.node')
:lua local result = node.create('test', 'not a table')
:lua print(vim.inspect(result))
```
- Expected: `{ ok = false, error = "meta must be a table" }`

### Node Validation

**Test 29: Validate valid node**
```vim
:lua local node = require('lifemode.domain.node')
:lua local created = node.create('test content')
:lua local validation = node.validate(created.value)
:lua print(vim.inspect(validation))
```
- Expected: `{ ok = true, value = <node> }`

**Test 30: Validate invalid node structure**
```vim
:lua local node = require('lifemode.domain.node')
:lua local invalid = {id = 'not-a-uuid', content = 'test', meta = {id = 'not-a-uuid', created = 'not-a-timestamp'}}
:lua local validation = node.validate(invalid)
:lua print(vim.inspect(validation))
```
- Expected: `{ ok = false, error = "node.id must be a valid UUID v4" }`

**Test 31: Validate missing required fields**
```vim
:lua local node = require('lifemode.domain.node')
:lua local incomplete = {content = 'test', meta = {created = os.time()}}
:lua local validation = node.validate(incomplete)
:lua print(vim.inspect(validation))
```
- Expected: Error about missing `node.id`

### Markdown Serialization

**Test 32: Serialize basic node to markdown**
```vim
:lua local node = require('lifemode.domain.node')
:lua local result = node.create('This is my content')
:lua local markdown = node.to_markdown(result.value)
:lua print(markdown)
```
- Expected: Starts with `---`
- Expected: Contains `id: <uuid>` in frontmatter
- Expected: Contains `created: <timestamp>` in frontmatter
- Expected: Contains `modified: <timestamp>` in frontmatter
- Expected: Ends with `---` followed by newline and "This is my content"

**Test 33: Serialize node with custom metadata**
```vim
:lua local node = require('lifemode.domain.node')
:lua local meta = {type = 'task', status = 'in_progress'}
:lua local result = node.create('Complete Phase 5', meta)
:lua local markdown = node.to_markdown(result.value)
:lua print(markdown)
```
- Expected: Frontmatter includes `type: task`
- Expected: Frontmatter includes `status: in_progress`
- Expected: Content is "Complete Phase 5"

**Test 34: Serialize multiline content**
```vim
:lua local node = require('lifemode.domain.node')
:lua local content = '# Heading\n\nParagraph with **bold** and *italic*.'
:lua local result = node.create(content)
:lua local markdown = node.to_markdown(result.value)
:lua print(markdown)
```
- Expected: Multiline content preserved exactly
- Expected: Markdown formatting not escaped

**Test 35: Serialize empty content**
```vim
:lua local node = require('lifemode.domain.node')
:lua local result = node.create('')
:lua local markdown = node.to_markdown(result.value)
:lua print(markdown)
```
- Expected: Frontmatter present
- Expected: Ends with `---\n` (no content after)

**Test 36: Serialize nested metadata**
```vim
:lua local node = require('lifemode.domain.node')
:lua local meta = {tags = {'tag1', 'tag2'}, settings = {color = 'blue', priority = 5}}
:lua local result = node.create('test', meta)
:lua local markdown = node.to_markdown(result.value)
:lua print(markdown)
```
- Expected: Nested tables rendered as YAML
- Expected: Proper indentation for nested fields

### Workflow Integration

**Test 37: Create, serialize, and inspect**
```vim
:lua local node = require('lifemode.domain.node')
:lua local r1 = node.create('First node', {type = 'note'})
:lua local r2 = node.create('Second node', {type = 'task'})
:lua print(node.to_markdown(r1.value))
:lua print('\n---\n')
:lua print(node.to_markdown(r2.value))
```
- Expected: Two distinct markdown outputs
- Expected: Different UUIDs for each node
- Expected: Correct types in each frontmatter

**Test 38: UUID uniqueness across multiple creations**
```vim
:lua local node = require('lifemode.domain.node')
:lua local uuids = {}
:lua for i=1,10 do
:lua   local r = node.create('node ' .. i)
:lua   table.insert(uuids, r.value.id)
:lua end
:lua local unique = {}
:lua for _, u in ipairs(uuids) do unique[u] = true end
:lua print('Created: ' .. #uuids .. ', Unique: ' .. vim.tbl_count(unique))
```
- Expected: Created: 10, Unique: 10

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
