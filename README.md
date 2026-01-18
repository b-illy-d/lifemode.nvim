# lifemode.nvim

A Markdown-native productivity and wiki system for Neovim, inspired by Orgmode, LogSeq, Todoist, and wikis.

## What is LifeMode?

- **1 file = 1 node**: Each markdown file is exactly one node (task, note, quote, project, etc.) with explicit `type::`, `id::`, and `created::` properties.
- **View-first**: You don't edit vault files directly. You invoke `:LifeMode` to open interactive views that compile relevant nodes into navigable buffers.
- **Markdown is truth**: Your notes are plain `.md` files organized in type folders. No proprietary database. `grep` always works.
- **Projects**: Meta-nodes that reference other nodes in a specific order - perfect for sermons, research papers, or any composed work.
- **Bible-aware**: Scripture references are first-class citizens with full backlink support.
- **LSP-like UX**: `gd` for go-to-definition, `gr` for references/backlinks, code actions for task management.

## Features

- **Daily View**: Browse your vault chronologically (Year > Month > Day tree)
- **Tasks View**: Aggregate all tasks with grouping by due date, priority, or tag
- **Project View**: Render projects with their referenced nodes in order
- **Task management**: Toggle state, adjust priority (!1-!5), set due dates, add tags
- **Wikilinks**: `[[node-id]]` syntax to link between nodes with navigation
- **Bible references**: `John 3:16`, `Rom 8:28-30` with backlinks for each verse
- **Lens system**: Cycle between rendering styles per node (`task/brief`, `node/full`, etc.)
- **Auto-indexing**: Lazy build on first use, incremental updates on file save

## Installation

### lazy.nvim

```lua
{
  'billy/lifemode.nvim',
  config = function()
    require('lifemode').setup({
      vault_root = vim.fn.expand('~/notes'),
    })
  end,
}
```

### packer.nvim

```lua
use {
  'billy/lifemode.nvim',
  config = function()
    require('lifemode').setup({
      vault_root = vim.fn.expand('~/notes'),
    })
  end,
}
```

## Quick Start

1. Point `vault_root` at your notes directory
2. Run `:LifeMode` to open the Daily view
3. Navigate with `j`/`k`, expand with `<Space>e`, jump to source with `gd`

See [TUTORIAL.md](TUTORIAL.md) for a full tutorial.

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `vault_root` | *required* | Absolute path to your vault directory |
| `leader` | `<Space>` | LifeMode leader key for keymaps |
| `max_depth` | `10` | Default expansion depth limit |
| `max_nodes_per_action` | `100` | Expansion budget per action |
| `bible_version` | `ESV` | Default Bible version for providers |
| `default_view` | `daily` | View to open with `:LifeMode` (`daily` or `tasks`) |
| `daily_view_expanded_depth` | `3` | Date levels to expand (3 = day level) |
| `tasks_default_grouping` | `due_date` | Default grouping (`due_date`, `priority`, `tag`) |
| `auto_index_on_startup` | `false` | Build index when Neovim starts |

```lua
require('lifemode').setup({
  vault_root = vim.fn.expand('~/notes'),
  leader = '<Space>',
  bible_version = 'ESV',
  default_view = 'daily',
  daily_view_expanded_depth = 3,
  tasks_default_grouping = 'due_date',
})
```

## Keymaps

These keymaps are active in LifeMode view buffers:

| Keymap | Action |
|--------|--------|
| `gd` / `<CR>` | Jump to source file |
| `gr` | Show backlinks in quickfix |
| `<Space>e` | Expand tree node |
| `<Space>E` | Collapse tree node |
| `]d` / `[d` | Jump to next/previous day |
| `]m` / `[m` | Jump to next/previous month |
| `<Space><Space>` | Toggle task state (todo/done) |
| `<Space>tp` | Increase task priority |
| `<Space>tP` | Decrease task priority |
| `<Space>g` | Cycle task grouping (Tasks view) |
| `<Space>l` / `<Space>L` | Cycle lens forward/backward |
| `o` | Create new node below cursor |
| `i` | Edit node inline |
| `a` | Edit node inline (append) |
| `q` | Close view buffer |

## Commands

| Command | Description |
|---------|-------------|
| `:LifeMode` | Open default view (Daily) |
| `:LifeMode daily` | Open Daily view |
| `:LifeMode tasks` | Open All Tasks view |
| `:LifeModeHello` | Validate plugin and show config |
| `:LifeModeParse` | Parse current buffer (debug) |
| `:LifeModeDebugSpan` | Show metadata at cursor (debug) |

## Node Format

Each node is a single file with LogSeq-style properties:

```markdown
type:: task
id:: abc123
created:: 2026-01-15

- [ ] Review PR !1 @due(2026-01-20) #work
```

### Task Metadata

Tasks use CommonMark checkbox syntax with inline metadata:

- **Priority**: `!1` (highest) through `!5` (lowest)
- **Due date**: `@due(YYYY-MM-DD)`
- **Tags**: `#tag` or `#tag/subtag`

### Node Types

| Type | Storage | Purpose |
|------|---------|---------|
| `note` | `notes/` | General notes, thoughts |
| `task` | `tasks/` | Actionable items |
| `quote` | `quotes/` | Quotations |
| `source` | `sources/` | Books, articles |
| `project` | `projects/` | Ordered node references |

## Documentation

- [PHILOSOPHY.md](PHILOSOPHY.md) - Core mental model (nodes, views, lenses, projects)
- [TUTORIAL.md](TUTORIAL.md) - Hands-on tutorial
- [CONTRIBUTING.md](CONTRIBUTING.md) - Architecture and development guide
- [SPEC.md](SPEC.md) - Design specification

## License

MIT
