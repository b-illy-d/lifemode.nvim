# LifeMode (Neovim) — SPEC.md

## Overview

LifeMode is a Markdown-native productivity + wiki system for Neovim, inspired by Orgmode, LogSeq, Todoist, and wikis.

Core promise:

- **Markdown is the source of truth.** Everything else (indexes, views, AI suggestions) is derived and disposable.
- You don't open vault files directly; you invoke **:LifeMode** from anywhere in Neovim to enter modal views that compile relevant nodes into interactive buffers.
- **:LifeMode is the primary entry point.** Views are first-class interfaces, not auxiliary to file editing. Vault files are backend storage, not primary UI.
- UX feels like an **LSP for your life**: go-to-definition for wikilinks, references/backlinks in quickfix, rename terms safely, code-actions for tasks.
- **Bible references are central** to the workflow. Notes integrate Scripture references naturally alongside academic sources and online articles.

See PHILOSOPHY.md for the core mental model (nodes, views, lenses, projects).

## Core MVP Loop

The essential workflow that must work end-to-end:

1. **Invoke** `:LifeMode` from anywhere in Neovim
   - Opens default view (Daily: nodes grouped by date)
   - View shows aggregated vault data without opening files
   - No manual indexing required

2. **Navigate** interactive views
   - Daily view: YEAR > MONTH > DAY tree, today expanded by default
   - Tasks view: grouped by due date/priority/tags
   - Project view: ordered nodes in a project
   - Expand/collapse, cycle lenses, jump to source

3. **Auto-index** runs in background
   - Index built lazily on first view open
   - Incremental updates on vault file saves
   - ID assignment automatic for new nodes
   - Date tracking uses file properties or mtime

4. **Manage content** from any view
   - Toggle task state, adjust priority, set due dates
   - Create new nodes (`:LifeModeNew`, `:LifeModeNewTask`)
   - Changes update vault files and refresh views

5. **Edit source when needed**
   - Jump from view to source file with `gd` or Enter
   - Edit markdown directly
   - Save triggers index refresh and view update


## Principles

### P1 — Markdown-first, durable, portable
- Every node is a `.md` file in the vault directory
- 1 file = 1 node (not multiple nodes per file)
- Any index/cache can be deleted and rebuilt
- `rg`/`grep` remain useful; no lock-in

### P2 — Separate truth from projection
- **Nodes are truth** (identity + content + type + metadata)
- **Views are projection** (computed queries rendered to buffers)
- **Lenses are presentation** (how a node appears in a view)

### P3 — Stable identity is non-negotiable
- Every node has a stable ID (`id::` property)
- IDs are UUIDs or slugs depending on node type
- External corpora (Bible verses) use deterministic IDs (e.g., `bible:john:17:20`)

### P4 — Lenses are deterministic, context-sensitive renderers
- Display is a pure function of: node type + props + lens name
- Lenses switchable without changing underlying node data
- Multiple lenses per node type (brief, detail, full, raw)

### P5 — Infinite expansion is lazy, bounded, cycle-safe
- Expansion happens on demand, not eagerly
- Default max depth / node budget per expansion
- Cycle detection for projects referencing projects

### P6 — Editing feels like Vim
- Active node clearly visible in view
- Structured edits (toggle state, set due) are code-actions
- Direct file editing available via jump-to-source

### P7 — Agent-neutral AI integration
- AI reads node/view context and proposes patches
- Suggestions non-destructive and promotable

### P8 — Don't weld the brain into Lua
- Keep engine (parsing/indexing) separate from UI
- Clean path to external process if needed


## Architecture

### Configuration

```lua
require('lifemode').setup({
  vault_root = vim.fn.expand("~/notes"),  -- REQUIRED
  leader = "<Space>",                      -- LifeMode leader key
  max_depth = 10,                          -- Expansion depth limit
  max_nodes_per_action = 100,              -- Expansion budget
  bible_version = "ESV",                   -- Default Bible version
  default_view = "daily",                  -- Default view type
  daily_view_expanded_depth = 3,           -- Date levels to expand
  tasks_default_grouping = "due_date",     -- Task grouping
  auto_index_on_startup = false,           -- Lazy vs eager indexing
})
```

### Components

#### Entry Points
- `:LifeMode [view]` - Open view (daily, tasks, project)
- `:LifeModeNew [type]` - Create new node
- `:LifeModeNewTask` - Create new task node

#### Vault (Filesystem)
- Root directory containing typed subfolders
- Structure: `vault/{type}s/{type}-{id}.md`
- Files use standard markdown with `key:: value` properties

#### Engine (Parsing/Indexing)
- Parse markdown files into node records
- Maintain incremental index:
  - node_id → location (file path)
  - type → nodes
  - date → nodes
  - backlinks (refs from other nodes)
- Lazy initialization, incremental updates on save

#### UI (Views)
- Modal view buffers (`buftype=nofile`)
- Map buffer lines to nodes via extmarks
- Handle keymaps, lenses, navigation


### Data Model

#### Node (1 file = 1 node)

Every node file has:
```markdown
type:: note
id:: abc123
created:: 2026-01-18
[additional properties...]

[content body]
```

Node types: `note`, `task`, `quote`, `source`, `citation`, `project`

#### View (Computed Projection)

A view combines:
- **Query**: Filter nodes (type, tags, dates, refs)
- **Grouping**: Organize results (by date, priority, project order)
- **Lens**: Render each node (brief, detail, full)

Views are NOT stored - they're dynamically generated.

#### Lens (Presentation)

Pure function: `(node, lens_name) → rendered_output`

Standard lenses:
- `brief` - Compact single-line
- `detail` - Multi-line with metadata
- `full` - Complete content
- `raw` - Markdown source


### File Formats

See PHILOSOPHY.md for detailed examples. Key formats:

**NoteNode**: General content with optional wikilinks and refs
**TaskNode**: Task line with `- [ ]`/`- [x]`, priority, due, tags, plus context
**QuoteNode**: Attribution + quoted text
**SourceNode**: Bibliography entry (title, author, year, kind)
**ProjectNode**: Ordered list of `[[node-id]]` references


### Markdown Conventions

#### Node Properties
First block of `key:: value` lines are node properties:
- `type::` - Node type (required for non-note)
- `id::` - Unique identifier
- `created::` - Creation date
- Type-specific props (author, due, priority, etc.)

#### Task Metadata (inline)
- Priority: `!1` (highest) to `!5` (lowest)
- Due: `@due(YYYY-MM-DD)`
- Tags: `#tag` or `#tag/subtag`
- State: `- [ ]` (todo) / `- [x]` (done)

#### Wikilinks
- `[[node-id]]` - Reference to another node
- `[[Page#Heading]]` - Reference with anchor
- `[[Page^block-id]]` - Block reference (legacy)

#### Bible References
- `John 17:20` (single verse)
- `John 17:18-23` (range)
- `Rom 8:28` (abbreviated)
- Treated as first-class references, same as wikilinks


### Views

#### Daily View
- **Query**: All nodes
- **Grouping**: Year > Month > Day (by created date)
- **Default lens**: `brief`
- Today expanded by default

#### Tasks View
- **Query**: `type == task`
- **Grouping**: Configurable (due_date, priority, tag)
- **Default lens**: `task/brief`
- Filter by state (todo/done)

#### Project View
- **Query**: Nodes referenced by project X
- **Grouping**: Project reference order
- **Default lens**: Varies by referenced node type
- Navigate into referenced nodes


### Keybindings (MVP)

#### Global Entry
- `:LifeMode` - Open default view
- `:LifeMode tasks` - Open tasks view
- `:LifeModeNew` - Create note node
- `:LifeModeNewTask` - Create task node

#### View Navigation
- `Enter` / `gd` - Jump to source file
- `<Space>e` / `<Space>E` - Expand/collapse
- `<Space>l` / `<Space>L` - Cycle lens
- `]d` / `[d` - Next/prev day
- `]m` / `[m` - Next/prev month

#### Task Management
- `<Space><Space>` - Toggle task state
- `<Space>tp` / `<Space>tP` - Inc/dec priority
- `<Space>tt` - Edit tags
- `<Space>td` - Set due date

#### Vault Files
- `gd` - Go to definition (wikilink/Bible ref)
- `gr` - Show references/backlinks


### Patch Operations

Structured edits against nodes:
- `toggle_task_state(node_id)`
- `set_task_state(node_id, state)`
- `inc_priority(node_id)` / `dec_priority(node_id)`
- `add_tag(node_id, tag)` / `remove_tag(node_id, tag)`
- `set_due(node_id, date)` / `clear_due(node_id)`
- `set_prop(node_id, key, value)`
- `create_node(type, props, content)` - Create new node file

All patch ops update storage and trigger index refresh.


### Testing Strategy

- Unit tests for core functions (parsing, ID generation)
- Integration tests for full loop (file → parse → index → view)
- Manual testing with real vault
- Test files in `tests/` directory
