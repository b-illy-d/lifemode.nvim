# Manual QA Testing Instructions

This document provides manual testing instructions for each phase of the LifeMode plugin. Use these to verify functionality beyond what automated tests cover.

## Prerequisites

Before testing, ensure you have:
- Neovim installed with Lua support
- plenary.nvim installed (for automated tests)
- The plugin directory in your runtimepath


## Phase 12: NewNode Command

### Test: Create new node via command
```vim
" Setup test vault
:lua vim.fn.mkdir("/tmp/qa_vault", "p")
:lua require("lifemode").setup({ vault_path = "/tmp/qa_vault" })

" Execute command
:LifeModeNewNode
```
#### Expected
- New buffer opens
- Frontmatter visible on lines 1-4:
  ```
  ---
  id: <uuid>
  created: <timestamp>
  ---
  ```
- Cursor positioned on line 5, column 0
- Success notification: "[LifeMode] Created new node"
- File created at `/tmp/qa_vault/YYYY/MM-Mmm/DD/<uuid>.md`

**Verify file on disk:**
```vim
" Check current buffer file path
:echo expand("%:p")

" Should match pattern: /tmp/qa_vault/2026/01-Jan/22/<uuid>.md
```
### Test: Type content and save
```vim
" With cursor on line 5, type some content
iThis is my first captured thought.
<Esc>
:w
```

#### Expected
- Content saves to file
- File contains frontmatter + content
- No errors

**Cleanup:**
```vim
:lua vim.fn.delete("/tmp/qa_vault", "rf")
```

### Error Handling

### Test: Command with invalid vault
```vim
:lua require("lifemode.config")._config = nil
:LifeModeNewNode
```

#### Expected
- Error notification shown
- Message mentions vault_path or configuration
- No file created
- Original buffer unchanged

## Phase 24: Full-Text Search (FTS5)

### Before ALl

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

### Test search
   ```lua
   local search = require('lifemode.infra.index.search')
   local results = search.search('quick')
   print(vim.inspect(results))
   ```
#### Expected
   - Should return 2 nodes (both contain "quick")
   - test2.md should rank higher (more occurrences of "quick")

### Test phrase search
   ```lua
   local search = require('lifemode.infra.index.search')
   local results = search.search('"lazy dog"')
   print(vim.inspect(results))
   ```
#### Expected
   - Should return 1 node (test1.md only)

### Test prefix search
   ```lua
   local search = require('lifemode.infra.index.search')
   local results = search.search('qui*')
   print(vim.inspect(results))
   ```
#### Expected
   - Should return 2 nodes (matches "quick")

### Test FTS updates on node change
   - Edit `~/test_vault/test1.md`, change "fox" to "cat"
   - Save file (triggers incremental index update)
   ```lua
   local search = require('lifemode.infra.index.search')
   local results = search.search('fox')
   print(#results.value) -- should be 0

   results = search.search('cat')
   print(#results.value) -- should be 1
   ```

#### Expected

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


## Phase 29: Backlinks in Sidebar

### Manual Test Procedure

**Prerequisites:**
- Neovim with lifemode.nvim installed
- Vault with multiple nodes
- At least one node with wikilinks to other nodes
- Edges stored in index (Phase 28 working)

**Test Steps:**

1. **Open sidebar**
   - Open a markdown file with nodes
   - Position cursor on a node
   - Run `:LifeModeSidebar` or press `<leader>ns`
   - #### Expected Floating window appears on right side (30% width)
   - #### Expected Shows "# Relations" header

2. **View backlinks**
   - Sidebar should show "## Backlinks (N)" section
   - If node has incoming edges, should list file paths
   - If no backlinks, should show "(none)"
   - #### Expected Count matches number of nodes linking to current node

3. **View outgoing links**
   - Sidebar should show "## Outgoing (N)" section
   - Should list file paths of linked nodes
   - If no outgoing links, should show "(none)"
   - #### Expected Count matches number of wikilinks in current node

4. **Jump to linked node**
   - Move cursor to a line with a file path (- /path/to/file.md)
   - Press `<CR>`
   - #### Expected Opens that file in main window
   - #### Expected Cursor moves to main window
   - #### Expected Sidebar remains open

5. **Toggle close sidebar**
   - Run `:LifeModeSidebar` again or press `<leader>ns`
   - #### Expected Sidebar closes
   - #### Expected No errors

6. **Reopen sidebar**
   - Press `<leader>ns` again
   - #### Expected Sidebar reopens with info for node at cursor
   - #### Expected Content reflects current node

7. **Close with 'q'**
   - With sidebar open, press `q` in sidebar buffer
   - #### Expected Sidebar closes

8. **No node at cursor**
   - Move cursor to empty area (no node)
   - Try to open sidebar with `<leader>ns`
   - #### Expected Error message "cursor not within any node"

**Edge Cases:**

- Node with no backlinks: should show "(none)"
- Node with no outgoing links: should show "(none)"
- Node with both: should show both lists correctly
- Multiple backlinks: all should be listed
- Press `<CR>` on header line: should show "no link on current line" error


## Phase 30: Update Sidebar on Cursor Move

### Manual Test Procedure

**Prerequisites:**
- Neovim with lifemode.nvim installed
- Vault with multiple nodes in same file
- At least 2 nodes with edges between them

**Test Steps:**

1. **Setup: Check updatetime**
   - Run `:set updatetime?` in Neovim
   - Note the value (default is 4000ms)
   - This determines how long to wait for auto-update

2. **Auto-update on cursor move**
   - Open markdown file with multiple nodes
   - Position cursor on Node A
   - Open sidebar with `<leader>ns`
   - #### Expected Sidebar shows relations for Node A
   - Move cursor to Node B
   - Wait for updatetime milliseconds (or trigger with `:doautocmd CursorHold`)
   - #### Expected Sidebar automatically updates to show Node B relations
   - #### Expected No manual refresh needed

3. **No-op when staying on same node**
   - Sidebar open on Node A
   - Move cursor within Node A (different lines, same node)
   - Wait for CursorHold
   - #### Expected Sidebar doesn't flicker or re-render
   - #### Expected Content stays same

4. **Works when sidebar initially closed**
   - Close sidebar
   - Move to Node A, open sidebar with `<leader>ns`
   - Shows Node A
   - Move to Node B, wait for CursorHold
   - #### Expected Sidebar updates to Node B

5. **No errors when cursor not in node**
   - Sidebar open on Node A
   - Move cursor to empty area (no node boundaries)
   - Wait for CursorHold
   - #### Expected No errors in `:messages`
   - #### Expected Sidebar still shows Node A (last valid state)

6. **No auto-update in non-markdown files**
   - Open sidebar in markdown file
   - Switch to .lua or .txt file
   - Move cursor around
   - Wait for CursorHold
   - #### Expected Sidebar doesn't update (stays on last markdown node)
   - #### Expected No errors

7. **Manual trigger works**
   - Run `:doautocmd CursorHold` to manually trigger
   - #### Expected Same behavior as waiting for updatetime

**Edge Cases:**

- Rapidly moving between nodes: only updates after CursorHold (natural debouncing)
- Opening sidebar when already open: still works, updates to current node
- Multiple markdown buffers: auto-update tracks cursor in current buffer

**Performance:**
- Auto-update should be fast (<50ms)
- No visible lag when moving cursor
- Check `:messages` for any warnings


## Phase 38: Jump to Source (`gd`)

### Manual Test Procedure

**Prerequisites:**
- Neovim with lifemode.nvim installed
- Valid vault configured
- Markdown file in vault

### Test 1: Jump to existing source file

**Steps:**
1. Create source file: `~/vault/.lifemode/sources/testkey.yaml`
2. In a markdown file, write: `This cites @testkey for reference.`
3. Save the file
4. Move cursor to the `@testkey` citation (anywhere within `@testkey`)
5. Press `gd` in normal mode

#### Expected
- Source file `testkey.yaml` opens in current window
- No error messages

### Test 2: Create missing source file

**Steps:**
1. In markdown file, write: `This cites @newkey that doesn't exist.`
2. Move cursor to `@newkey`
3. Press `gd`

#### Expected
- Confirmation dialog: "Source file not found: newkey.yaml\nCreate it?"
- Two options: "Yes" and "No", default is "No"

**If user chooses Yes:**
- New file created at `~/vault/.lifemode/sources/newkey.yaml`
- File opens with template:
  ```yaml
  ---
  key: newkey
  title: ""
  author: ""
  year: ""
  type: article
  url: ""
  notes: ""
  ```

**If user chooses No:**
- Error notification: "Source file not found: newkey.yaml"
- No file created
- Buffer unchanged

### Test 3: Not on a citation

**Steps:**
1. Write: `This is plain text without citations.`
2. Move cursor to "plain" (not a citation)
3. Press `gd`

#### Expected
- Error notification: "No citation under cursor"
- No file operations

### Test 4: Multiple citations on same line

**Steps:**
1. Write: `Sources include @first, @second, and @third citations.`
2. Move cursor to `@second`
3. Press `gd`

#### Expected
- Confirmation dialog for `second.yaml` (not first or third)
- Correct source key detected based on cursor position

### Test 5: Command invocation

**Steps:**
1. Write: `@cmdtest citation`
2. Move cursor to `@cmdtest`
3. Run `:LifeModeEditSource`

#### Expected
- Same behavior as `gd` keymap
- Works identically

### Test 6: Citation at line boundaries

**Steps:**
1. Write: `@startkey is at the beginning`
2. Write: `Reference ends with @endkey`
3. Test both citations with `gd`

#### Expected
- Both work correctly (edge cases)

### Test 7: `gd` in non-markdown files

**Steps:**
1. Open a `.lua` file
2. Press `gd`

#### Expected
- Vim's default `gd` behavior (go to local definition)
- LifeMode does NOT override it
- Buffer-local keymap only applies to markdown

### Test 8: Directory creation

**Steps:**
1. Delete `.lifemode/sources/` directory if it exists
2. Write: `@testcreate citation`
3. Move cursor to `@testcreate`, press `gd`
4. Choose "Yes"

#### Expected
- Directory `.lifemode/sources/` created automatically
- Source file created inside it
- No permission errors

### Test 9: Valid citation characters

**Steps:**
1. Write: `@test-key-123` (hyphens, numbers)
2. Write: `@test_key_ABC` (underscores, uppercase)
3. Test both with `gd`

#### Expected
- Both work correctly
- Source files `test-key-123.yaml` and `test_key_ABC.yaml` created/opened

### Expected Results Summary

- ✓ Jump to existing sources works
- ✓ Create missing sources with confirmation
- ✓ Error when not on citation
- ✓ Correct citation detection on multi-citation lines
- ✓ Command and keymap both work
- ✓ Edge cases (line start/end) handled
- ✓ Non-markdown files unaffected
- ✓ Directory auto-creation works
- ✓ Valid characters (hyphens, underscores, numbers) supported

