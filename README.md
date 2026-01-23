# lifemode.nvim

A Neovim-native personal research operating system for capturing, organizing, and discovering creative relations among information.

## What is LifeMode?

LifeMode is a keyboard-centric knowledge management system built for Neovim that treats **citations as first-class** and enables **graph-first thinking**. Unlike traditional hierarchical note systems, LifeMode embraces:

- **Zero-decision capture** — content first, organization later
- **True narrowing** — any node's subtree can become your entire buffer
- **First-class citations** — extensible schemes for Bible verses, academic papers, or custom sources
- **Transclusion with cycle detection** — recursive embedding that just works
- **Graph relationships** — productive and creative connections between ideas

Built on immutable value objects with a deep, composable API. Small interface, massive power.

## Features

- **Capture workflow**: Quick node creation to dated directories (`YYYY/MM-Mmm/DD/`)
- **Narrowing**: True narrowing to focus on single nodes (org-mode style)
- **Transclusion**: Recursive node embedding with cycle detection
- **Citations**: Extensible citation schemes (BibTeX, Bible, custom)
- **SQLite indexing**: Fast graph queries and backlink tracking
- **Sidebar context**: Passive accordion showing citations, backlinks, relations
- **Extmarks**: Buffer-local node tracking with frontmatter persistence
- **YAML sources**: Human-editable source files auto-generate `.bib` for LaTeX

## Installation

### lazy.nvim

```lua
{
  "billy/lifemode.nvim",
  config = function()
    require("lifemode").setup({
      vault_path = "~/vault"  -- REQUIRED: path to your vault
    })
  end
}
```

### packer.nvim

```lua
use {
  'billy/lifemode.nvim',
  config = function()
    require('lifemode').setup({
      vault_path = "~/vault"
    })
  end
}
```

### vim-plug

```vim
Plug 'billy/lifemode.nvim'
```

Then in your `init.lua`:

```lua
require('lifemode').setup({
  vault_path = "~/vault"
})
```

## Development

### Installing from local

Clone the repo:

```bash
git clone https://github.com/billy/lifemode.nvim.git ~/projects/lifemode.nvim
```

Then configure your plugin manager to use the local path:

#### lazy.nvim

```lua
{
  dir = "~/projects/lifemode.nvim",
  config = function()
    require("lifemode").setup({
      vault_path = "~/vault"
    })
  end
}
```

#### packer.nvim

```lua
use {
  '~/projects/lifemode.nvim',
  config = function()
    require('lifemode').setup({
      vault_path = "~/vault"
    })
  end
}
```

#### vim-plug

```vim
Plug '~/projects/lifemode.nvim'
```

## Quick Start

### 1. Create your vault directory

```bash
mkdir -p ~/vault
```

### 2. Capture your first node

In Neovim, press `<leader>nc` or run `:LifeModeNewNode`

This creates a new node in today's directory (`vault/YYYY/MM-Mmm/DD/<uuid>.md`) and automatically narrows to it.

### 3. Navigate and focus

- `<leader>nn` — Narrow to node at cursor
- `<leader>nw` — Widen from narrow view
- `<leader>nj` — Jump between narrow and context views

### 4. View context

- `<leader>ns` — Toggle sidebar (shows citations, backlinks, relations)

## Configuration

### Full configuration example

```lua
require('lifemode').setup({
  vault_path = "~/vault",  -- REQUIRED

  sidebar = {
    width_percent = 30,
    position = "right",
  },

  keymaps = {
    new_node = "<leader>nc",
    narrow = "<leader>nn",
    widen = "<leader>nw",
    jump_context = "<leader>nj",
    sidebar = "<leader>ns",
  },
})
```

### Configuration options

| Option | Default | Description |
|--------|---------|-------------|
| `vault_path` | `~/vault` | **Required.** Path to your vault directory |
| `sidebar.width_percent` | `30` | Sidebar width as percentage of window |
| `sidebar.position` | `right` | Sidebar position (`right` or `left`) |
| `keymaps.new_node` | `<leader>nc` | Create new node |
| `keymaps.narrow` | `<leader>nn` | Narrow to node |
| `keymaps.widen` | `<leader>nw` | Widen from narrow |
| `keymaps.jump_context` | `<leader>nj` | Jump between narrow and context |
| `keymaps.sidebar` | `<leader>ns` | Toggle sidebar |

## Key Concepts

### Nodes

Atomic units of thought stored as Markdown files with YAML frontmatter. Each node has:

- **UUID** — Unique identifier
- **Created date** — ISO date for chronological indexing
- **Content** — Markdown with nested outline structure
- **Metadata** — Extensible frontmatter fields

Example node file:

```markdown
---
id: a1b2c3d4-e5f6-7890-abcd-ef1234567890
created: 2026-01-22
type: note
tags: [research, pkm]
---

# Research Notes

This is the root node content.

- Child idea 1
  - Nested detail
- Child idea 2
```

### Transclusion

Embed one node inside another using `{{uuid}}` syntax:

```markdown
# Literature Review

{{a1b2c3d4-e5f6-7890-abcd-ef1234567890}}
```

The referenced node's content appears inline with visual boundaries. Supports recursive transclusion with cycle detection and depth limits.

### Citations

First-class objects with extensible schemes. Built-in support for BibTeX; add custom schemes via YAML:

```yaml
# .lifemode/citation_schemes/bible.yaml
name: bible
patterns:
  - regex: '(\w+)\s+(\d+):(\d+)'
    groups: [book, chapter, verse]
normalize: |
  function(match)
    return string.format("@bible:%s.%s.%s",
      match.book:lower(), match.chapter, match.verse)
  end
render:
  short: "[${book} ${chapter}:${verse}]"
  full: "${book} ${chapter}:${verse} (Bible)"
```

### Triple Redundancy

Node UUIDs are stored in three places for robustness and performance:

1. **Frontmatter** — Human-readable, survives file moves
2. **Extmarks** — Fast in-buffer queries
3. **SQLite index** — Vault-wide relationship queries

## Commands

| Command | Description |
|---------|-------------|
| `:LifeModeNewNode` | Create new node in today's directory |
| `:LifeModeNarrow` | Narrow to node at cursor |
| `:LifeModeWiden` | Widen from narrow view |
| `:LifeModeJumpContext` | Jump between narrow and context |
| `:LifeModeSidebar` | Toggle sidebar |
| `:LifeModeRebuildIndex` | Rebuild SQLite index from vault |

## Project Structure

LifeMode follows a clean layered architecture:

```
lifemode.nvim/
├── lua/lifemode/
│   ├── domain/          # Pure business logic (nodes, edges, citations)
│   ├── app/             # Use cases (capture, narrow, sidebar)
│   ├── infra/           # External adapters (filesystem, SQLite, Neovim)
│   └── ui/              # User interface (commands, keymaps)
├── .lifemode/           # Example vault configuration
│   ├── node_types/      # Custom node type definitions
│   ├── citation_schemes/# Custom citation schemes
│   └── sources/         # Source metadata (YAML)
└── docs/                # Architecture and spec docs
```

## Documentation

- [SPEC.md](docs/SPEC.md) — Complete product specification with BDD scenarios
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — Deep API design and implementation guidance

## Philosophy

LifeMode embodies **deep APIs** — a small, composable interface with massive expressive power. Five core operations:

1. `node()` — All node operations
2. `relate()` — All edge/relationship operations
3. `query()` — All filtering and searching
4. `render()` — All output formatting
5. `sync()` — All persistence

Small interface × wide functionality = depth. Think SQLite (3 functions, entire database), not jQuery (300 methods).

## Requirements

- Neovim ≥ 0.9.0
- SQLite3 (for indexing)

## License

MIT

## Acknowledgments

Inspired by:
- Org-mode's true narrowing and outline structure
- Roam Research's block transclusion
- TiddlyWiki's flexible transclusion
- Obsidian's graph-based thinking
