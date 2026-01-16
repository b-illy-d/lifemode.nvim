# LifeMode (Neovim) — SPEC.md

## Overview

LifeMode is a Markdown-native productivity + wiki system for Neovim, inspired by Orgmode, LogSeq, Todoist, and wikis.

Core promise:

- **Markdown is the source of truth.** Everything else (indexes, views, AI suggestions) is derived and disposable.
- You don't open vault files directly; you invoke **:LifeMode** from anywhere in Neovim to enter modal views that compile relevant nodes into interactive buffers.
- **:LifeMode is the primary entry point.** Views are first-class interfaces, not auxiliary to file editing. Vault files are backend storage, not primary UI.
- UX feels like an **LSP for your life**: go-to-definition for wikilinks, references/backlinks in quickfix, rename terms safely, code-actions for tasks.
- The system manages **productive connections** (explicit dependencies/outputs) and helps discover **creative connections** (suggested bridges between ideas).
- **Bible references are central** to the workflow. Notes integrate Scripture references naturally alongside academic sources and online articles for both theological study and daily reflection.

Key abstractions:

- **Node**: canonical object (stable identity) containing markdown snippet + metadata, possibly with children.
- **Instance**: a placement of a node inside a view-tree; can carry local params and can also be a selector that expands to many nodes.
- **View**: what the user interacts with; a compiled tree/forest of instances rendered into a buffer, controlled by a **Lens** (renderer).

Non-goals (for MVP):

- No proprietary database required to "use" the notes.
- No assumption of a single AI vendor or agent runtime.
- No heavy GUI widgets; Neovim remains the cockpit.


## Core MVP Loop

The essential workflow that must work end-to-end before expanding features:

1. **Invoke** `:LifeMode` from anywhere in Neovim
   - Opens default view (Daily: nodes grouped by date-added)
   - View shows aggregated vault data without opening files
   - No manual indexing required

2. **Navigate** interactive views
   - Daily view: YEAR > MONTH > DAY tree, today expanded by default
   - All Tasks view: Tree grouped by due date/priority/tags
   - Expand/collapse tree nodes, cycle lenses per instance
   - Jump to source files on demand (`gd` / Enter)

3. **Auto-index** runs in background
   - Index built lazily on first view open
   - Incremental updates on vault file saves
   - ID assignment happens automatically for new tasks
   - Date tracking uses file timestamps (zero-maintenance)

4. **Manage tasks** from any view
   - Toggle state, adjust priority, set due dates
   - Changes update vault files and refresh views
   - Views re-query index automatically
   - `!1` = highest priority, `!5` = lowest priority

5. **Edit source when needed**
   - Jump from view to source file with `gd` or Enter
   - Edit markdown directly in vault
   - Save triggers index refresh and view update
   - Standard markdown remains human-readable

Everything else builds on this loop. Get this working with manual testing, then add automated tests and expand features.


## Principles

### P1 — Markdown-first, durable, portable
- Notes and tasks live as `.md` files in a vault directory.
- Any index/cache can be deleted and rebuilt.
- `rg`/`grep` must remain useful; users should not be locked into LifeMode for basic access.

### P2 — Separate truth from projection
- **Nodes are truth** (identity + content + metadata).
- **Instances are placement** (context, lens, local params, selectors).
- **Views are projection** (compiled buffers, lazily expandable).
- Never store view artifacts as “truth” unless explicitly requested.

### P3 — Stable identity is non-negotiable
- Every user-authored node that participates in linking/backlinks/tasks gets a stable ID (block/node id).
- External corpora (e.g., Bible verses) use deterministic IDs (e.g., `bible:john:17:20`).

### P4 — Lenses are deterministic, context-sensitive renderers
- Display is a pure function of:
  - node type + node props
  - view lens/mode
  - instance params (e.g., range, citation locator)
- Lenses should be switchable without changing underlying node data.

### P5 — Infinite expansion is lazy, bounded, cycle-safe
- Expansion happens on demand (cursor action), not eagerly.
- Default max depth / node budget per expansion action.
- Cycle detection in the expansion stack: render a stub for repeats instead of exploding.

### P6 — Editing should feel like Vim, not like a fragile UI
- The user clearly sees the “active node” in the view.
- `i/a` enter insert mode for the active node (or a commanded-edit mode for MVP).
- Structured edits (toggle state, set due, add tag) are code-actions that patch nodes and then re-render spans.

### P7 — Agent-neutral AI integration via a protocol
- AI is a client that reads the same node/instance/view context and proposes **patches** and **suggestions**.
- Suggestions are non-destructive and promotable into explicit edges if accepted.

### P8 — Don’t weld the brain into Lua
- Start with Neovim as UI, but keep a clean path to an external engine for parsing/indexing/querying and view planning.


## Architecture

### 0. Configuration (setup)
LifeMode is configured via `require('lifemode').setup({ ... })`:

**Required settings:**
- `vault_root`: absolute path to vault directory (e.g., `"/Users/billy/notes"`)

**Optional settings:**
- `leader`: LifeMode leader key (default: `"<Space>"`)
- `max_depth`: default expansion depth limit (default: `10`)
- `max_nodes_per_action`: expansion budget (default: `100`)
- `bible_version`: default Bible version for providers (default: `"ESV"`)
- `default_view`: default view when running `:LifeMode` (default: `"daily"`)
- `daily_view_expanded_depth`: how many date levels to expand (default: `3` = expand to day level)
- `tasks_default_grouping`: default grouping for All Tasks view (default: `"due_date"`)
- `auto_index_on_startup`: whether to build index on Neovim startup (default: `false`)

Example:
```lua
require('lifemode').setup({
  vault_root = vim.fn.expand("~/notes"),
  leader = "<leader>m",
  bible_version = "RSVCE",
  default_view = "daily",
  tasks_default_grouping = "due_date",
  auto_index_on_startup = false,
})
```

### A. Components

#### A0. Primary Entry Points

`:LifeMode [view]`
- No args: Opens default view (Daily)
- Args: `:LifeMode tasks`, `:LifeMode daily` (explicit view selection)
- Invocable from anywhere in Neovim
- View buffers are independent of vault file buffers

#### A1. Vault (filesystem)
- **Storage backend**, not primary interface
- Root directory containing Markdown files
- Files use standard markdown - no lock-in
- Views read from vault via index, not direct file editing
- Optional "providers" for non-file corpora (e.g., Bible verses), treated as read-only node sources

#### A2. Core Engine (recommended external process/library)
Responsibilities:
- Parse Markdown into node records (IDs, types, props, children).
- Maintain an incremental index:
  - node_id → location (file + range) or provider key
  - parent/children relationships
  - refs/backlinks (links, ranges, citations)
  - tags, types, properties, tasks
  - **file timestamps** (mtime) for date tracking
- Resolve selectors:
  - verse ranges, query results, backlinks lists, etc.
- Produce a **render plan** for a view:
  - linearized list/tree of instances + lens + spans
- Apply edits via patch operations (see "Patch Ops").

**Automatic Indexing Strategy:**
- **Lazy initialization**: Build index on first `:LifeMode` invocation
- **Incremental updates**: On `BufWritePost` for files in vault_root
- **File watching** (optional future): Watch vault directory for external changes
- **Index data includes**: node locations, backlinks, task metadata, **file timestamps**

**Index data structures:**
```lua
{
  node_locations = { [node_id] = { file, line, mtime } },
  backlinks = { [target] = { source_ids } },
  tasks_by_state = { todo = {...}, done = {...} },
  nodes_by_date = { ["2026-01-15"] = { node_ids } }
}
```

Interface:
- JSON-RPC or msgpack-rpc over stdio or socket.
- Versioned responses ("vault revision N") so the UI can safely re-render.

(For earliest MVP, this can be in Lua; keep boundaries so it can be moved out later.)

#### A3. Neovim Plugin (UI client)
Responsibilities (view-first design):

1. **Manage modal view buffers** (primary UX)
   - Daily view: Date-based tree navigation
   - All Tasks view: Configurable grouping/filtering
   - Backlinks view: Reference exploration

2. **Handle view interactions**
   - Expand/collapse tree nodes
   - Cycle lenses per instance
   - Jump to source files on demand

3. **Trigger index updates**
   - Build index lazily on first view open
   - Incremental rebuild on vault file saves
   - Refresh views when index changes

4. **Edit vault files** (secondary workflow)
   - Jump from view to source with `gd` / Enter
   - Standard markdown editing
   - Save triggers index refresh

Technical implementation:
- View buffers: `buftype=nofile`, compiled content
- Map buffer line ranges → instance/node via extmarks
- Handle keymaps, motions, pickers, quickfix output
- Render nodes using lens renderers (text + decorations via extmarks)
- Edit flow: commanded edits for MVP, optional in-view direct editing later


### B. Data Model

#### B1. Node
Minimum fields (internal model):
- `id: string`
- `type: string` (e.g., `task`, `event`, `source`, `verse`, `text`)
- `props: map<string, string | string[]>`
- `body_md: string` (markdown snippet for this node)
- `children: string[]` (node IDs in tree order; may be empty)
- `refs: Ref[]` (outbound references extracted from body/properties)

Notes:
- Nodes may originate from:
  - Markdown block in file
  - Provider (Bible verse)
  - (Later) synthetic nodes persisted by user choice

#### B2. Instance
An appearance/placement of a node in a view:
- `instance_id: string` (unique within view)
- `target_id: string | null` (canonical node id; null for purely synthetic group nodes)
- `selector: Selector | null` (range/query/backlinks selector that expands to many target nodes)
- `lens: string` (renderer choice, e.g., `task/brief`, `task/detail`)
- `params: map<string, any>` (local display/behavior params: collapsed, locator, range endpoints)
- `depth: number`

#### B3. View
A compiled interactive projection:
- `view_id: string`
- `root_instances: Instance[]`
- `lens_mode: string` (default lens family for the view)
- `options: map` (max_depth, budgets, grouping rules, etc.)

#### B4. Edges (references/connections)
- **Reference edge**: “A mentions B” via wikilinks/block refs.
- **Productive edge** (explicit): typed dependencies, blockers, outputs.
- **Creative edge** (suggested): candidate bridges; non-binding until promoted.

Productive vs creative:
- Manage productive connections: explicit, queryable, actionable.
- Discover creative connections: suggested, non-destructive, promotable.


### C. Markdown Conventions (MVP-friendly)

#### C1. Node IDs
- For user-authored blocks: append `^<id>` at end of the block line.
  - Example: `- [ ] Write spec ^550e8400-e29b-41d4-a716-446655440000`
- ID format: **UUID (UUID v4)** for stable, globally unique identifiers.
  - Compact representation recommended for readability (no optional prefixes in MVP; type inferred from content).
- Insert IDs automatically when a block becomes "indexable" (task, has link, referenced, etc.).

#### C2. Wikilinks
Support:
- `[[Page]]`
- `[[Page#Heading]]`
- `[[Page^block-id]]` (block reference)

Definition for “go-to”:
- Page resolves to file.
- Heading resolves to heading node within file.
- Block-id resolves to exact node by ID.

#### C3. Tasks
Use CommonMark-style task list items:
- `- [ ] ...` (todo)
- `- [x] ...` (done)

Add lightweight inline metadata:
- priority: `!1` (highest priority) to `!5` (lowest priority)
- due: `@due(YYYY-MM-DD)`
- tags: `#tag/subtag`

Optional property lines (LogSeq-style) within the block subtree:
```md
- [ ] Implement indexer !2 @due(2026-02-01) #lifemode ^t:indexer
  depends:: [[Task/Parser]] [[Task/RPC]]
  outputs:: [[Spec/LifeMode MVP]]
```

#### C4. Types and properties
Prefer per-node properties over file frontmatter:
- `type:: source`
- `author:: ...`
- `locator:: ch. 3`
Frontmatter reserved for page-level defaults only.

#### C5. Sources and citations (entity vs mention)
The user references multiple types of external works:
- Academic books and journal articles
- Blog posts and online articles
- News articles and web resources
- Conference papers and lectures

Distinction:
- **Source node (entity)**: represents the work itself (book/article/post/etc.)
- **Citation node (mention)**: represents a specific usage/reference with local parameters

Example:
```md
- [[source:Smith2019]] ^s:smith2019
  type:: source
  title:: Theological Arguments in Romans
  author:: John Smith
  year:: 2019
  kind:: book

- [[source:DesiringGodPost2024]] ^s:dg2024
  type:: source
  title:: Five Reasons to Rejoice in Suffering
  author:: John Piper
  url:: https://www.desiringgod.org/articles/...
  kind:: blog

- Smith argues X in his commentary. ^c:001
  type:: citation
  source:: [[source:Smith2019]]
  locator:: ch. 3
  pages:: 57-63
```

This allows proper bibliography management while keeping notes clean.

#### C6. Bible verses and ranges (CORE WORKFLOW)
Bible references are **central to daily note-taking and study**. The user's vault will be full of Scripture references for:
- Academic biblical/theological study
- Sermon notes and devotional reflections
- Cross-referencing theological concepts
- Daily journaling with scriptural meditation

**Reference formats supported:**
- `John 17:20` (single verse)
- `John 17:18-23` (range)
- `Rom 8:28` (abbreviated book names)
- Multiple refs: `Gen 1:1; John 3:16; Rev 22:21`

**Implementation:**
- Verse nodes use deterministic IDs (provider-backed): `bible:john:17:20`
- Range reference is a selector instance (not a canonical node by default): `John 17:18-23` expands to verse node IDs.
- Index rule (required): A range mention must count as a reference to **each verse in the range** (either expanded at index time or query time).

**Navigation:**
- `gd` on a verse reference opens the verse (inline expansion or jump to provider view)
- `gr` on a verse shows all notes that reference this verse (critical for cross-study)

Treat Bible references with the same first-class status as wikilinks. They are not an add-on feature.


### C7. View Types (Core UX)

- LifeMode provides views, user's configured default is invoked via `:LifeMode`:
- View can be changed by invoking a different view command
- New views can be added

#### Daily View (Default)
**Purpose**: Browse vault chronologically by date-added

**Structure**: Three-level tree (Year > Month > Day)

**Default state**: Today's date expanded, siblings collapsed

**Node display**: All nodes added on each date (tasks, notes, headings)

**Date tracking**: File modification timestamp (mtime) by default

**Navigation**: Expand/collapse dates, lens cycling per node

**Keymaps**:
- `Enter` / `gd`: Jump to source file at node location
- `<Space>e/E`: Expand/collapse date grouping
- `]d / [d`: Next/previous day
- `]m / [m`: Next/previous month

**Example tree:**
```
2026
  January
    Jan 15 (today)
      - [ ] Finish spec restructure !2 @due(2026-01-16) ^abc123
      # Meeting Notes ^def456
      - Study Romans 8 ^ghi789
  December
    Dec 31
      ...
2025
  ...
```

#### All Tasks View
**Purpose**: Browse all tasks across vault with filtering

**Structure**: Tree grouped by configurable property

**Grouping modes**:
- By due date: Overdue / Today / This Week / Later / No Due Date
- By priority: !1 (highest) → !5 (lowest) → No Priority
- By tag: Group by first tag (e.g., #project, #personal)

**Filtering**: Toggle filters (state: todo/done, tag, date range)

**Sorting**: Within groups, sort by priority or due date

**Keymaps**:
- `Enter` / `gd`: Jump to source file at task location
- `<Space><Space>`: Toggle task state
- `<Space>g`: Cycle grouping mode
- `<Space>f`: Toggle filters

**Example tree (grouped by due date):**
```
Overdue (3)
  - [ ] Review PR #123 !1 @due(2026-01-10) ^task1
  - [ ] Submit report !2 @due(2026-01-14) ^task2
Today (2)
  - [ ] Team standup !1 @due(2026-01-16) ^task3
  - [ ] Code review !3 @due(2026-01-16) ^task4
This Week (5)
  ...
No Due Date (12)
  ...
```


### D. Views, Lenses, and Rendering

#### D1. Lenses
A lens is a named renderer:
- `task/brief`: state + title + due + priority summary
- `task/detail`: full metadata (tags, due, recurrence, blockers, outputs), editable
- `source/biblio`: formatted citation
- `verse/citation`: grouped verse text with verse numbers
- `node/raw`: raw markdown snippet for a node

Lens switching:
- Keep `i/a` as normal Vim insert for the active node.
- Separate keys to cycle lenses (e.g., `<Space>l` / `<Space>L`).

#### D2. Active Node UX
- Active node span is visually distinct (highlight).
- Winbar/statusline shows: `type`, `node_id`, `lens`, maybe “depth”.

#### D3. Rendering mechanics
- Render to a compiled view buffer.
- Prefer decorations via extmarks over rewriting text:
  - virtual text for due dates, priority icons, backlink counts
  - highlights for task states, tags, active span

#### D4. Buffer model (compiled, virtualized)

**View Buffer Types:**

**Modal View Buffers** (invoked via `:LifeMode`):
- Independent of source file buffers
- Show aggregated vault data (not single-file)
- Examples: Daily view, All Tasks view
- Can be opened from anywhere in Neovim

**Page View Buffers** (invoked via `gd` from modal views):
- Show compiled single-file content
- Used when jumping to source from modal view
- Fallback: Open source file directly if page view unavailable

**Technical details:**
- View buffers are typically `nofile` and largely read-only.
- Every rendered block gets an extmark with:
  - `instance_id`, `node_id` (or selector)
  - `depth`, `lens`
  - `span_start`, `span_end` (line range)
  - `collapsed` state

Expand/collapse:
- Expand at cursor: resolve instance → children or selector expansion → insert rendered lines below.
- Collapse: delete span lines and mark collapsed.

Safety:
- Cycle detection on node-id stack during expansion.
- Expansion budget: max depth + max nodes per action.

Editing modes:
- MVP: commanded edits (toggle state, set due, add tag) applied via patch ops and span re-render.
- Later: direct in-span editing with diff → patch → re-render.

#### D5. Navigation semantics (LSP-like)
- Definition: open target of wikilink (page/heading/block).
- References: list all occurrences/backlinks for node/link in quickfix/location list.
- Rename: rename a page/term and update links safely (bounded by vault scope).
- Code actions: task state cycling, priority bump, edit tags, add dependencies, etc.


### E. Query/View System (MVP)
- Provide a minimal query filter language for tasks/links/sources:
  - `due:today`
  - `tag:#lifemode state:todo`
  - `blocked:true`
  - `link:[[John 17:20]]`
- Views render results into quickfix or a view buffer.
- Named views can be stored as comments or properties for later reuse.

(Exact DSL can evolve; MVP can hardcode a few common views.)


### F. Patch Ops (engine-facing editing API)
Edits should be structured operations against canonical nodes, not “random text mutation”.

Minimum patch operations:
- `toggle_task_state(node_id)`
- `set_task_state(node_id, state)`
- `inc_priority(node_id)` / `dec_priority(node_id)`
- `add_tag(node_id, tag)` / `remove_tag(node_id, tag)`
- `set_due(node_id, date)` / `clear_due(node_id)`
- `set_prop(node_id, key, value)`
- `replace_body(node_id, new_markdown)` (later, for direct editing)
- `ensure_id(node_location)` (insert IDs when missing)

All patch ops should:
- update storage (file edit or provider error)
- bump vault revision
- trigger index update for affected files/nodes


### G. Dependencies
For MVP, we can leverage well-tested Neovim ecosystem libraries:

**Recommended:**
- **plenary.nvim**: async/job control, functional utilities, testing framework
- **telescope.nvim**: fuzzy finder for tags, tasks, files, Bible verse pickers
- **nvim-treesitter** (optional): enhanced Markdown parsing if needed

Keep dependencies minimal and only add when they solve a real problem. Don't over-engineer.

### H. Testing Strategy
- Write **unit tests** for core functions (parsing, ID generation, selector expansion) using plenary.nvim test harness
- Write **integration tests** for the full loop (file → parse → index → query → render)
- **Manual testing** is primary for MVP:
  - Use real vault with Bible study notes
  - Validate navigation, task management, backlinks work end-to-end
- Pause for user testing at key milestones (after T08, T14, T19)
- Add tests incrementally; don't block progress on 100% coverage

Test file structure:
```
tests/
  lifemode/
    parser_spec.lua
    index_spec.lua
    view_spec.lua
```

### I. Engine Boundary (Don't Over-Architect)
Per P8 ("Don't weld the brain into Lua"):
- Keep parsing/indexing/query logic in separate modules from UI code
- Use clear function boundaries: `parse_file()`, `build_index()`, `apply_patch()`
- Start with **pure Lua implementation** in `lua/lifemode/engine/`
- Avoid premature abstraction for RPC/external process until proven necessary
- When/if we externalize:
  - The same function signatures become RPC calls
  - No UI code needs to change

This keeps the door open without over-engineering up front. Let the code tell us when it's time to split.

### J. Keybinding Guidelines (MVP defaults)
IMPORTANT: below is the current state, but this will change in the future
IMPORTANT: We want a separate, scoped "LifeMode Leader" that is **configurable from setup()**.
- Default: `<Space>` (space key)
- Users can override in their config: `require('lifemode').setup({ leader = '<leader>m' })`
- All LifeMode commands use this leader prefix to avoid conflicting with existing keybindings

#### Global Entry Points (from anywhere)
- `:LifeMode`: Open default view (Daily)
- `:LifeMode tasks`: Open All Tasks view
- `:LifeMode daily`: Open Daily view explicitly

#### Modal View Keymaps (LifeMode view buffers)
- `Enter` / `gd`: Jump to source file
- `<Space>e` / `<Space>E`: Expand/collapse tree node
- `<Space>l` / `<Space>L`: Cycle lens for active instance
- `]d` / `[d`: Navigate dates (Daily view)
- `]m` / `[m`: Navigate months (Daily view)
- `<Space>g`: Cycle grouping mode (All Tasks view)
- `<Space>f`: Toggle filters (All Tasks view)

#### Task Management (from any view or vault file)
- `<Space><Space>`: Cycle task state
- `<Space>tp` / `<Space>tP`: Inc/dec priority
- `<Space>tt`: Edit tags
- `<Space>td`: Set due date
- `<Space>te`: Edit task details (open task file)

#### Vault File Keymaps (when editing .md files in vault)
- `gd`: Go to definition (wikilink/Bible ref)
- `gr`: Show references/backlinks
- `gR`: Rename target across vault
- `<Space>mi`: Insert node inclusion
- Standard task management keymaps (above)


