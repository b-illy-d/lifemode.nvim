# Contributing to LifeMode

Technical guide for developers who want to understand or extend LifeMode.

## Project Philosophy

- **View-first**: Views are the primary UI. Vault files are storage, not the interface.
- **Markdown-native**: No proprietary formats. `grep` always works.
- **Lazy everything**: Index on demand, expand on demand.
- **Bible-aware**: Scripture references are first-class, not an afterthought.

## Key Abstractions

| Concept | Description |
|---------|-------------|
| **Node** | Canonical object with stable ID (task, heading, source, citation) |
| **Instance** | Placement of a node in a view tree (carries lens, depth, collapsed state) |
| **View** | Compiled buffer of instances |
| **Lens** | Deterministic renderer for a node type |

## Architecture

```
User → :LifeMode
         │
         ▼
   vault.lua ─────────► list .md files with mtimes
         │
         ▼
   parser.lua ────────► extract nodes (headings, tasks, sources)
         │                extract refs (wikilinks, Bible verses)
         ▼
   index.lua ─────────► in-memory index
         │                - node_locations
         │                - backlinks
         │                - tasks_by_state
         │                - nodes_by_date
         ▼
   views/daily.lua ───► build date hierarchy tree
   views/tasks.lua ───► build grouped task tree
         │
         ▼
   lens.lua ──────────► render instances to lines/highlights
         │
         ▼
   view.lua ──────────► create buffer, apply content
         │
         ▼
   extmarks.lua ──────► track spans for cursor queries
         │
         ▼
   controller.lua ────► handle keymaps, manage state
```

## Directory Structure

```
lua/lifemode/
├── init.lua           # Entry point, setup(), commands
├── config.lua         # Config validation, defaults
├── controller.lua     # View state, keymaps, user actions
├── vault.lua          # File discovery
├── parser.lua         # Markdown → nodes
├── index.lua          # In-memory index
├── view.lua           # Buffer creation
├── extmarks.lua       # Span metadata tracking
├── navigation.lua     # Expand/collapse, date jumping
├── lens.lua           # Renderer registry
├── patch.lua          # File modifications
├── wikilink.lua       # Wikilink handling
├── bible.lua          # Bible ref parsing
├── query.lua          # Filter system
├── core/
│   ├── dates.lua      # Date utilities
│   └── files.lua      # File I/O
└── views/
    ├── base.lua       # Shared rendering utils
    ├── daily.lua      # Daily view
    └── tasks.lua      # Tasks view

tests/
├── test_*.lua         # Test files (organized by phase)
├── minimal_init.lua   # Test harness
└── lifemode/
    └── init_spec.lua  # Spec-style tests
```

## Module Reference

### init.lua
Entry point and public API. Handles `setup()`, command registration, and delegates to other modules.

### config.lua
Configuration validation and defaults. All options validated with type checking.

### controller.lua
View state management and user interactions. Maintains current view, handles keymaps, coordinates the refresh cycle: action → patch → rebuild index → re-render.

### vault.lua
File discovery. Lists all `.md` files in vault with modification times.

### parser.lua
Markdown parsing. Extracts nodes (headings, tasks, list items, sources, citations) and refs (wikilinks, Bible verses) from files.

### index.lua
In-memory indexing with lazy initialization. Builds on first `get_or_build()`, updates incrementally on file save.

### view.lua
Buffer creation. Creates `nofile` scratch buffers and applies rendered content.

### extmarks.lua
Span metadata tracking using Neovim extmarks. Maps buffer positions to instance metadata for cursor queries.

### navigation.lua
Tree navigation helpers. Expand/collapse, jump by date, cursor positioning.

### lens.lua
Renderer registry. Each lens is a function that takes a node and returns `{lines, highlights}`.

### patch.lua
File modification operations. Toggle task state, adjust priority, modify tags/dates. Pattern: read file → modify line → write file.

### wikilink.lua
Wikilink parsing and cursor detection for `gd` navigation.

### bible.lua
Bible reference parsing, verse ID generation, URL construction.

### query.lua
Minimal query/filter system for tasks.

### views/base.lua
Shared view utilities: indentation, span tracking, output structure.

### views/daily.lua
Daily view implementation. Builds Year > Month > Day tree from nodes_by_date.

### views/tasks.lua
Tasks view implementation. Groups tasks by due date, priority, or tag.

## Data Structures

### Node (from parser)

```lua
{
  type = 'task',           -- 'task', 'heading', 'source', 'citation', 'list_item'
  line = 5,                -- 0-indexed line number
  text = 'Review PR',      -- Display text (metadata stripped)
  id = 'abc123',           -- Block ID (from ^id suffix)
  refs = {                 -- Outbound references
    { type = 'wikilink', target = 'tasks', ... },
    { type = 'bible', book = 'john', chapter = 3, verse_start = 16 },
  },
  props = {},              -- Properties for source/citation nodes

  -- Task-specific:
  state = 'todo',          -- 'todo' or 'done'
  priority = 1,            -- 1-5 or nil
  due = '2026-01-20',      -- YYYY-MM-DD or nil
  tags = {'work', 'docs'}, -- Array of tags
}
```

### Instance (in view tree)

```lua
{
  instance_id = 'i_001',   -- Unique within view
  target_id = 'abc123',    -- Node ID (nil for synthetic groups)
  lens = 'task/brief',     -- Current renderer
  depth = 2,               -- Tree depth
  collapsed = false,       -- Expansion state
  children = {...},        -- Child instances
  node = {...},            -- Reference to node data
}
```

### Index

```lua
{
  node_locations = {
    ['abc123'] = { file = '/path/to/file.md', line = 5, mtime = 1234567890 }
  },
  tasks_by_state = {
    todo = { node1, node2 },
    done = { node3 },
  },
  nodes_by_date = {
    ['2026-01-17'] = { node1, node2 },
  },
  backlinks = {
    ['target_id'] = {
      { source_id = 'abc', file = '/path.md', line = 10 },
    },
  },
}
```

## Adding Features

### Adding a New Lens

1. Register in `lens.lua`:

```lua
register('mytype/mylens', function(node)
  local line = format_my_node(node)
  return {
    lines = { line },
    highlights = {
      { line = 0, col_start = 0, col_end = 5, hl_group = 'MyHighlight' }
    }
  }
end)
```

2. Add to `get_available_lenses()` for cycling support.

### Adding a New View

1. Create `lua/lifemode/views/yourview.lua`:

```lua
local M = {}
local base = require('lifemode.views.base')

function M.build_tree(index, opts)
  local output = base.create_output()
  -- Build your tree structure
  return { instances = {...}, grouping = opts.grouping }
end

function M.render(tree, opts)
  local output = base.create_output()
  -- Render instances to lines
  return output
end

return M
```

2. Add to `init.lua` `open_view()` function.

### Adding a Patch Operation

1. Add to `patch.lua`:

```lua
function M.my_operation(node_id, idx)
  local loc = idx.node_locations[node_id]
  if not loc then return nil end

  local files = require('lifemode.core.files')
  local lines = files.read_lines(loc.file)
  if not lines then return nil end

  local line_idx = loc.line + 1
  local line = lines[line_idx]

  -- Modify the line
  local new_line = transform(line)
  lines[line_idx] = new_line

  files.write_lines(loc.file, lines)
  return result
end
```

### Adding a New Node Type

1. Add detection in `parser.lua` `_parse_line()`:

```lua
if line:match('^your_pattern') then
  return _parse_your_type(line, line_num)
end
```

2. Create `_parse_your_type()` function.

3. Add lens renderers in `lens.lua`.

## Coding Conventions

### Module Pattern

```lua
local M = {}

local _private_state = nil

function M.public_function()
  -- ...
end

local function private_helper()
  -- ...
end

function M._reset_state()
  _private_state = nil
end

return M
```

### No Comments

Per project convention, avoid comments unless absolutely necessary (e.g., complex regex). Code should be self-documenting through clear naming.

### Error Handling

- **Setup-time errors**: Use `error()` to halt
- **Runtime errors**: Use `vim.notify(msg, vim.log.levels.WARN)` for user feedback
- **API failures**: Check return values (e.g., `bufnr == 0 or not bufnr`)

### Functional Patterns

Prefer:
- `vim.tbl_map()`, `vim.tbl_filter()`
- Inline functions for callbacks
- Pure functions where possible

### Naming

- Public: `M.function_name()`
- Private: `local function helper_name()`
- Test helpers: `M._reset_state()`
- Constants: `UPPER_CASE`

## Testing

### Location

All tests go in `tests/` directory. **Never** create test files at project root.

```
tests/
├── test_t01_acceptance.lua
├── test_t02_config.lua
├── ...
└── minimal_init.lua
```

### Running Tests

```bash
make test                    # Run all tests
make test-phase1             # Run specific phase
nvim --headless -l tests/test_foo.lua  # Run single test
```

### Test Pattern

```lua
local lifemode = require('lifemode')

lifemode._reset_state()

lifemode.setup({ vault_root = '/tmp/test' })

local config = lifemode.get_config()
assert(config.vault_root == '/tmp/test')

print('PASS: test description')
```

### State Reset

Always reset module state between tests:

```lua
lifemode._reset_state()
controller._reset_state()
index._reset_state()
```

## Key Design Decisions

From [DECISIONS.md](DECISIONS.md):

| Decision | Rationale |
|----------|-----------|
| `bufhidden=hide` | View buffers persist for return navigation |
| Priority: !1 highest, !5 lowest | Matches org-mode convention |
| Bible ID: `bible:book:chapter:verse` | Deterministic, human-readable |
| Full refresh on lens cycle | Simpler than per-span updates (MVP) |
| Range refs expand to individual verses | Enables precise backlink queries |
| File mtime for date tracking | Zero-maintenance, no explicit dates needed |

## Dependencies

None required. Pure Lua + Neovim API.

Optional future integrations:
- `plenary.nvim` - Testing, async utilities
- `telescope.nvim` - Fuzzy pickers

## Data Flow Examples

### Opening a View

```
:LifeMode
  → init.open_view('daily')
    → index.get_or_build(vault_root)
      → vault.list_files() → [{path, mtime}]
      → for each file: parser.parse_file(path)
      → build node_locations, backlinks, tasks_by_state, nodes_by_date
    → daily.build_tree(index, config)
    → daily.render(tree, {index})
    → view.create_buffer()
    → view.apply_rendered_content(bufnr, rendered)
    → controller.set_current_view({bufnr, tree, index, spans})
    → controller.setup_keymaps(bufnr, config)
```

### Toggling a Task

```
<Space><Space>
  → controller.toggle_task(config)
    → extmarks.get_instance_at_cursor() → metadata
    → patch.toggle_task_state(node_id, index)
      → read file → modify line → write file
    → refresh_after_patch(config)
      → index._reset_state()
      → index.get_or_build()
      → daily.build_tree()
      → daily.render()
      → view.apply_rendered_content()
```

### Finding Backlinks

```
gr
  → controller.backlinks_at_cursor()
    → extmarks.get_instance_at_cursor() → {node}
    → index.get_backlinks(target, idx)
    → vim.fn.setqflist(items)
    → vim.cmd('copen')
```

### Creating a Node Inline

```
o
  → controller.create_node_inline(config)
    → extmarks.get_instance_at_cursor() → metadata.file
    → view.set_modifiable(bufnr, true)
    → insert blank line, enter insert mode
    → on InsertLeave:
      → patch.create_node(content, dest_file)
      → refresh_after_patch()
```

### Editing a Node Inline

```
i
  → controller.edit_node_inline(config)
    → extmarks.get_instance_at_cursor() → {node, target_id}
    → view.set_modifiable(bufnr, true)
    → startinsert
    → on InsertLeave:
      → strip view decorations from edited line
      → patch.update_node_text(node_id, new_text, index)
        → extract prefix, priority, due, tags, id from original
        → reconstruct: prefix + new_text + metadata
        → write file
      → refresh_after_patch()
```
