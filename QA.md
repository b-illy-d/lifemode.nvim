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

## Phase 6: Node Parsing

### Basic Parsing

**Test 39: Parse markdown with frontmatter**
```vim
:lua local node = require('lifemode.domain.node')
:lua local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
created: 1234567890
modified: 1234567890
type: note
---
Test content]]
:lua local result = node.parse(markdown)
:lua print(vim.inspect(result))
```
- Expected: `{ ok = true, value = { id = "...", content = "Test content", meta = {...} } }`
- Expected: All meta fields correctly parsed

**Test 40: Parse with additional metadata**
```vim
:lua local node = require('lifemode.domain.node')
:lua local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
created: 1234567890
type: task
status: in_progress
priority: 5
archived: false
---
Task description here]]
:lua local result = node.parse(markdown)
:lua print('Type:', result.value.meta.type)
:lua print('Status:', result.value.meta.status)
:lua print('Priority:', result.value.meta.priority)
:lua print('Archived:', result.value.meta.archived)
```
- Expected: `Type: task`
- Expected: `Status: in_progress`
- Expected: `Priority: 5` (number)
- Expected: `Archived: false` (boolean)

**Test 41: Parse multiline content**
```vim
:lua local node = require('lifemode.domain.node')
:lua local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
created: 1234567890
---
# Heading

Paragraph 1

Paragraph 2]]
:lua local result = node.parse(markdown)
:lua print(result.value.content)
```
- Expected: Multiline content preserved with newlines

**Test 42: Parse empty content**
```vim
:lua local node = require('lifemode.domain.node')
:lua local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
created: 1234567890
---
]]
:lua local result = node.parse(markdown)
:lua print('Content length:', #result.value.content)
```
- Expected: `Content length: 0`

### Round-Trip Testing

**Test 43: Create, serialize, parse cycle**
```vim
:lua local node = require('lifemode.domain.node')
:lua local original = node.create('Original content', {type = 'note', tags = {'a', 'b'}})
:lua local markdown = node.to_markdown(original.value)
:lua local parsed = node.parse(markdown)
:lua print('Original ID:', original.value.id)
:lua print('Parsed ID:', parsed.value.id)
:lua print('Content match:', original.value.content == parsed.value.content)
```
- Expected: IDs match
- Expected: `Content match: true`
- Expected: Metadata preserved

**Test 44: Multiple round-trips**
```vim
:lua local node = require('lifemode.domain.node')
:lua local r1 = node.create('Test')
:lua local md1 = node.to_markdown(r1.value)
:lua local r2 = node.parse(md1)
:lua local md2 = node.to_markdown(r2.value)
:lua local r3 = node.parse(md2)
:lua print('Pass 1 ID:', r1.value.id)
:lua print('Pass 3 ID:', r3.value.id)
:lua print('IDs match:', r1.value.id == r3.value.id)
```
- Expected: `IDs match: true`
- Expected: Content stable across multiple round-trips

### Error Handling

**Test 45: Missing frontmatter**
```vim
:lua local node = require('lifemode.domain.node')
:lua local result = node.parse('Just plain text without frontmatter')
:lua print(vim.inspect(result))
```
- Expected: `{ ok = false, error = "Missing frontmatter: expected '---' at start" }`

**Test 46: Missing closing delimiter**
```vim
:lua local node = require('lifemode.domain.node')
:lua local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
created: 1234567890
This has no closing delimiter]]
:lua local result = node.parse(markdown)
:lua print(vim.inspect(result))
```
- Expected: `{ ok = false, error = "Missing frontmatter closing delimiter: expected '---'" }`

**Test 47: Missing required field (id)**
```vim
:lua local node = require('lifemode.domain.node')
:lua local markdown = [[---
created: 1234567890
type: note
---
content]]
:lua local result = node.parse(markdown)
:lua print(vim.inspect(result))
```
- Expected: `{ ok = false, error = "Missing required field: id" }`

**Test 48: Missing required field (created)**
```vim
:lua local node = require('lifemode.domain.node')
:lua local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
type: note
---
content]]
:lua local result = node.parse(markdown)
:lua print(vim.inspect(result))
```
- Expected: `{ ok = false, error = "Missing required field: created" }`

**Test 49: Invalid UUID format**
```vim
:lua local node = require('lifemode.domain.node')
:lua local markdown = [[---
id: not-a-valid-uuid-format
created: 1234567890
---
content]]
:lua local result = node.parse(markdown)
:lua print(vim.inspect(result))
```
- Expected: Error mentioning "valid UUID v4"

**Test 50: Non-string input**
```vim
:lua local node = require('lifemode.domain.node')
:lua local result = node.parse(12345)
:lua print(vim.inspect(result))
```
- Expected: `{ ok = false, error = "text must be a string" }`

### Data Type Handling

**Test 51: Parse different value types**
```vim
:lua local node = require('lifemode.domain.node')
:lua local markdown = [[---
id: 12345678-1234-4abc-9def-123456789abc
created: 1234567890
string_val: hello world
int_val: 42
float_val: 3.14
bool_true: true
bool_false: false
---
content]]
:lua local result = node.parse(markdown)
:lua print('String:', result.value.meta.string_val, type(result.value.meta.string_val))
:lua print('Int:', result.value.meta.int_val, type(result.value.meta.int_val))
:lua print('Float:', result.value.meta.float_val, type(result.value.meta.float_val))
:lua print('Bool true:', result.value.meta.bool_true, type(result.value.meta.bool_true))
:lua print('Bool false:', result.value.meta.bool_false, type(result.value.meta.bool_false))
```
- Expected: Correct types for each value
- Expected: Numbers as numbers, booleans as booleans, strings as strings


## Phase 7: Filesystem Write

### File Existence Check

**Test 52: Check non-existent file**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua print(write.exists('/tmp/nonexistent_file.txt'))
```
- Expected: `false`

**Test 53: Check existing file**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua vim.fn.system('touch /tmp/test_exists.txt')
:lua print(write.exists('/tmp/test_exists.txt'))
:lua vim.fn.system('rm /tmp/test_exists.txt')
```
- Expected: `true`

### Directory Creation

**Test 54: Create single directory**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua local result = write.mkdir('/tmp/lifemode_test_dir')
:lua print(vim.inspect(result))
:lua print('Exists:', write.exists('/tmp/lifemode_test_dir'))
:lua vim.fn.system('rm -rf /tmp/lifemode_test_dir')
```
- Expected: `{ ok = true, value = <userdata> }`
- Expected: `Exists: true`

**Test 55: Create nested directories**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua local result = write.mkdir('/tmp/lifemode_test/a/b/c')
:lua print('OK:', result.ok)
:lua print('Exists:', write.exists('/tmp/lifemode_test/a/b/c'))
:lua vim.fn.system('rm -rf /tmp/lifemode_test')
```
- Expected: `OK: true`
- Expected: `Exists: true`

**Test 56: Idempotent directory creation**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua local r1 = write.mkdir('/tmp/lifemode_idempotent')
:lua local r2 = write.mkdir('/tmp/lifemode_idempotent')
:lua print('First:', r1.ok, 'Second:', r2.ok)
:lua vim.fn.system('rm -rf /tmp/lifemode_idempotent')
```
- Expected: `First: true Second: true`

### File Writing

**Test 57: Write to new file**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua local result = write.write('/tmp/lifemode_new.txt', 'Hello World')
:lua print('OK:', result.ok)
:lua vim.fn.system('cat /tmp/lifemode_new.txt')
:lua vim.fn.system('rm /tmp/lifemode_new.txt')
```
- Expected: `OK: true`
- Expected: File contains "Hello World"

**Test 58: Write with parent directory creation**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua local result = write.write('/tmp/lifemode_nested/deep/file.txt', 'content')
:lua print('OK:', result.ok)
:lua print('File exists:', write.exists('/tmp/lifemode_nested/deep/file.txt'))
:lua vim.fn.system('rm -rf /tmp/lifemode_nested')
```
- Expected: `OK: true`
- Expected: `File exists: true`

**Test 59: Overwrite existing file**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua write.write('/tmp/lifemode_overwrite.txt', 'original')
:lua write.write('/tmp/lifemode_overwrite.txt', 'updated')
:lua vim.fn.system('cat /tmp/lifemode_overwrite.txt')
:lua vim.fn.system('rm /tmp/lifemode_overwrite.txt')
```
- Expected: File contains "updated" (not "original")

**Test 60: Write multiline content**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua local content = 'Line 1\nLine 2\nLine 3'
:lua write.write('/tmp/lifemode_multiline.txt', content)
:lua print(vim.fn.system('cat /tmp/lifemode_multiline.txt'))
:lua vim.fn.system('rm /tmp/lifemode_multiline.txt')
```
- Expected: Three lines displayed

### Integration with Node Module

**Test 61: Write node to filesystem**
```vim
:lua local node = require('lifemode.domain.node')
:lua local write = require('lifemode.infra.fs.write')
:lua local n = node.create('My first persisted node', {type = 'note'})
:lua local md = node.to_markdown(n.value)
:lua local result = write.write('/tmp/lifemode_node.md', md)
:lua print('Write OK:', result.ok)
:lua print(vim.fn.system('cat /tmp/lifemode_node.md'))
:lua vim.fn.system('rm /tmp/lifemode_node.md')
```
- Expected: `Write OK: true`
- Expected: Markdown with frontmatter and content displayed

**Test 62: Simulate vault structure**
```vim
:lua local node = require('lifemode.domain.node')
:lua local write = require('lifemode.infra.fs.write')
:lua local n = node.create('Daily note')
:lua local md = node.to_markdown(n.value)
:lua local path = '/tmp/vault/2026/01-Jan/21/' .. n.value.id .. '.md'
:lua local result = write.write(path, md)
:lua print('OK:', result.ok)
:lua print('Exists:', write.exists(path))
:lua vim.fn.system('rm -rf /tmp/vault')
```
- Expected: `OK: true`
- Expected: `Exists: true`

### Error Handling

**Test 63: Invalid path (empty string)**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua local result = write.write('', 'content')
:lua print(vim.inspect(result))
```
- Expected: `{ ok = false, error = "write: path must be a non-empty string" }`

**Test 64: Invalid content type**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua local result = write.write('/tmp/test.txt', 123)
:lua print(vim.inspect(result))
```
- Expected: `{ ok = false, error = "write: content must be a string" }`


## Phase 8: Filesystem Read

### Basic File Reading

**Test 65: Read existing file**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua local read = require('lifemode.infra.fs.read')
:lua write.write('/tmp/test_read.txt', 'Hello from LifeMode')
:lua local result = read.read('/tmp/test_read.txt')
:lua print(vim.inspect(result))
:lua vim.fn.system('rm /tmp/test_read.txt')
```
- Expected: `{ ok = true, value = "Hello from LifeMode" }`

**Test 66: Read multiline file**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua local read = require('lifemode.infra.fs.read')
:lua local content = 'Line 1\nLine 2\nLine 3'
:lua write.write('/tmp/multiline.txt', content)
:lua local result = read.read('/tmp/multiline.txt')
:lua print('Content:', result.value)
:lua vim.fn.system('rm /tmp/multiline.txt')
```
- Expected: Three lines displayed

**Test 67: Read empty file**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua local read = require('lifemode.infra.fs.read')
:lua write.write('/tmp/empty.txt', '')
:lua local result = read.read('/tmp/empty.txt')
:lua print('OK:', result.ok)
:lua print('Length:', #result.value)
:lua vim.fn.system('rm /tmp/empty.txt')
```
- Expected: `OK: true`
- Expected: `Length: 0`

**Test 68: Read non-existent file**
```vim
:lua local read = require('lifemode.infra.fs.read')
:lua local result = read.read('/tmp/does_not_exist.txt')
:lua print(vim.inspect(result))
```
- Expected: `{ ok = false, error = "read: file not found: /tmp/does_not_exist.txt" }`

### Modification Time

**Test 69: Get mtime of file**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua local read = require('lifemode.infra.fs.read')
:lua write.write('/tmp/mtime_test.txt', 'content')
:lua local result = read.mtime('/tmp/mtime_test.txt')
:lua print('OK:', result.ok)
:lua print('Timestamp:', result.value)
:lua print('Type:', type(result.value))
:lua vim.fn.system('rm /tmp/mtime_test.txt')
```
- Expected: `OK: true`
- Expected: Timestamp is a number
- Expected: `Type: number`

**Test 70: Detect file modification**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua local read = require('lifemode.infra.fs.read')
:lua write.write('/tmp/modify.txt', 'v1')
:lua local mtime1 = read.mtime('/tmp/modify.txt')
:lua vim.fn.system('sleep 2')
:lua write.write('/tmp/modify.txt', 'v2')
:lua local mtime2 = read.mtime('/tmp/modify.txt')
:lua print('First:', mtime1.value)
:lua print('Second:', mtime2.value)
:lua print('Modified:', mtime2.value > mtime1.value)
:lua vim.fn.system('rm /tmp/modify.txt')
```
- Expected: `Modified: true`
- Expected: Second timestamp greater than first

**Test 71: Mtime for non-existent file**
```vim
:lua local read = require('lifemode.infra.fs.read')
:lua local result = read.mtime('/tmp/missing.txt')
:lua print(vim.inspect(result))
```
- Expected: `{ ok = false, error = "mtime: file not found: /tmp/missing.txt" }`

### Write/Read Round-Trip

**Test 72: Write and read back**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua local read = require('lifemode.infra.fs.read')
:lua local original = 'Test content for round-trip'
:lua write.write('/tmp/roundtrip.txt', original)
:lua local result = read.read('/tmp/roundtrip.txt')
:lua print('Match:', result.value == original)
:lua vim.fn.system('rm /tmp/roundtrip.txt')
```
- Expected: `Match: true`

**Test 73: Special characters preserved**
```vim
:lua local write = require('lifemode.infra.fs.write')
:lua local read = require('lifemode.infra.fs.read')
:lua local special = 'Characters: @#$%^&*()[]{}|\\:;"\'<>?,./`~'
:lua write.write('/tmp/special.txt', special)
:lua local result = read.read('/tmp/special.txt')
:lua print('Match:', result.value == special)
:lua vim.fn.system('rm /tmp/special.txt')
```
- Expected: `Match: true`

### Node Persistence Integration

**Test 74: Write node, read back, parse**
```vim
:lua local node = require('lifemode.domain.node')
:lua local write = require('lifemode.infra.fs.write')
:lua local read = require('lifemode.infra.fs.read')
:lua local original = node.create('Integration test node', {type = 'test'})
:lua local markdown = node.to_markdown(original.value)
:lua write.write('/tmp/node_persist.md', markdown)
:lua local read_result = read.read('/tmp/node_persist.md')
:lua local parsed = node.parse(read_result.value)
:lua print('Parse OK:', parsed.ok)
:lua print('Content match:', original.value.content == parsed.value.content)
:lua print('ID match:', original.value.id == parsed.value.id)
:lua vim.fn.system('rm /tmp/node_persist.md')
```
- Expected: `Parse OK: true`
- Expected: `Content match: true`
- Expected: `ID match: true`

**Test 75: Multiple nodes in vault structure**
```vim
:lua local node = require('lifemode.domain.node')
:lua local write = require('lifemode.infra.fs.write')
:lua local read = require('lifemode.infra.fs.read')
:lua local n1 = node.create('First note')
:lua local n2 = node.create('Second note')
:lua local dir = '/tmp/vault/2026/01-Jan/22/'
:lua write.write(dir .. 'note1.md', node.to_markdown(n1.value))
:lua write.write(dir .. 'note2.md', node.to_markdown(n2.value))
:lua local r1 = read.read(dir .. 'note1.md')
:lua local r2 = read.read(dir .. 'note2.md')
:lua print('Read 1 OK:', r1.ok)
:lua print('Read 2 OK:', r2.ok)
:lua vim.fn.system('rm -rf /tmp/vault')
```
- Expected: `Read 1 OK: true`
- Expected: `Read 2 OK: true`

### Error Handling

**Test 76: Invalid path (empty string)**
```vim
:lua local read = require('lifemode.infra.fs.read')
:lua local result = read.read('')
:lua print(vim.inspect(result))
```
- Expected: `{ ok = false, error = "read: path must be a non-empty string" }`

**Test 77: Non-string path**
```vim
:lua local read = require('lifemode.infra.fs.read')
:lua local result = read.read(nil)
:lua print(vim.inspect(result))
```
- Expected: `{ ok = false, error = "read: path must be a non-empty string" }`

