# Manual QA Testing Instructions

This document provides manual testing instructions for each phase of the LifeMode plugin. Use these to verify functionality beyond what automated tests cover.

## Prerequisites

Before testing, ensure you have:
- Neovim installed with Lua support
- plenary.nvim installed (for automated tests)
- The plugin directory in your runtimepath


## Phase 12: NewNode Command

### Basic Command Execution

**Test: Create new node via command**
```vim
" Setup test vault
:lua vim.fn.mkdir("/tmp/qa_vault", "p")
:lua require("lifemode").setup({ vault_path = "/tmp/qa_vault" })

" Execute command
:LifeModeNewNode
```

**Expected:**
- New buffer opens
- Frontmatter visible on lines 1-3:
  ```
  ---
  id: <uuid>
  created: <timestamp>
  ---
  ```
- Cursor positioned on line 4, column 0
- Success notification: "[LifeMode] Created new node"
- File created at `/tmp/qa_vault/YYYY/MM-Mmm/DD/<uuid>.md`

**Verify file on disk:**
```vim
" Check current buffer file path
:echo expand("%:p")

" Should match pattern: /tmp/qa_vault/2026/01-Jan/22/<uuid>.md
```

**Test: Type content and save**
```vim
" With cursor on line 4, type some content
iThis is my first captured thought.
<Esc>
:w
```

**Expected:**
- Content saves to file
- File contains frontmatter + content
- No errors

**Cleanup:**
```vim
:lua vim.fn.delete("/tmp/qa_vault", "rf")
```

### Error Handling

**Test: Command with invalid vault**
```vim
:lua require("lifemode.config")._config = nil
:LifeModeNewNode
```

**Expected:**
- Error notification shown
- Message mentions vault_path or configuration
- No file created
- Original buffer unchanged


## Phase 24: Full-Text Search (FTS5)

### Manual QA Steps

1. **Setup:**
   ```vim
   :lua require('lifemode.config').validate_config({vault_path = '~/test_vault'})
   ```

2. **Create test nodes:**
   - Create file `~/test_vault/test1.md`:
     ```markdown
     ---
     id: aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa
     created: 1234567890
     ---
     The quick brown fox jumps over the lazy dog
     ```
   - Create file `~/test_vault/test2.md`:
     ```markdown
     ---
     id: bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb
     created: 1234567891
     ---
     Quick thinking leads to quick solutions
     ```

3. **Rebuild index:**
   ```vim
   :lua local builder = require('lifemode.infra.index.builder'); builder.rebuild_index()
   ```

4. **Test search:**
   ```vim
   :lua local search = require('lifemode.infra.index.search')
   :lua local results = search.search('quick')
   :lua print(vim.inspect(results))
   ```
   - Should return 2 nodes (both contain "quick")
   - test2.md should rank higher (more occurrences of "quick")

5. **Test phrase search:**
   ```vim
   :lua local results = search.search('"lazy dog"')
   :lua print(vim.inspect(results))
   ```
   - Should return 1 node (test1.md only)

6. **Test prefix search:**
   ```vim
   :lua local results = search.search('qui*')
   :lua print(vim.inspect(results))
   ```
   - Should return 2 nodes (matches "quick")

7. **Test FTS updates on node change:**
   - Edit `~/test_vault/test1.md`, change "fox" to "cat"
   - Save file (triggers incremental index update)
   ```vim
   :lua local results = search.search('fox')
   :lua print(#results.value) -- should be 0
   :lua local results = search.search('cat')
   :lua print(#results.value) -- should be 1
   ```

### Expected Results

- All searches return correct, ranked results
- FTS index updates automatically on file save
- No errors in `:messages`


## Phase 24: Full-Text Search (FTS5)

### Manual QA Steps

1. **Setup:**
   ```vim
   :lua require('lifemode.config').validate_config({vault_path = '~/test_vault'})
   ```

2. **Create test nodes:**
   - Create file `~/test_vault/test1.md`:
     ```markdown
     ---
     id: aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa
     created: 1234567890
     ---
     The quick brown fox jumps over the lazy dog
     ```
   - Create file `~/test_vault/test2.md`:
     ```markdown
     ---
     id: bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb
     created: 1234567891
     ---
     Quick thinking leads to quick solutions
     ```

3. **Rebuild index:**
   ```vim
   :lua local builder = require('lifemode.infra.index.builder'); builder.rebuild_index()
   ```

4. **Test search:**
   ```vim
   :lua local search = require('lifemode.infra.index.search')
   :lua local results = search.search('quick')
   :lua print(vim.inspect(results))
   ```
   - Should return 2 nodes (both contain "quick")
   - test2.md should rank higher (more occurrences of "quick")

5. **Test phrase search:**
   ```vim
   :lua local results = search.search('"lazy dog"')
   :lua print(vim.inspect(results))
   ```
   - Should return 1 node (test1.md only)

6. **Test prefix search:**
   ```vim
   :lua local results = search.search('qui*')
   :lua print(vim.inspect(results))
   ```
   - Should return 2 nodes (matches "quick")

7. **Test FTS updates on node change:**
   - Edit `~/test_vault/test1.md`, change "fox" to "cat"
   - Save file (triggers incremental index update)
   ```vim
   :lua local results = search.search('fox')
   :lua print(#results.value) -- should be 0
   :lua local results = search.search('cat')
   :lua print(#results.value) -- should be 1
   ```

### Expected Results

- All searches return correct, ranked results
- FTS index updates automatically on file save
- No errors in `:messages`


## Phase 28: Store Edges in Index

### Manual Test Procedure

**Prerequisites:**
- Neovim with lifemode.nvim installed
- sqlite.lua plugin installed (kkharji/sqlite.lua)
- Valid vault configured

**Test Script:**
```lua
local types = require('lifemode.domain.types')
local index = require('lifemode.infra.index')

-- Use real node UUIDs from your vault, or create test nodes first
local node1_uuid = "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa"
local node2_uuid = "bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb"
local node3_uuid = "cccccccc-cccc-4ccc-cccc-cccccccccccc"

-- Test 1: Insert wikilink edge
local edge1 = types.Edge_new(node1_uuid, node2_uuid, "wikilink", nil)
assert(edge1.ok)
local insert1 = index.insert_edge(edge1.value)
assert(insert1.ok)
print("✓ Inserted wikilink edge")

-- Test 2: Query outgoing edges
local out = index.find_edges(node1_uuid, "out", nil)
assert(out.ok)
assert(#out.value >= 1)
print("✓ Found " .. #out.value .. " outgoing edges")

-- Test 3: Query backlinks
local backlinks = index.find_edges(node2_uuid, "in", nil)
assert(backlinks.ok)
assert(#backlinks.value >= 1)
print("✓ Found " .. #backlinks.value .. " backlinks")

-- Test 4: Insert transclusion edge
local edge2 = types.Edge_new(node1_uuid, node3_uuid, "transclusion", nil)
assert(edge2.ok)
index.insert_edge(edge2.value)
print("✓ Inserted transclusion edge")

-- Test 5: Filter by kind
local wikilinks = index.find_edges(node1_uuid, "out", "wikilink")
assert(wikilinks.ok)
print("✓ Found " .. #wikilinks.value .. " wikilinks")

local transclusions = index.find_edges(node1_uuid, "out", "transclusion")
assert(transclusions.ok)
print("✓ Found " .. #transclusions.value .. " transclusions")

-- Test 6: Delete edges from node
local delete_res = index.delete_edges_from(node1_uuid)
assert(delete_res.ok)
local after = index.find_edges(node1_uuid, "out", nil)
assert(after.ok)
assert(#after.value == 0)
print("✓ Deleted edges, none remain")

print("✓ All manual tests passed")
```

**Expected Results:**
- All assertions pass
- No errors printed
- Edges queryable after insert
- Backlinks work correctly
- Kind filtering works
- Delete removes only outgoing edges

