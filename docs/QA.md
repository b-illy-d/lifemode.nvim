# Manual QA Testing Instructions

This document covers **user-facing workflows only**. If you're looking for API-level tests (config validation, search, edges, etc.), those are automated in `tests/*_spec.lua`.

## Automated Tests

Run automated tests with plenary:
```bash
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.vim'}"
```

Key test files:
- `tests/config_reset_spec.lua` - Config validation and reset behavior
- `tests/search_spec.lua` - Full-text search (FTS5) functionality
- `tests/edges_spec.lua` - Edge storage and querying

## Prerequisites

Before testing, ensure you have:
- Neovim installed with Lua support
- LifeMode configured with a valid vault_path
- **kkharji/sqlite.lua installed (required for indexing features)**
- **plenary.nvim installed (for running automated tests)**

## Quick Setup

```bash
mkdir -p ~/test_vault
```

In your Neovim config:
```lua
require("lifemode").setup({ vault_path = "~/test_vault" })
```

## Phase 12: NewNode Command

### Test: Create and edit new node

1. Press `<leader>nc` or run `:LifeModeNewNode`
2. Type some content: `This is my first captured thought.`
3. Save with `:w`
4. Run `:echo expand("%:p")` to verify file path

#### Expected

- New buffer opens with frontmatter (id, created, ---)
- Cursor positioned on line 5 (after frontmatter)
- File created in date directory: `~/test_vault/YYYY/MM-Mmm/DD/<uuid>.md`
- Content persists after save
- Success notification shown

**Note:** Tests for config validation and error handling are automated in `tests/config_reset_spec.lua`


## Phase 29: Backlinks in Sidebar

### Test: Open sidebar

Open a markdown file with nodes
Position cursor on a node
Run `:LifeModeSidebar` or press `<leader>ns`

#### Expected

- Floating window appears on right side (30% width)
- Shows "# Relations" header
- No errors

### Test: View backlinks section

With sidebar open on a node that has incoming edges

#### Expected

- Shows "## Backlinks (N)" section
- Lists file paths of linking nodes
- Count matches number of nodes linking to current node
- Shows "(none)" if no backlinks

### Test: View outgoing links section

With sidebar open on a node that has outgoing links

#### Expected

- Shows "## Outgoing (N)" section
- Lists file paths of linked nodes
- Count matches number of wikilinks in current node
- Shows "(none)" if no outgoing links

### Test: Jump to linked node

Move cursor to a line with a file path (- /path/to/file.md)
Press `<CR>`

#### Expected

- Opens that file in main window
- Cursor moves to main window
- Sidebar remains open

### Test: Toggle close sidebar

Run `:LifeModeSidebar` again or press `<leader>ns`

#### Expected

- Sidebar closes
- No errors

### Test: Reopen sidebar

Press `<leader>ns` again

#### Expected

- Sidebar reopens with info for node at cursor
- Content reflects current node

### Test: Close with 'q'

With sidebar open, press `q` in sidebar buffer

#### Expected

- Sidebar closes

### Test: No node at cursor

Move cursor to empty area (no node)
Try to open sidebar with `<leader>ns`

#### Expected

- Error message "cursor not within any node"

### Test: Node with no backlinks

Open sidebar on a node with no incoming edges

#### Expected

- Backlinks section shows "(none)"

### Test: Node with no outgoing links

Open sidebar on a node with no wikilinks

#### Expected

- Outgoing section shows "(none)"

### Test: Press Enter on header line

Move cursor to "## Backlinks" or "## Outgoing" line
Press `<CR>`

#### Expected

- Error message "no link on current line"


## Phase 30: Update Sidebar on Cursor Move

### Test: Check updatetime setting

```vim
:set updatetime?
```

#### Expected

- Shows current updatetime value (default 4000ms)

### Test: Auto-update on cursor move

Open markdown file with multiple nodes (Node A and Node B)
Position cursor on Node A
Open sidebar with `<leader>ns`
Move cursor to Node B
Wait for updatetime milliseconds (or run `:doautocmd CursorHold`)

#### Expected

- Sidebar initially shows relations for Node A
- After CursorHold event, sidebar automatically updates to show Node B relations
- No manual refresh needed
- No flicker

### Test: No-op when staying on same node

Sidebar open on Node A
Move cursor within Node A (different lines, same node)
Wait for CursorHold

#### Expected

- Sidebar doesn't flicker or re-render
- Content stays same

### Test: Auto-update when sidebar initially closed

Close sidebar
Move to Node A, open sidebar with `<leader>ns`
Move to Node B, wait for CursorHold

#### Expected

- Sidebar updates to Node B automatically

### Test: No errors when cursor not in node

Sidebar open on Node A
Move cursor to empty area (no node boundaries)
Wait for CursorHold

#### Expected

- No errors in `:messages`
- Sidebar still shows Node A (last valid state)

### Test: No auto-update in non-markdown files

Open sidebar in markdown file
Switch to .lua or .txt file
Move cursor around
Wait for CursorHold

#### Expected

- Sidebar doesn't update (stays on last markdown node)
- No errors

### Test: Manual trigger with doautocmd

```vim
:doautocmd CursorHold
```

#### Expected

- Same behavior as waiting for updatetime
- Sidebar updates if cursor moved to new node

### Test: Rapid cursor movement

Rapidly move cursor between multiple nodes

#### Expected

- Only updates after CursorHold fires (natural debouncing)
- No performance lag
- No visible lag when moving cursor
- Auto-update completes in <50ms


## Phase 38: Jump to Source (`gd`)

### Test: Jump to existing source file

Create source file: `~/vault/.lifemode/sources/testkey.yaml`
In a markdown file, write: `This cites @testkey for reference.`
Save the file
Move cursor to the `@testkey` citation (anywhere within `@testkey`)
Press `gd` in normal mode

#### Expected

- Source file `testkey.yaml` opens in current window
- No error messages

### Test: Create missing source file (user chooses Yes)

In markdown file, write: `This cites @newkey that doesn't exist.`
Move cursor to `@newkey`
Press `gd`
Choose "Yes" in confirmation dialog

#### Expected

- Confirmation dialog shows: "Source file not found: newkey.yaml\nCreate it?"
- Two options: "Yes" and "No", default is "No"
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

### Test: Create missing source file (user chooses No)

Write: `This cites @anotherkey that doesn't exist.`
Move cursor to `@anotherkey`
Press `gd`
Choose "No" in confirmation dialog

#### Expected

- Error notification: "Source file not found: anotherkey.yaml"
- No file created
- Buffer unchanged

### Test: Not on a citation

Write: `This is plain text without citations.`
Move cursor to "plain" (not a citation)
Press `gd`

#### Expected

- Error notification: "No citation under cursor"
- No file operations

### Test: Multiple citations on same line

Write: `Sources include @first, @second, and @third citations.`
Move cursor to `@second`
Press `gd`

#### Expected

- Confirmation dialog for `second.yaml` (not first or third)
- Correct source key detected based on cursor position

### Test: Command invocation

Write: `@cmdtest citation`
Move cursor to `@cmdtest`
Run `:LifeModeEditSource`

#### Expected

- Same behavior as `gd` keymap
- Works identically

### Test: Citation at line start

Write: `@startkey is at the beginning`
Move cursor to `@startkey`
Press `gd`

#### Expected

- Works correctly (edge case)

### Test: Citation at line end

Write: `Reference ends with @endkey`
Move cursor to `@endkey`
Press `gd`

#### Expected

- Works correctly (edge case)

### Test: gd in non-markdown files

Open a `.lua` file
Press `gd`

#### Expected

- Vim's default `gd` behavior (go to local definition)
- LifeMode does NOT override it
- Buffer-local keymap only applies to markdown

### Test: Directory creation

Delete `.lifemode/sources/` directory if it exists
Write: `@testcreate citation`
Move cursor to `@testcreate`, press `gd`
Choose "Yes"

#### Expected

- Directory `.lifemode/sources/` created automatically
- Source file created inside it
- No permission errors

### Test: Citation with hyphens and numbers

Write: `@test-key-123` (hyphens, numbers)
Press `gd`

#### Expected

- Works correctly
- Source file `test-key-123.yaml` created/opened

### Test: Citation with underscores and uppercase

Write: `@test_key_ABC` (underscores, uppercase)
Press `gd`

#### Expected

- Works correctly
- Source file `test_key_ABC.yaml` created/opened
