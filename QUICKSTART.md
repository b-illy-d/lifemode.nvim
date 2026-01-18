# LifeMode Quick Start Guide

This guide walks you through every feature of LifeMode. By the end, you'll be fully comfortable with the plugin.

## Prerequisites

- Neovim 0.9+
- A directory for your notes (your "vault")

## Installation

Add LifeMode to your plugin manager:

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

Run `:LifeModeHello` to verify the plugin loaded correctly. You should see your configuration printed.

## Creating a Test Vault

Let's create some sample files to explore LifeMode's features. Create a directory (e.g., `~/notes`) and add these files:

### tasks.md

```markdown
# My Tasks

## Work

- [ ] Review PR #123 !1 @due(2026-01-20) #work ^pr-review
- [ ] Write documentation !2 @due(2026-01-25) #work #docs ^write-docs
- [ ] Team sync meeting !3 #work/meetings ^team-sync
- [x] Submit timesheet #work ^timesheet

## Personal

- [ ] Buy groceries @due(2026-01-18) #personal ^groceries
- [ ] Call mom !2 #personal/family ^call-mom
- [ ] Gym workout #personal/health ^gym
```

### notes.md

```markdown
# Project Notes

## Architecture Decision

We decided to use a view-first approach. See [[tasks#Work]] for related tasks.

The key insight from [[Smith2019]] influenced this decision.

## Meeting Notes

Discussed the timeline with the team. Action items tracked in [[tasks]].
```

### bible-study.md

```markdown
# Romans Study

## Chapter 8

Key verses for understanding suffering and glory:

- Romans 8:28 - All things work together for good
- Romans 8:28-30 - The golden chain of salvation
- John 17:20-23 - Jesus prays for unity

Cross-reference with Gen 50:20 (Joseph's story).

## Devotional Thoughts

The promise in Rom 8:28 connects to the broader theme in John 3:16.
```

### sources.md

```markdown
# Sources

- [[source:Smith2019]] ^s:smith2019
  type:: source
  title:: Theological Arguments in Romans
  author:: John Smith
  year:: 2019
  kind:: book

- [[source:BlogPost2024]] ^s:blog2024
  type:: source
  title:: Understanding Grace
  author:: Jane Doe
  url:: https://example.com/grace
  kind:: blog
```

## Tutorial 1: Opening Your First View

With your vault set up, run:

```
:LifeMode
```

This opens the **Daily View**, which organizes your vault content by date:

```
2026
  January
    Jan 17 (today)
      [ ] Review PR #123 !1 @due(2026-01-20) #work
      [ ] Write documentation !2 @due(2026-01-25) #work #docs
      ...
    Jan 16
      ...
  December
    ...
2025
  ...
```

The date hierarchy uses file modification times. Today's date is automatically expanded.

### Basic Navigation

- `j`/`k` - Move up/down
- `<Space>e` - Expand the node under cursor
- `<Space>E` - Collapse the node under cursor

## Tutorial 2: Navigation

### Date Navigation

Jump quickly between dates:

| Keymap | Action |
|--------|--------|
| `]d` | Jump to next day |
| `[d` | Jump to previous day |
| `]m` | Jump to next month |
| `[m` | Jump to previous month |

### Jump to Source

When your cursor is on a task or heading:

- `gd` or `<CR>` - Open the source file at that line

This opens the actual vault file where you can edit the content. The view buffer stays available - just switch back to it.

### Backlinks

To see what references a node:

- `gr` - Opens quickfix with all backlinks

For example, with your cursor on a task that has `^pr-review`, pressing `gr` shows everywhere that ID is referenced.

## Tutorial 3: Task Management

### Task Syntax

LifeMode tasks use CommonMark checkboxes with inline metadata:

```markdown
- [ ] Task description !1 @due(2026-01-20) #tag ^id
```

| Element | Meaning |
|---------|---------|
| `- [ ]` | Uncompleted task |
| `- [x]` | Completed task |
| `!1` | Priority (1=highest, 5=lowest) |
| `@due(YYYY-MM-DD)` | Due date |
| `#tag` | Tag (supports `/` for hierarchy) |
| `^id` | Block ID (auto-assigned if missing) |

### Managing Tasks from Views

With your cursor on a task:

| Keymap | Action |
|--------|--------|
| `<Space><Space>` | Toggle state (todo ↔ done) |
| `<Space>tp` | Increase priority (!2 → !1) |
| `<Space>tP` | Decrease priority (!2 → !3) |

Changes are written directly to your vault files. The view refreshes automatically.

### Priority Rules

- `!1` is highest priority, `!5` is lowest
- Increasing priority at `!1` stays at `!1`
- Decreasing priority at `!5` removes the priority entirely
- Adding priority to a task without one starts at `!3`

## Tutorial 4: Tasks View

Open the All Tasks view:

```
:LifeMode tasks
```

This aggregates all tasks from your vault into groups:

```
Overdue (1)
  [ ] Review PR #123 !1 @due(2026-01-20) #work
Today (0)
This Week (2)
  [ ] Buy groceries @due(2026-01-18) #personal
  [ ] Write documentation !2 @due(2026-01-25) #work #docs
Later (0)
No Due Date (4)
  [ ] Team sync meeting !3 #work/meetings
  [ ] Call mom !2 #personal/family
  ...
```

### Cycling Groupings

Press `<Space>g` to cycle through grouping modes:

1. **by_due_date** (default): Overdue → Today → This Week → Later → No Due Date
2. **by_priority**: !1 → !2 → !3 → !4 → !5 → No Priority
3. **by_tag**: Groups by first tag

Within each group, tasks are sorted by priority.

## Tutorial 5: Wikilinks & Backlinks

### Creating Wikilinks

LifeMode supports standard wikilink syntax:

| Syntax | Target |
|--------|--------|
| `[[Page]]` | Links to Page.md |
| `[[Page#Heading]]` | Links to a heading in Page.md |
| `[[Page^block-id]]` | Links to a specific block by ID |

### Navigation

With your cursor on a wikilink:

- `gd` - Jump to the link target

### Finding Backlinks

With your cursor on any node:

- `gr` - Show all references to this node in quickfix

This is powerful for exploring connections. If you're on a heading and press `gr`, you'll see everywhere that heading is linked.

## Tutorial 6: Bible References

Bible references are first-class citizens in LifeMode.

### Supported Formats

```markdown
John 3:16           (single verse)
Romans 8:28-30      (verse range)
Rom 8:28            (abbreviated book)
Gen 1:1             (abbreviated)
1 Cor 13:4-7        (numbered book)
```

### Navigation

With your cursor on a Bible reference:

- `gd` - Shows the Bible Gateway URL for that verse

### Backlinks

The real power is in backlinks:

- `gr` on a Bible reference shows all notes referencing that verse

**Range expansion**: A reference like `John 17:18-23` creates backlinks for *each verse* in the range. So searching for `John 17:20` will find notes that reference `John 17:18-23`.

### Bible Verse IDs

Internally, verses use deterministic IDs:

```
bible:john:3:16
bible:romans:8:28
bible:1-corinthians:13:4
```

These enable precise cross-referencing across your vault.

## Tutorial 7: Lens System

Lenses are different ways to render the same node.

### What Are Lenses?

A task can be displayed as:
- `task/brief` - Checkbox + text + key metadata
- `task/detail` - Full metadata including all tags, properties
- `node/raw` - The raw markdown

### Cycling Lenses

With your cursor on a node:

| Keymap | Action |
|--------|--------|
| `<Space>l` | Cycle to next lens |
| `<Space>L` | Cycle to previous lens |

Try it: position on a task and press `<Space>l` to see different rendering styles.

### Available Lenses

| Lens | Node Types | Description |
|------|------------|-------------|
| `task/brief` | task | Compact task display |
| `task/detail` | task | Full metadata |
| `heading/brief` | heading | Heading text |
| `node/raw` | any | Raw markdown |
| `date/year` | date | Year display |
| `date/month` | date | Month display |
| `date/day` | date | Day display |
| `source/biblio` | source | Bibliography format |
| `citation/brief` | citation | Citation display |

## Tutorial 8: Source & Citation Nodes

For academic work or curated references, LifeMode supports source and citation nodes.

### Creating a Source

```markdown
- [[source:Smith2019]] ^s:smith2019
  type:: source
  title:: Theological Arguments in Romans
  author:: John Smith
  year:: 2019
  kind:: book
```

Properties use `key:: value` syntax on indented lines.

### Source Properties

| Property | Description |
|----------|-------------|
| `type` | Always `source` |
| `title` | Work title |
| `author` | Author name(s) |
| `year` | Publication year |
| `kind` | book, article, blog, etc. |
| `url` | URL for online sources |

### Creating Citations

Reference sources with additional context:

```markdown
- Smith argues X ^c:001
  type:: citation
  source:: [[source:Smith2019]]
  locator:: ch. 3
  pages:: 57-63
```

### Lenses for Sources

- `source/biblio` - Formatted bibliography entry
- `citation/brief` - Compact citation display

## Configuration Reference

Full configuration with all options:

```lua
require('lifemode').setup({
  vault_root = vim.fn.expand('~/notes'),
  leader = '<Space>',
  max_depth = 10,
  max_nodes_per_action = 100,
  bible_version = 'ESV',
  default_view = 'daily',
  daily_view_expanded_depth = 3,
  tasks_default_grouping = 'due_date',
  auto_index_on_startup = false,
})
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `vault_root` | string | *required* | Absolute path to vault directory |
| `leader` | string | `<Space>` | Leader key for LifeMode keymaps |
| `max_depth` | number | `10` | Maximum tree expansion depth |
| `max_nodes_per_action` | number | `100` | Node budget per expand action |
| `bible_version` | string | `ESV` | Bible version for providers |
| `default_view` | string | `daily` | View for `:LifeMode` (`daily`/`tasks`) |
| `daily_view_expanded_depth` | number | `3` | Levels to auto-expand (3=day) |
| `tasks_default_grouping` | string | `due_date` | Initial grouping mode |
| `auto_index_on_startup` | boolean | `false` | Index vault on Neovim start |

## Statusline Integration

Add LifeMode info to your statusline:

```lua
require('lifemode').get_statusline_info()
```

Returns a string like: `task [task/brief] ^abc123... d:2`

Components:
- Node type
- Current lens
- Truncated node ID
- Depth in tree

## Troubleshooting

### "vault_root is required"

You must set `vault_root` in your setup:

```lua
require('lifemode').setup({
  vault_root = vim.fn.expand('~/notes'),
})
```

### No files appear in views

- Check that your vault directory exists and contains `.md` files
- Run `:LifeModeHello` to verify your `vault_root` path
- The index builds lazily on first `:LifeMode` call

### Debug Commands

| Command | Purpose |
|---------|---------|
| `:LifeModeHello` | Show current configuration |
| `:LifeModeParse` | Parse current buffer, show block counts |
| `:LifeModeDebugSpan` | Show metadata for span under cursor |

### View not updating after file edit

The index updates automatically on `BufWritePost`. If you edit a file outside Neovim, the view won't know about changes until you save a file or reopen the view.

## Next Steps

- Explore [CONTRIBUTING.md](CONTRIBUTING.md) if you want to understand the architecture
- Read [SPEC.md](SPEC.md) for the full design specification
- Check the [README.md](README.md) for a quick reference
