# LifeMode (Neovim) — SPEC.md

## Overview

LifeMode is a Markdown-native productivity + wiki system for Neovim, inspired by Orgmode, LogSeq, Todoist, and wikis.

**This is a greenfield project.** We start with a clean slate and build iteratively toward a working MVP.

Core promise:

- **Markdown is the source of truth.** Everything else (indexes, views, AI suggestions) is derived and disposable.
- You rarely "open a node"; you **live in views** that compile relevant nodes into an interactive buffer.
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

1. **Write** Markdown notes in a configurable vault directory
   - Inline Bible references (e.g., `John 17:20-23`, `Rom 8:28`)
   - Wikilinks to other notes `[[Page]]`, `[[Page#Heading]]`
   - Tasks with checkboxes `- [ ] Task name`
   - Citations to academic sources and articles

2. **Auto-ID** indexable blocks (tasks, referenced blocks) with stable UUIDs
   - Format: `^<uuid>` appended to line
   - Generated on-demand when block needs stable identity

3. **Navigate** with LSP-like semantics
   - `gd` follow wikilink or Bible ref to definition
   - `gr` show all references/backlinks for item under cursor
   - Jump between related notes fluidly

4. **Manage tasks** with inline priority and basic commands
   - `!1` = highest priority, `!5` = lowest priority
   - Toggle state, adjust priority, set due dates
   - View tasks filtered by state/tag/due

5. **Query and view**
   - Backlinks for current note/block
   - All tasks with filters
   - Bible verse references across vault
   - Expandable/collapsible structured views

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

Example:
```lua
require('lifemode').setup({
  vault_root = vim.fn.expand("~/notes"),
  leader = "<leader>m",
  bible_version = "NIV"
})
```

### A. Components

#### A1. Vault (filesystem)
- Root directory containing Markdown files.
- Optional “providers” for non-file corpora (e.g., Bible verses), treated as read-only node sources.

#### A2. Core Engine (recommended external process/library)
Responsibilities:
- Parse Markdown into node records (IDs, types, props, children).
- Maintain an incremental index:
  - node_id → location (file + range) or provider key
  - parent/children relationships
  - refs/backlinks (links, ranges, citations)
  - tags, types, properties, tasks
- Resolve selectors:
  - verse ranges, query results, backlinks lists, etc.
- Produce a **render plan** for a view:
  - linearized list/tree of instances + lens + spans
- Apply edits via patch operations (see “Patch Ops”).

Interface:
- JSON-RPC or msgpack-rpc over stdio or socket.
- Versioned responses (“vault revision N”) so the UI can safely re-render.

(For earliest MVP, this can be in Lua; keep boundaries so it can be moved out later.)

#### A3. Neovim Plugin (UI client)
Responsibilities:
- Manage view buffers (`buftype=nofile`, compiled content).
- Map buffer line ranges → instance/node via extmarks.
- Handle keymaps, motions, pickers, quickfix output.
- Render nodes using lens renderers:
  - base text in buffer
  - decorations via extmarks (virtual text, highlights, conceal)
- Trigger expansion/collapse (lazy).
- Edit flow:
  - commanded edits for MVP
  - optional in-view direct editing later


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
- Separate keys to cycle lenses (e.g., `<Space>ml` / `<Space>mL`).

#### D2. Active Node UX
- Active node span is visually distinct (highlight).
- Winbar/statusline shows: `type`, `node_id`, `lens`, maybe “depth”.

#### D3. Rendering mechanics
- Render to a compiled view buffer.
- Prefer decorations via extmarks over rewriting text:
  - virtual text for due dates, priority icons, backlink counts
  - highlights for task states, tags, active span

#### D4. Buffer model (compiled, virtualized)
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
IMPORTANT: We want a separate, scoped "LifeMode Leader" that is **configurable from setup()**.
- Default: `<Space>` (space key)
- Users can override in their config: `require('lifemode').setup({ leader = '<leader>m' })`
- All LifeMode commands use this leader prefix to avoid conflicting with existing keybindings

Navigation:
- `gd` go to definition (wikilink target)
- `gr` references/backlinks for target under cursor
- `gR` rename target under cursor across vault

Tasks:
- `<Space><Space>` cycle task state
- `<Space>tp` / `<Space>tP` inc/dec priority
- `<Space>tt` edit tags (picker)
- `<Space>td` set due date (prompt)

Views:
- `<Space>vv` tasks view (picker)
- `<Space>vt` tasks by tag
- `<Space>vb` backlinks for current node/page

Expansion:
- `<Space>e` expand instance under cursor
- `<Space>E` collapse instance under cursor
- `]t` / `[t` next/prev task in view buffer
- `]l` / `[l` next/prev link in view buffer

Lenses:
- `<Space>l` next lens
- `<Space>L` previous lens


## Iteration (commit-sized tasks)

Each task below should fit in ~10–1000 LOC and land as a single git commit.

**Implementation Notes:**
- Focus on the **Core MVP Loop** first (T00-T19 prioritized)
- Write tests for parsing/indexing logic; pause for manual testing at milestones
- Bible reference parsing and navigation should be treated as **core features**, not nice-to-haves
- User will signal when to pause for extensive user testing
- Keep engine boundary in mind but don't over-architect initially
- Prefer plenary.nvim and telescope.nvim for utilities and pickers

### T00 — Repo skeleton + plugin bootstrap
- Create `lua/lifemode/init.lua`, minimal `setup()` with config defaults.
- Required config: `vault_root` (must be provided by user)
- Optional config: `leader` (default `"<Space>"`), `max_depth`, `bible_version`
- Add a `:LifeModeHello` command to validate loading and show config.
- Acceptance: `:LifeModeHello` echoes config and plugin loads without errors.

### T01 — View buffer creation utility
- Implement `lifemode.view.create_buffer()`:
  - `buftype=nofile`, `swapfile=false`, `bufhidden=wipe`
- Add `:LifeModeOpen` to open an empty view buffer.
- Acceptance: buffer opens and is clearly marked as LifeMode view.

### T02 — Extmark-based span mapping
- Add an extmark namespace and helpers to attach metadata per rendered block:
  - `instance_id`, `node_id`, `lens`, `span_start/end` (initially computed)
- Acceptance: debug command prints metadata for instance under cursor.

### T03 — Minimal Markdown block parser (Lua MVP)
- Parse a Markdown file into a list of blocks (headings + list items).
- Extract:
  - task checkbox state
  - `^id` suffix if present
- Acceptance: command parses current buffer and prints block count + tasks count.

### T04 — Ensure IDs for indexable blocks
- Implement `ensure_id(block)`:
  - if no `^id`, generate UUID v4 and insert on line end
  - Format: `^550e8400-e29b-41d4-a716-446655440000`
- Only apply for task blocks initially.
- Use `vim.fn.system('uuidgen')` or pure Lua UUID generation
- Acceptance: running command adds UUIDs to tasks in file and preserves content.

### T05 — Build in-memory Node model for a single file
- Convert parsed blocks into Node records:
  - `id`, `type` (task vs text), `body_md`, `children` (basic via indentation or heading nesting)
- Acceptance: command prints node tree summary.

### T06 — Basic wikilink extraction
- Extract `[[...]]` links from node body.
- Create outbound refs list and collect backlinks map in-memory for the file.
- Acceptance: `:LifeModeRefs` shows refs for node under cursor.

### T07 — Bible reference extraction and parsing (CORE)
- Parse Bible references from markdown text:
  - `John 17:20` (single verse)
  - `John 17:18-23` (verse range)
  - `Rom 8:28` (abbreviated book names)
  - Support common abbreviations (Gen, Rom, Matt, etc.)
- Create a deterministic ID for each verse: `bible:john:17:20`
- Extract refs from node body and add to refs list
- Acceptance: command shows all Bible refs found in current file with parsed verse IDs.

### T07a — Quickfix "references" view
- Implement `gr` mapping in LifeMode view buffers:
  - find occurrences of the link/node under cursor (initially within current file)
  - populate quickfix list with locations
- Acceptance: `gr` opens quickfix with correct matches.

### T08 — "Definition" jump for wikilinks and Bible refs
- Implement `gd`:
  - resolve `[[Page]]` → open file
  - resolve `[[Page#Heading]]` → jump to heading
  - resolve `[[Page^id]]` → jump to block by id
  - resolve Bible reference (e.g., `John 17:20`) → show verse (inline or separate buffer/provider)
- Acceptance: `gd` works for all forms inside vault, including Bible references.

### T09 — Minimal task state toggle (commanded edit)
- Implement `toggle_task_state(node_id)` patch:
  - edit the checkbox `[ ]` ↔ `[x]` in source line
  - reparse file (MVP) and refresh view
- Acceptance: toggling updates file and view correctly.

### T10 — Task priority bump
- Define priority syntax: `!1` (highest) to `!5` (lowest).
- Implement `inc_priority` (toward !1) / `dec_priority` (toward !5) by editing inline marker.
- Acceptance: keymaps adjust priority and re-render decorations.

### T11 — Basic lens system + lens cycling
- Define lens registry with at least:
  - `task/brief`, `task/detail`, `node/raw`
- Implement `<Space>ml` / `<Space>mL` to change lens for active instance and re-render span.
- Acceptance: same task displays differently in brief vs detail lens.

### T12 — Active node highlighting + statusline/winbar info
- Highlight active instance span (extmark highlight).
- Populate winbar with `type`, `node_id`, `lens`.
- Acceptance: active node is unambiguous while navigating.

### T13 — Compiled view render of a page root (single file)
- Create a simple “page view”:
  - root instances are top-level nodes of current file
- Render to view buffer with extmarks for each node span.
- Acceptance: `:LifeModePageView` shows the file as a compiled interactive view.

### T14 — Expand/collapse one level (children)
- Implement expansion for instances pointing at nodes with children:
  - expand inserts rendered children lines beneath parent
  - collapse removes them
- Add cycle-safe stack tracking (minimal).
- Acceptance: expand/collapse works and does not duplicate children on repeated expand.

### T15 — Expansion budget + cycle stub
- Add max depth + max nodes per action.
- If cycle detected: render stub line “↩ already shown”.
- Acceptance: crafted cycle does not blow up buffer.

### T16 — Tag add/remove (commanded edit)
- Define tag syntax `#tag/subtag`.
- Implement add/remove tag ops (edit inline).
- Provide a simple prompt for tag string.
- Acceptance: tags update source line and view decorations.

### T17 — Due date set/clear (commanded edit)
- Define due syntax `@due(YYYY-MM-DD)`.
- Implement set/clear due ops.
- Acceptance: due date appears in task/brief lens virtual text.

### T18 — Multi-file index (vault scan MVP)
- Given a vault root, scan `.md` files and build:
  - node_id → (file, line)
  - backlinks index for wikilinks (simple)
- Acceptance: `gr` references works across files.

### T19 — Backlinks view buffer for current node/page
- Implement `:LifeModeBacklinks`:
  - show backlinks as a compiled view listing contexts/snippets
- Acceptance: backlinks list updates when files change and is navigable.

### T20 — Minimal query views for tasks
- Implement a tiny filter engine for tasks:
  - `state`, `tag`, `due`
- Add `:LifeModeTasksToday` and `:LifeModeTasksByTag <tag>`.
- Acceptance: results appear in quickfix or a view buffer.

### T21 — Productive edges (depends/blocks) parsing
- Parse property lines in a task subtree:
  - `depends:: [[...]]`
  - `blocks:: [[...]]`
- Index these as typed edges.
- Acceptance: `:LifeModeBlocked` shows tasks with open dependencies.

### T22 — Warn-on-done if blocked (non-enforcing)
- When toggling to done, if `depends::` has unfinished tasks:
  - show warning message (do not block, MVP)
- Acceptance: warning appears with a list of blockers.

### T23 — Source entities + citation mentions (MVP)
- Add `type:: source` node handling and `type:: citation` mention nodes.
- Index citations referencing `source:: [[source:...]]`.
- Acceptance: “show all citations for this source” view works.

### T24 — Provider interface (Bible provider stub)
- Define provider API:
  - `get_node(node_id)` and `expand_selector(selector)`
- Implement a stub provider with a few hardcoded verse nodes.
- Acceptance: selector expands to provider nodes and renders in view.

### T25 — Verse range selector parsing + backlinks accounting
- Parse `John 17:18-23` style text into selector.
- Ensure reference queries for a verse find range mentions (expand at query time if needed).
- Acceptance: searching references for `bible:john:17:20` includes range citations.

### T26 — External engine boundary (RPC skeleton)
- Create an engine process stub (could be Lua first, then swapped):
  - `parse_file`, `build_index`, `view_plan`, `apply_patch`
- Neovim plugin calls engine via RPC.
- Acceptance: same features work with engine calls routed over RPC.

### T27 — Incremental indexing hooks
- On `BufWritePost` and debounced `TextChanged`, update engine index for that file.
- Acceptance: backlinks/tasks views refresh without full rescan.

### T28 — Patch op: replace body (for direct in-view editing, experimental)
- Allow toggling the active span to modifiable on `i/a`.
- On exit insert, diff and send `replace_body(node_id, new_md)`.
- Acceptance: editing updates source file and re-renders span.

### T29 — Creative connection suggestions (non-AI baseline)
- Implement “suggest bridges” based on:
  - shared tags, shared backlinks neighbors, co-occurrence
- Render suggestions as a view with actions:
  - promote → insert a productive/creative link property line
  - ignore → store ignore list (optional, later)
- Acceptance: suggestions appear and can be promoted into explicit edges.

### T30 — Agent-neutral suggestion protocol (comments)
- Define comment block format:
  - `<!-- lifemode:suggest ... -->`
- Implement import/export of suggestions.
- Acceptance: external tool can append suggestions; LifeMode renders and can accept them.

