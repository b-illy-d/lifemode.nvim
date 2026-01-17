# LifeMode Overview

LifeMode is a Markdown-native productivity and wiki system for Neovim. This document summarizes what has been built so far.

## Project Status

**Phases Complete:** 1, 2 (of 15)
**Lines of Code:** ~700 (plugin) + ~40 test files
**Test Coverage:** 70+ tests, all passing

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     User Interface                          │
│  :LifeMode command → View buffers (nofile, scratch)         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    init.lua (Entry Point)                   │
│  - setup(opts) with config validation                       │
│  - Command registration (:LifeMode, :LifeModeOpen, etc.)    │
│  - Orchestrates other modules                               │
└─────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   view.lua      │  │  extmarks.lua   │  │   index.lua     │
│  Buffer creation│  │  Span tracking  │  │  Index system   │
│  (nofile type)  │  │  via extmarks   │  │  (lazy build)   │
└─────────────────┘  └─────────────────┘  └─────────────────┘
                                                  │
                              ┌───────────────────┤
                              ▼                   ▼
                     ┌─────────────────┐  ┌─────────────────┐
                     │   vault.lua     │  │  parser.lua     │
                     │  File discovery │  │  Markdown parse │
                     │  (.md + mtime)  │  │  (blocks/tasks) │
                     └─────────────────┘  └─────────────────┘
                              │                   │
                              ▼                   ▼
                     ┌─────────────────────────────────────┐
                     │         Vault (Filesystem)          │
                     │    ~/notes/**/*.md (user files)     │
                     └─────────────────────────────────────┘
```

## Module Responsibilities

### init.lua (201 lines)
The main plugin entry point.

- `setup(opts)` - Initialize plugin with user config
- Config validation (type checking, required fields, range validation)
- Command registration (`:LifeMode`, `:LifeModeOpen`, `:LifeModeParse`, etc.)
- Duplicate setup guard
- `_reset_state()` for testing

**Config Options:**
```lua
{
  vault_root = "~/notes",           -- REQUIRED: Path to vault
  leader = "<Space>",               -- LifeMode leader key
  max_depth = 10,                   -- Expansion depth limit
  max_nodes_per_action = 100,       -- Expansion budget
  bible_version = "ESV",            -- Default Bible version
  default_view = "daily",           -- Default view type
  daily_view_expanded_depth = 3,    -- Date levels to expand
  tasks_default_grouping = "due_date",
  auto_index_on_startup = false,
}
```

### vault.lua (29 lines)
Discovers Markdown files in the vault.

- `list_files(vault_root)` → `{ { path, mtime }, ... }`
- Uses `vim.fn.glob()` for recursive `.md` discovery
- Uses `vim.loop.fs_stat()` for file modification times
- Returns empty array for non-existent vault (graceful startup)

### parser.lua (175 lines)
Parses Markdown into structured blocks.

- `parse_buffer(bufnr)` → blocks from open buffer
- `parse_file(path)` → blocks from file on disk

**Block Types:**
```lua
-- Heading
{ type = "heading", line = 0, level = 2, text = "Section", id = "abc123" }

-- Task (with full metadata extraction)
{ type = "task", line = 5, state = "todo", text = "Do thing",
  id = "xyz789", priority = 2, due = "2026-01-20", tags = {"work", "urgent"} }

-- List item
{ type = "list_item", line = 10, text = "Item text", id = nil }
```

**Metadata Extraction:**
- Priority: `!1` through `!5` (1 = highest)
- Due date: `@due(YYYY-MM-DD)`
- Tags: `#tag` or `#tag/subtag`
- Block ID: `^id-suffix` at end of line

### index.lua (180 lines)
Maintains an in-memory index of all vault content.

**Data Structure:**
```lua
{
  node_locations = {
    ["abc123"] = { file = "/path/to/file.md", line = 5, mtime = 1705420800 }
  },
  tasks_by_state = {
    todo = { {task1}, {task2} },
    done = { {task3} }
  },
  nodes_by_date = {
    ["2026-01-16"] = { {id = "abc", file = "..."}, {node = {...}, file = "..."} }
  }
}
```

**API:**
```lua
index.create()                      -- Empty index
index.build(vault_root)             -- Full build from vault
index.get_or_build(vault_root)      -- Lazy initialization
index.is_built()                    -- Check if cached
index.invalidate()                  -- Clear cache
index.update_file(path, mtime)      -- Incremental update
index.setup_autocommands(vault_root) -- BufWritePost hook
```

**Features:**
- Lazy initialization (only builds on first access)
- Incremental updates via BufWritePost autocmd
- Autocmd cleanup on re-registration (prevents duplicates)
- Path normalization with `vim.fn.simplify()`

### view.lua (23 lines)
Creates LifeMode view buffers.

- `create_buffer()` → bufnr
- Buffer settings: `buftype=nofile`, `swapfile=false`, `bufhidden=wipe`, `filetype=lifemode`
- Unique buffer naming with counter (prevents E95 errors)
- Validates buffer creation succeeded

### extmarks.lua (92 lines)
Tracks metadata for rendered spans using Neovim extmarks.

- `create_namespace()` → namespace ID (singleton)
- `set_instance_span(bufnr, start, end, metadata)` → mark_id
- `get_instance_at_cursor()` → metadata or nil

**Features:**
- Module-local metadata storage (more reliable than ext_data API)
- Automatic cleanup on BufDelete/BufWipeout (prevents memory leaks)
- Cursor position lookup across all spans

## Data Flow

### Index Build
```
vault.list_files(root)
    │
    ▼ for each file
parser.parse_file(path)
    │
    ▼ for each block
index.add_node(idx, block, path, mtime)
    │
    ▼
Populated index with node_locations, tasks_by_state, nodes_by_date
```

### Incremental Update (on file save)
```
BufWritePost autocmd triggers
    │
    ▼
Check file is in vault (vim.startswith with trailing slash)
    │
    ▼
index.update_file(path, mtime)
    │
    ├─► Remove all entries from this file
    │
    └─► Re-parse and re-add entries
```

## Coding Conventions

### No Comments
Per project requirements (CLAUDE.md), code contains no comments unless absolutely necessary for understanding complex patterns (e.g., regex).

### Module Pattern
```lua
local M = {}

-- Private state
local _state = nil

-- Public functions
function M.public_function()
end

-- Test helper (underscore prefix)
function M._reset_state()
end

return M
```

### Error Handling
- **Setup/validation errors:** Use `error()` to halt execution
- **Runtime errors:** Use `vim.notify()` with log levels
- **API failures:** Check return values (e.g., `bufnr == 0`)

### Buffer API
- Use `vim.bo[bufnr].option` (not deprecated `nvim_buf_set_option`)
- Always validate buffer creation: `if bufnr == 0 or not bufnr then error(...)`
- Use `buftype=nofile` for view buffers

### Path Handling
- Normalize with `vim.fn.simplify()` (handles `//` vs `/`)
- Use `vim.startswith()` for prefix matching
- Add trailing slash when checking directory containment

### Testing
- Manual tests via `nvim --headless -l test_file.lua`
- TDD approach: RED → GREEN → REFACTOR
- Test both success and failure paths
- Edge case coverage required

## File Structure

```
lifemode.nvim/
├── lua/lifemode/
│   ├── init.lua        # Entry point, setup, commands
│   ├── vault.lua       # File discovery
│   ├── parser.lua      # Markdown parsing
│   ├── index.lua       # Index system
│   ├── view.lua        # Buffer creation
│   └── extmarks.lua    # Span tracking
├── plugin
│   └── lifemode.vim    # Autoload guard
├── tests/              # Test files (in tests/ dir)
├── test_*.lua          # Test files (root level)
├── SPEC.md             # Full specification
├── TODO.md             # Task breakdown
├── OVERVIEW.md         # This file
└── Makefile            # Test runner
```

## What's Next

**Phase 3: View Infrastructure** (T10-T12)
- Note: T10 (view buffer) and T11 (extmarks) already implemented
- T12: Basic lens renderer interface

**Phase 4: Daily View** (T13-T17)
- Date tree structure (Year > Month > Day)
- View rendering with extmarks
- Expand/collapse functionality
- Date navigation

**Phase 5+:** Navigation, task management, All Tasks view, wikilinks, Bible references, etc.

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Index storage | In-memory Lua tables | Simple, fast, sufficient for personal vaults |
| Lazy initialization | Build on first `:LifeMode` | Avoid startup delay |
| Incremental updates | Remove all + re-add | Simpler than tracking individual changes |
| Metadata storage | Module-local tables | ext_data API unreliable in Neovim |
| Path normalization | `vim.fn.simplify()` | Handles edge cases better than `fnamemodify` |
| Error propagation | Let errors bubble up | Caller responsible for handling |
| Parser approach | Lua patterns | Sufficient for MVP, simpler than tree-sitter |
