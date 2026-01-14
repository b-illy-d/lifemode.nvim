# Project Patterns

## Architecture Patterns
- Neovim plugin with Lua
- Engine boundary: keep parsing/indexing separate from UI
- Start with pure Lua, prepare for external process later

## Code Conventions
- Use plenary.nvim for utilities and testing
- Keep dependencies minimal
- Follow Neovim plugin structure: lua/lifemode/

## File Structure
- `lua/lifemode/init.lua` - main entry point with setup()
- `lua/lifemode/view.lua` - view buffer creation and management
- `lua/lifemode/extmarks.lua` - extmark-based span metadata tracking
- `lua/lifemode/parser.lua` - minimal Markdown block parser (headings, list items, tasks)
- `lua/lifemode/uuid.lua` - UUID v4 generation using system uuidgen
- `lua/lifemode/blocks.lua` - block ID management (ensure_ids_in_buffer)
- `lua/lifemode/node.lua` - in-memory Node model with tree structure
- `lua/lifemode/config.lua` - configuration management (future)
- `lua/lifemode/engine/` - parsing, indexing, query logic (future)
- `tests/lifemode/` - test files using plenary (future)
- `tests/*_spec.lua` - test files using custom test runner
- `tests/manual_*_test.lua` - manual acceptance tests

## Testing Patterns
- Use plenary.nvim test harness (when available)
- Custom minimal test runner for MVP (tests/run_tests.lua)
- File naming: `*_spec.lua`
- TDD cycle: RED → GREEN → REFACTOR
- Edge case testing: test empty strings, wrong types, boundary values
- Runtime testing: test command registration, config merging, path handling

## Common Gotchas
- vault_root must be provided by user (required config)
- Leader key is configurable, default is `<Space>`
- Bible references are first-class features
- **Quickfix API quirk**: Cannot pass both list and options in single call to vim.fn.setqflist
- **string.find return order**: Returns (start, end, captures...) not (start, captures, end)
- **Wikilink target matching**: [[Page]] and [[Page#Section]] are different targets (exact match)
- **Wikilink pattern captures full target**: [[Page#Heading]] target is "Page#Heading", not just "Page"
- **Empty wikilinks [[]] should be filtered**: Use target:match("%S") to check for non-whitespace content
- **Backlinks index by full target**: Index includes # and ^ suffixes for complete reference tracking
- **Lua treats empty string as truthy**: `if not ""` is false, string passes check
- **vim.tbl_extend does not validate types**: accepts any type, validate after merge
- **Config merge replaces, doesn't accumulate**: second setup() resets unspecified keys
- **Path normalization not automatic**: ~, trailing slashes, // not handled by default
- **Extmarks don't allow arbitrary keys**: must store custom metadata separately
- **Extmark end_row is exclusive**: add 1 when setting, subtract 1 when checking range
- **Multi-line span detection requires overlap checking**: query from buffer start and check if extmark covers target line
- **Lua patterns vs regex**: Lua uses `%` for special chars, not `\` (e.g., `%[` not `\[`)
- **Function order matters in Lua**: local functions must be defined before use
- **Markdown heading syntax**: Must have space after # symbols (`# Heading` not `#Heading`)
- **Parser ignores non-block lines**: Regular text/paragraphs not parsed, only headings and lists
- **UUID generation output includes newline**: vim.fn.system('uuidgen') returns string with \n, must strip with :gsub('%s+', '')
- **UUID case sensitivity**: uuidgen returns uppercase by default, use :lower() for consistent formatting
- **Buffer line indexing**: nvim_buf_get_lines returns 1-indexed table, but nvim_buf_set_lines uses 0-indexed positions
- **Buffer modification in loops**: Lines table becomes stale after nvim_buf_set_lines, update local copy for subsequent iterations
- **Parser indentation support**: List patterns must include `^%s*` prefix to match indented items
- **Hierarchy tracking**: Stack-based approach works well for both heading levels and list indentation
- **Node tree context switching**: Must reset list stack when encountering a heading (different hierarchy context)

## Dependencies
- plenary.nvim (async, utilities, testing)
- telescope.nvim (fuzzy finder, pickers)
- nvim-treesitter (optional, for enhanced Markdown parsing)

## Error Handling
- Validate required config (vault_root)
- Provide clear error messages for missing config
- Validate types for all config options (not just vault_root)
- Check for empty strings, not just nil
- Validate boundary values for numeric configs

## Silent Failure Prevention (Learned from T00 Audit)

### Type Validation Pattern
```lua
-- BAD: Only validates vault_root type
if type(user_config.vault_root) ~= 'string' then
  error('vault_root must be a string')
end
config = vim.tbl_extend('force', defaults, user_config)

-- GOOD: Validates all types after merge
config = vim.tbl_extend('force', defaults, user_config)
if type(config.leader) ~= 'string' then
  error('leader must be a string')
end
if type(config.max_depth) ~= 'number' then
  error('max_depth must be a number')
end
```

### Empty String Check Pattern
```lua
-- BAD: Empty string passes
if not user_config.vault_root then
  error('vault_root is required')
end

-- GOOD: Rejects empty and whitespace
if not user_config.vault_root or user_config.vault_root:match('^%s*$') then
  error('vault_root is required and cannot be empty')
end
```

### Boundary Validation Pattern
```lua
-- BAD: Accepts any number
if type(config.max_depth) ~= 'number' then
  error('max_depth must be a number')
end

-- GOOD: Enforces reasonable bounds
if type(config.max_depth) ~= 'number' or config.max_depth < 1 or config.max_depth > 100 then
  error('max_depth must be a number between 1 and 100')
end
```

### Path Normalization Pattern
```lua
local function normalize_path(path)
  -- Expand home directory
  path = vim.fn.expand(path)
  -- Remove trailing slash (unless root /)
  if path ~= '/' then
    path = path:gsub('/$', '')
  end
  return path
end

config.vault_root = normalize_path(user_config.vault_root)
```

## Edge Cases to Test

When adding new configuration options, always test:

1. **Type validation**
   - Wrong type (number for string, string for number, table, function)
   - nil (should use default or error if required)

2. **Empty/boundary values**
   - Empty string: ''
   - Whitespace: '   '
   - Zero: 0
   - Negative: -1
   - Very large: 999999

3. **Special characters**
   - Paths with spaces: '/path with spaces/'
   - Unicode: '/path/with/日本語/'
   - Special chars: '/path-with_special.chars/'

4. **Runtime edge cases**
   - Multiple calls to setup()
   - Command registration conflicts
   - Config accessed before setup()
   - Long strings (test output rendering)

## Quickfix and References Patterns (T07a)

### Quickfix List API
```lua
-- Set quickfix items and title separately
vim.fn.setqflist(items, 'r')  -- Replace with items
vim.fn.setqflist({}, 'a', { title = 'My Title' })  -- Append title

-- Get quickfix with title
local qf_info = vim.fn.getqflist({ title = 1 })
print(qf_info.title)

-- Quickfix item format
{
  bufnr = bufnr,
  lnum = line_number,  -- 1-indexed
  col = column,        -- 1-indexed (display), 0-indexed (internal)
  text = preview_text,
}
```

### Extract Target Under Cursor Pattern
```lua
-- Check if cursor position falls within match bounds
for match_start, target, match_end in text:gmatch("()%[%[([^%]]+)%]%]()") do
  local start_col = match_start - 1  -- Convert to 0-indexed
  local end_col = match_end - 1

  if col >= start_col and col < end_col then
    return target, "wikilink"
  end
end
```

### Find Multiple References in Same Line
```lua
-- Use while loop with search_pos to find all matches
local search_pos = 1
while true do
  local match_start, match_end, match_target = line:find("%[%[([^%]]+)%]%]", search_pos)
  if not match_start then break end

  -- Process match...

  search_pos = match_end + 1  -- Continue search after this match
end
```

### Buffer-Local Keymaps
```lua
-- Set keymap for specific buffer (survives window switches)
vim.keymap.set('n', 'gr', function()
  require('lifemode.references').find_references_at_cursor()
end, { buffer = bufnr, noremap = true, silent = true })
```

## Bible Reference Patterns (T07)

### Book Name Mapping
- Mapping table: abbreviated/full name → canonical name (lowercase, no spaces)
- Covers all 66 books + common abbreviations
- Examples: "gen" → "genesis", "rom" → "romans", "matt" → "matthew"
- Numbered books: "1cor" → "1corinthians", "1john" → "1john", "2tim" → "2timothy"
- Psalm variations: "psalm", "psalms", "ps" all → "psalms"

### Lua Pattern for Bible References
```lua
-- Pattern: ([%d]?%s?[%a]+)%s+(%d+):(%d+)%-?(%d*)
-- Captures: book, chapter, verse_start, verse_end (optional)
-- Handles: John 3:16, 1 Cor 13:4, Rom 8:28-30
```

### Verse ID Format
- Deterministic: `bible:book:chapter:verse`
- All lowercase, no spaces
- Examples: `bible:john:3:16`, `bible:romans:8:28`, `bible:psalms:23:1`

### Integration Pattern
```lua
-- In node.lua build_nodes_from_buffer:
local refs = extract_wikilinks(block.text)
local bible_refs = bible.parse_bible_refs(block.text)
for _, ref in ipairs(bible_refs) do
  table.insert(refs, ref)
end
-- Bible refs participate in backlinks system same as wikilinks
```

## Test Template for New Features

```lua
describe("Edge Cases: [feature name]", function()
  before_each(function()
    lifemode._reset_for_testing()
  end)

  test("rejects wrong type", function()
    assert_error(function()
      lifemode.setup({ vault_root = '/test', [option] = 123 })
    end, "must be a")
  end)

  test("rejects empty string", function()
    assert_error(function()
      lifemode.setup({ vault_root = '/test', [option] = '' })
    end)
  end)

  test("handles boundary values", function()
    assert_no_error(function()
      lifemode.setup({ vault_root = '/test', [option] = [boundary_value] })
    end)
  end)
end)
```
