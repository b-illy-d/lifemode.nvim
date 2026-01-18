# LifeMode Overview

LifeMode is a Markdown-native productivity and wiki system for Neovim.

See PHILOSOPHY.md for the core mental model. See SPEC.md for detailed specification.

## Core Concept

**1 file = 1 node.** The vault is a portable database of markdown files organized by type.

```
vault/
├── notes/note-*.md      # General notes
├── tasks/task-*.md      # Actionable items
├── quotes/quote-*.md    # Quotations
├── sources/source-*.md  # Bibliography
├── citations/citation-*.md
└── projects/project-*.md # Ordered collections
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     User Interface                          │
│  :LifeMode → View buffers (daily, tasks, project)           │
│  :LifeModeNew → Create node files                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    init.lua (Entry Point)                   │
│  - setup(opts) with config validation                       │
│  - Command registration                                     │
│  - Orchestrates modules                                     │
└─────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   view.lua      │  │  controller.lua │  │   index.lua     │
│  Buffer creation│  │  View state &   │  │  Node indexing  │
│  (nofile type)  │  │  interactions   │  │  (1 file = 1)   │
└─────────────────┘  └─────────────────┘  └─────────────────┘
                                                  │
                              ┌───────────────────┤
                              ▼                   ▼
                     ┌─────────────────┐  ┌─────────────────┐
                     │   vault.lua     │  │  parser.lua     │
                     │  File discovery │  │  Single-node    │
                     │  Node creation  │  │  file parsing   │
                     └─────────────────┘  └─────────────────┘
                              │                   │
                              ▼                   ▼
                     ┌─────────────────────────────────────┐
                     │         Vault (Filesystem)          │
                     │    vault/{type}s/{type}-{id}.md     │
                     └─────────────────────────────────────┘
```

## Module Responsibilities

### init.lua
Plugin entry point: setup, config validation, command registration.

### vault.lua
File discovery and node creation:
- `list_files(root)` → all .md files with mtime
- `create_node(type, props, content)` → new node file
- Manages type-based folder structure

### parser.lua
Parses single-node files:
- `parse_file(path)` → node with props, type, content, refs
- Extracts `key:: value` properties
- Extracts task metadata (priority, due, tags)
- Extracts wikilinks and Bible references

### index.lua
Maintains node index:
- `build(root)` → full index from vault
- `get_or_build(root)` → lazy initialization
- `update_file(path)` → incremental update
- Maps: id→node, type→nodes, date→nodes, backlinks

### lens.lua
Node rendering:
- `render(node, lens_name)` → lines + highlights
- Registry of lenses per node type
- Standard: brief, detail, full, raw

### views/
View implementations:
- `daily.lua` → Year > Month > Day grouping
- `tasks.lua` → Due date / Priority / Tag grouping
- `project.lua` → Ordered node references

### controller.lua
View state and user interactions:
- Expand/collapse
- Lens cycling
- Task state toggling
- Navigation

### extmarks.lua
Buffer span tracking:
- Map line ranges to node metadata
- Cursor position lookup

## Data Flow

### Index Build
```
vault.list_files(root)
    │
    ▼ for each file
parser.parse_file(path)
    │
    ▼
Node: { type, id, props, content, refs }
    │
    ▼
index.add_node(node, path)
    │
    ▼
Populated index
```

### View Render
```
index.get_or_build(root)
    │
    ▼
Query + Grouping → tree of instances
    │
    ▼
For each instance: lens.render(node, lens_name)
    │
    ▼
Apply to buffer with extmarks
```

### Edit Action
```
User action (toggle, set due, etc.)
    │
    ▼
patch.operation(node_id, ...)
    │
    ▼
Update node file on disk
    │
    ▼
index.update_file(path)
    │
    ▼
Refresh view
```

## Node File Format

```markdown
type:: note
id:: abc123
created:: 2026-01-18

# Content Title

Body content with [[wikilinks]] and Bible refs like John 3:16.
```

## Configuration

```lua
require('lifemode').setup({
  vault_root = "~/notes",           -- REQUIRED
  leader = "<Space>",
  default_view = "daily",
  daily_view_expanded_depth = 3,
  tasks_default_grouping = "due_date",
})
```

## Commands

- `:LifeMode [view]` - Open view (daily, tasks)
- `:LifeModeNew [type]` - Create new node
- `:LifeModeNewTask` - Create task node
- `:LifeModeHello` - Show config
- `:LifeModeParse` - Debug parse current file

## File Structure

```
lifemode.nvim/
├── lua/lifemode/
│   ├── init.lua
│   ├── config.lua
│   ├── vault.lua
│   ├── parser.lua
│   ├── index.lua
│   ├── lens.lua
│   ├── view.lua
│   ├── controller.lua
│   ├── extmarks.lua
│   ├── patch.lua
│   ├── navigation.lua
│   ├── wikilink.lua
│   ├── query.lua
│   ├── bible.lua
│   ├── core/
│   │   ├── dates.lua
│   │   └── files.lua
│   └── views/
│       ├── base.lua
│       ├── daily.lua
│       ├── tasks.lua
│       └── project.lua
├── tests/
├── example_vault/
├── PHILOSOPHY.md
├── SPEC.md
└── OVERVIEW.md
```
