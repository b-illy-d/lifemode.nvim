# LifeMode (Neovim) — Product Spec (Architect Draft)

**Status:** Implementation-ready specification with BDD scenarios, visual specs, and resolved design decisions.

---

## Table of Contents

### Core Specification
- [0. Purpose](#0-purpose)
- [1. Vault Layout](#1-vault-layout)
  - [1.1 Primary capture storage (daily directories)](#11-primary-capture-storage-daily-directories)
  - [1.2 Node file format](#12-node-file-format)
  - [1.3 Optional organization](#13-optional-organization)
  - [1.4 `.lifemode/` directory](#14-lifemode-directory)
- [2. Principles](#2-principles)
- [3. Core Data Model](#3-core-data-model)
  - [3.1 Node](#31-node)
  - [3.2 Relationships](#32-relationships)
  - [3.3 Citations](#33-citations)
  - [3.4 Dates](#34-dates)
  - [3.5 Sources](#35-sources)
- [4. UX & Interaction](#4-ux--interaction)
  - [4.1 Capture (daily directory + narrow)](#41-capture-daily-directory--narrow)
  - [4.2 Focus & Navigation](#42-focus--navigation)
  - [4.3 Side Window (passive, accordion)](#43-side-window-passive-accordion)
  - [4.4 Slash Commands](#44-slash-commands)
  - [4.5 Visual Feedback Patterns](#45-visual-feedback-patterns) ⭐
- [5. Transclusion & Backlinks](#5-transclusion--backlinks)
  - [5.1 Transclusion](#51-transclusion)
  - [5.2 Backlinks](#52-backlinks)
  - [5.3 Transclusion UX (no manual IDs)](#53-transclusion-ux-no-manual-ids)
  - [5.4 Transclusion Rendering States](#54-transclusion-rendering-states) ⭐
- [6. Typing, Rendering, Export](#6-typing-rendering-export)
  - [6.1 Inference-first typing](#61-inference-first-typing)
  - [6.2 User-defined node types](#62-user-defined-node-types)
  - [6.3 Projects (LaTeX-shaped)](#63-projects-latex-shaped)
  - [6.4 Typed rendering](#64-typed-rendering)
- [7. Indexing & Storage](#7-indexing--storage)
  - [7.1 SQLite graph/index](#71-sqlite-graphindex)
  - [7.2 Derived contexts (automatic indexes)](#72-derived-contexts-automatic-indexes)
- [8. Org-mode Influences](#8-org-mode-influences)
- [9. Error Handling & Resilience](#9-error-handling--resilience)
  - [9.1 Malformed Frontmatter](#91-malformed-frontmatter)
  - [9.2 Index Corruption](#92-index-corruption)
  - [9.3 User-Facing Error Messages](#93-user-facing-error-messages)

### BDD Scenarios ⭐
- [10. BDD Scenarios](#10-bdd-scenarios)
  - [10.1 Capture Workflow](#101-capture-workflow)
  - [10.2 Navigation & Focus](#102-navigation--focus)
  - [10.3 Transclusion & References](#103-transclusion--references)
  - [10.4 Side Window Interactions](#104-side-window-interactions)

### Appendices
- [Appendix A: Resolved Design Decisions](#appendix-a-resolved-design-decisions) ⭐
  - [Decision A.1: Node UUID Persistence](#decision-a1-node-uuid-persistence)
  - [Decision A.2: Citation Scheme DSL](#decision-a2-citation-scheme-dsl)
  - [Decision A.3: BibTeX UX & Source Management](#decision-a3-bibtex-ux--source-management)
  - [Decision A.4: View/Query DSL Syntax](#decision-a4-viewquery-dsl-syntax)
  - [Decision A.5: Creative-Relation Discovery](#decision-a5-creative-relation-discovery)
- [Appendix B: Visual State Reference](#appendix-b-visual-state-reference) ⭐
  - [B.1 Highlight Groups Catalog](#b1-highlight-groups-catalog)
  - [B.2 Gutter Signs Reference](#b2-gutter-signs-reference)
  - [B.3 Buffer State Transitions](#b3-buffer-state-transitions)
  - [B.4 Sidebar Update Flow](#b4-sidebar-update-flow)
  - [B.5 Transclusion Rendering States](#b5-transclusion-rendering-states)
  - [B.6 Citation Rendering Pipeline](#b6-citation-rendering-pipeline)
  - [B.7 Keybinding Quick Reference](#b7-keybinding-quick-reference)
  - [B.8 Configuration Schema](#b8-configuration-schema)

**Legend:** ⭐ = New sections added in this audit

---

## 0. Purpose
A Neovim-first “Personal Research OS” for capturing, organizing, and **discovering creative relations** among information—especially across sources—while treating **citations as first-class**.

## 1. Vault Layout
A LifeMode vault is a directory containing arbitrarily organized `.md` files plus a `.lifemode/` directory.

### 1.1 Primary capture storage (daily directories)
- Capture creates **one file per new root node**.
- Files are stored by creation date:
  - `vault/YYYY/MM-Mmm/DD/<uuid>.md`
  - example: `2026/01-Jan/21/3f2c9c6b-....md`
- Co-presence in the same day directory is a weak signal of relationship; it is only a default chronological grouping.

### 1.2 Node file format
Each node file contains:
- YAML frontmatter (metadata)
- a single **root node** rendered as an outline with nested children (Markdown bullets)

Frontmatter includes at minimum:
- `id` (UUID)
- `created` (ISO date, used for date-node linking)
- `type` (optional / inferred)
- additional type-specific metadata (extensible)

### 1.3 Optional organization
- `projects/<name>/...` (articles/books/series workspaces)
- Arbitrary folders are allowed; LifeMode indexes across the whole vault.

### 1.4 `.lifemode/` directory
- `.lifemode/` contains configuration and indexes:
  - `node_types/` (Lua or YAML)
  - `citation_schemes/` (Lua or YAML)
  - `views/` (future: view-as-file definitions)
  - `sources/` (YAML source objects; source-of-truth)
  - `bib/` (generated `.bib` files)
  - `index.sqlite` (persisted graph/index; portable cache)

## 2. Principles
- Keyboard-centric (Neovim native)
- **Flat UI**: minimal modes, minimal panes, minimal chrome
- Zero-decision capture (content first, placement later)
- **Graph-first**: relationships are primary; hierarchy is local context only
- **True narrowing**: any node’s subtree can temporarily become the whole buffer
- Ambiguity preserved: no mandatory refiling; “inbox” is implicit/virtual
- System supports (but does not dictate) synthesis:
  - accuse: reading without integrating / citing without thinking / circling without concluding
  - discover: via traversal and views, not editorial conclusions

## 3. Core Data Model
### 3.1 Node
- Atomic unit of thought.
- **One file per root node**; the file contains the root node plus nested children.
- Nesting (indentation) encodes local structure and layered marginalia as sibling/child nodes.

#### 3.1.1 Node identity
- Node identity is the UUID (`id`) stored in frontmatter.
- Filename may also be the UUID for durability and portability.
- Users never type IDs; LifeMode inserts references via search.

**UUID Storage Mechanism (clarified):**
- Triple redundancy approach:
  1. **Frontmatter**: Persistent in file, human-readable
  2. **Extmarks**: Buffer-local tracking with namespace for fast in-buffer queries
  3. **Index (SQLite)**: Vault-wide queries and relationship traversal
- Extmarks attached to frontmatter line with `id` metadata
- On buffer load: parse frontmatter → create extmark → verify against index
- On save: update index if UUID or boundaries changed

### 3.2 Relationships
- **Productive**: A is necessary for B (often defined; sometimes discovered).
- **Creative**: A and B together are necessary for C (often discovered; sometimes defined).
- Relationships are bidirectional and queryable.

### 3.3 Citations
- First-class objects.
- Must support canonical IDs including non-traditional schemes (Bible, Summa, Spiritual Exercises, etc.).
- Citation normalization + rendering is **user-configurable** via scheme definitions:
  - parsers/normalizers (e.g., `John 6:35` → `@bible:John.6.35`)
  - renderers (short / one-line / full)

### 3.4 Dates
- Dates are **real nodes**.
- Each node file has `created: YYYY-MM-DD` in frontmatter.
- LifeMode materializes date nodes (e.g. `@date:2026-01-21`) from `created` and uses them for:
  - default chronological tree view
  - linking/transclusion/querying like any other node

### 3.5 Sources (bibliographic objects) (bibliographic objects)
- Source-of-truth is YAML (or similar) under `.lifemode/sources/<key>.yaml`.
- LifeMode generates `.bib` under `.lifemode/bib/` (or `bibliography/`) from source objects.
- UX goal: `gd` (or slash command) on a cite/source jumps to the source object by default; optional jump to `.bib` entry.

## 4. UX & Interaction
### 4.1 Capture (daily directory + narrow)
Command: `LifeModeNewNode`
1) compute today's directory: `YYYY/MM-Mmm/DD/` (create if missing)
2) create a new node file: `<uuid>.md`
3) write frontmatter (`id`, `created`, optional `type`)
4) open the file and **narrow** to the root subtree (effectively: the file is the node)

Rationale: capture must show only the node being written; chronology is stored without implying semantic relation.

**Date Directory Creation (clarified):**
- Directories created lazily on first node capture for that date
- Nested creation: `mkdir -p` behavior (create year, month, day as needed)
- Month format: `MM-Mmm` (e.g., `01-Jan`, `12-Dec`) for sortability + readability
- If vault root doesn't exist: error with clear message, don't auto-create vault
- Permission errors: surface immediately with full path in error message

### 4.2 Focus & Navigation
- True narrowing is the primary focus mechanic.
- Jump actions should always exist to:
  - jump to node in original context
  - jump to node in narrowed view
  - jump "through" relations (backlinks/transclusions)

**Narrowing UX (clarified):**
- `<leader>nn` — Narrow to node at cursor (subtree becomes entire buffer view)
- `<leader>nw` — Widen from narrow (restore original buffer context)
- `<leader>nj` — Jump between narrow and context views
- Implementation:
  - Store original buffer, node UUID, cursor position in buffer-local vars
  - Create temporary scratch buffer with narrowed content
  - Maintain extmark sync between narrow and source buffers
  - On widen: restore original buffer and cursor position
- Exit conditions: explicit widen, buffer switch with warning, or save (commits to source)

### 4.3 Side Window (passive, accordion)
- Updates on **node change** (not every cursor move).
- Accordion sections:
  1) Context (themes, inferred type, key properties)
  2) Citations (in-node; other nodes citing same sources)
  3) Relations (backlinks/transclusions; creative traversal affordances)
- Quick actions: jump, narrow, transclude, manage source, embed view

**Side Window Update Trigger (clarified):**
- "Node change" means: cursor moved to a different node UUID
- Implementation via autocommand on `CursorHold` (debounced):
  - Query extmark at cursor position for node UUID
  - Compare to last-rendered UUID
  - If different: query index for new node context, re-render accordion
  - If same: no-op
- Only active in LifeMode-managed buffers (file in vault)
- Toggle: `<leader>ns` to show/hide side window

### 4.4 Slash Commands
- Unified slash-command palette to avoid keybinding explosion.
- Must cover:
  - insert/transclude
  - change/infer type
  - attach/normalize citations
  - embed views
  - manage sources (jump/edit)

**Slash Command Implementation (clarified):**
- Trigger: Type `/` in insert mode within a LifeMode buffer
- UI: Floating window with fuzzy-searchable command list (use `vim.ui.select` or telescope)
- Command registry structure:
  ```lua
  {
    name = "transclude",
    description = "Insert transclusion of another node",
    handler = function(ctx) ... end,
    context_filter = function(ctx) return ctx.in_node end
  }
  ```
- After selecting command: may spawn secondary picker (e.g., node search for transclusion)
- Insert result at cursor position, update extmarks/index as needed
- User-extensible via config: `config.slash_commands = { ... }`

### 4.5 Visual Feedback Patterns

#### 4.5.1 Narrowing States

**Normal View:**
- All nodes visible in buffer
- Standard Markdown highlighting (no special markers)
- Statusline: default appearance
- Window borders: standard gray

**Narrowed View:**
- Scratch buffer name: `*Narrow: <node-title>*`
- Content: only target node's subtree visible (root + children)
- Statusline: `[NARROW: <node-title>]` with custom highlight group `LifeModeNarrowStatus`
- Window border: cyan (#5fd7ff) vs standard gray
- Virtual text at top of buffer: `↑ Context hidden. <leader>nw to widen` (dim gray, highlight group `LifeModeNarrowHint`)
- Buffer marked as scratch (not file-backed during narrowing)

**Jump Context Highlight:**
- Triggered by: `<leader>nj` from narrowed view to context
- Effect: node boundaries highlighted via extmark background
- Highlight group: `LifeModeNarrowContext` (subtle blue/gray, default `#2d3748` bg)
- Duration: 2000ms, then fade transition (200ms) to normal
- Boundaries: from frontmatter line to last line of subtree

**Transitions:**
- Narrow operation: instantaneous buffer switch
- Widen operation: brief statusline flash sequence:
  1. `[Syncing...]` (300ms, highlight group `LifeModeStatusInfo`)
  2. `[Saved]` (500ms, highlight group `LifeModeStatusOk`)
  3. Return to normal statusline

#### 4.5.2 Transclusion Rendering

**Concealment Mechanism:**
- Raw token `{{uuid}}` or `{{uuid:depth}}` concealed when cursor not on line
- Concealed via `conceallevel=2`, concealchar empty
- Expanded content displayed in place of token
- Cursor hover behavior: when cursor on transclusion line, token becomes visible in virtual text at EOL: `[source: {{uuid}}]` (dim gray)

**Highlight Groups:**
- `LifeModeTransclusion` — Background for transcluded content (default `#2a2a2a`, subtle darker than normal)
- `LifeModeTransclusionSign` — Gutter sign appearance (`»`, fg `#6c6c6c`)
- `LifeModeTransclusionError` — Error states: cycle detection, missing nodes (bg `#3a1a1a`, fg `#ff6666`)
- `LifeModeTransclusionVirtual` — Virtual text for boundaries (fg `#4a4a4a`)

**Boundary Markers:**
- First line of transcluded content: virtual text `▼ Transcluded from <node-title>` (left-aligned, before content)
- Last line of transcluded content: virtual text `▲ End transclusion` (left-aligned, after content)
- Both use highlight group `LifeModeTransclusionVirtual`
- Gutter sign `»` on first line (namespace: `lifemode_transclusions`)

**Rendering States:**

*Loading State:*
```
[Loading transclusion...] ⟳
```
- Spinner char cycles through `⟳⟲⟳⟲` every 200ms
- Highlight: `LifeModeTransclusionLoading` (dim gray italic)
- Displayed during async index query

*Success State:*
```
▼ Transcluded from Research Notes
This is the transcluded content from another node.
It can span multiple lines and include formatting.
▲ End transclusion
```
- Background highlight applied to all content lines
- Gutter sign on first line only

*Error States:*
```
[⚠️ Cycle detected: {{a1b2c3d4}}]
[⚠️ Node not found: {{a1b2c3d4}}]
[⚠️ Max depth reached]
```
- Red background, bright red foreground
- Gutter sign `⚠` with error highlight
- Original token shown in brackets for debugging

#### 4.5.3 Side Window Layout

**Window Geometry:**
- Position: right split
- Width: 30% of vim width (configurable via `config.sidebar.width_percent`)
- Height: full vim height
- Border: rounded with title bar
- Title: `Context: <node-title>` (truncated to fit width)

**Structure:**
```
┌─ Context: Research Notes ──────────────┐
│ ▸ Context                               │
│ ▾ Citations                             │
│   • @bible:John.6.35                    │
│   • @bibtex:smith2020                   │
│                                         │
│   Related in other nodes:               │
│   → Daily Note (2026-01-20): @smith2020 │
│                                         │
│ ▾ Relations                             │
│   ← Backlinks (2):                      │
│     • Daily Note (2026-01-20)           │
│       "Referenced [[Research Notes]]"   │
│     • Project Alpha                     │
│                                         │
│   → Outgoing links (1):                 │
│     • Literature Review                 │
│                                         │
│   [<CR>] jump | [t] transclude          │
└─────────────────────────────────────────┘
```

**Fold Indicators:**
- Folded section: `▸ Section Name` (highlight group `LifeModeSidebarFolded`, dim fg)
- Expanded section: `▾ Section Name` (highlight group `LifeModeSidebarExpanded`, bright fg)
- Fold level: 1 for top-level sections, 2 for nested items
- Fold method: manual (via `za`, not expression-based)

**Interactive Elements:**
- Links/items: highlight group `LifeModeSidebarLink` (underline on cursor hover via `CursorMoved` autocmd)
- Context snippets: italic, dim gray (2-line max, truncated with `...`)
- Actions row: always visible at bottom, highlight group `LifeModeSidebarActions` (dim until cursor enters sidebar)

**Update Behavior:**
- Triggered by: `CursorHold` event (500ms debounce) in main buffer
- Detection: compare extmark UUID at cursor vs last-rendered UUID
- On change: fade-out effect (100ms dim), re-render, fade-in effect (100ms brighten)
- No update if: UUID unchanged, sidebar hidden, not in LifeMode buffer

#### 4.5.4 Citation Rendering

**Inline Citation States:**

*Unparsed (raw text):*
```
John 6:35
```
- Appears as normal text initially
- Parsed on BufEnter, TextChanged (debounced)

*Parsed (concealed):*
```
[John 6:35]
```
- Original text concealed via extmark
- Rendered as bracketed shortcode with underline (highlight group `LifeModeCitation`)
- Hover: virtual text shows normalized key `@bible:John.6.35`

*Missing Source:*
```
[Smith2020]
```
- Orange wavy underline (highlight group `LifeModeCitationMissing`, fg `#ff9900`, underline style wavy)
- Virtual text: `⚠️ Source not found` (at EOL)
- `gd` attempts jump, shows error: `[LifeMode] ERROR: Source not found: smith2020`

**Sidebar Citation Context:**

*Short form (collapsed):*
```
[@smith2020]
```

*One-line form (expanded):*
```
Smith (2020). "Knowledge Graphs for Personal Research"
```

*Jump action:*
- `gd` on citation: opens `.lifemode/sources/smith2020.yaml`
- Cursor positioned at `title:` field
- Sidebar updates to show source metadata in Context section

## 5. Transclusion & Backlinks
### 5.1 Transclusion
- Any node (and optionally its subtree) can be included elsewhere.
- Transclusion is recursive and nestable.
- A transcluded node remains a single identity.

### 5.2 Backlinks
- A reference A → B creates edge `A -> B` and backlink `B <- A`.
- Default backlink scope: **node+subtree**.
- Backlink propagation depth configurable:
  - `N = 0` node-only
  - `N > 0` up to N descendant levels
  - `N = ∞` anywhere inside B’s subtree

### 5.3 Transclusion UX (no manual IDs)
- Users never type node IDs.
- Insert/transclude via slash-command search:
  - free-text
  - themes
  - citations/sources
  - recency / date nodes
- Inserted token stores UUID invisibly, displays human-friendly label.

### 5.4 Transclusion Rendering States

#### 5.4.1 Expansion Algorithm

**Overview:**
Transclusions are expanded recursively at buffer display time. The algorithm tracks visited nodes to prevent cycles and enforces a configurable depth limit.

**Pseudocode:**
```
function expand_transclusions(buffer, config):
  visited = Set()
  max_depth = config.max_depth (default: 10)

  for each line in buffer:
    tokens = find_transclusion_tokens(line)  // match {{uuid}} or {{uuid:depth}}

    for token in tokens:
      result = expand_token(token, visited, depth=0, max_depth)
      replace_line_with_expansion(line, token, result)
      attach_extmark(line, token.uuid, result.metadata)

function expand_token(token, visited, depth, max_depth):
  if depth >= max_depth:
    return error_state("Max depth reached")

  if token.uuid in visited:
    return error_state("Cycle detected: " + token.uuid)

  visited.add(token.uuid)

  node = query_index(token.uuid)
  if not node:
    return error_state("Node not found: " + token.uuid)

  content = node.content
  target_depth = token.depth or 0  // 0 = root only, N = include N child levels

  if target_depth > 0:
    subtree = get_subtree(node, target_depth)
    content = content + "\n" + subtree

  // Recursively expand nested transclusions
  nested_tokens = find_transclusion_tokens(content)
  for nested in nested_tokens:
    nested_result = expand_token(nested, visited.copy(), depth+1, max_depth)
    content = replace_in_content(content, nested, nested_result)

  visited.remove(token.uuid)  // Allow re-entry in different branches

  return success_state(content, node.title)
```

**Reference:** Roam block transclusion (RESEARCH.md §2.2), TiddlyWiki transclusion nesting (§3.2)

#### 5.4.2 Cycle Detection Logic

**Detection Strategy:**
- Maintain a `visited` set per expansion path (not global)
- Add UUID to `visited` before expanding
- Check if UUID already in `visited` before recursing
- Remove UUID from `visited` after expansion completes (allows same node in different branches)

**Example: Cycle Detection**
```
Node A contains: "Introduction {{B}}"
Node B contains: "Details {{A}}"

Expansion trace:
1. Expand A: visited = {A}
2. Find {{B}}, expand B: visited = {A, B}
3. Find {{A}} in B: A in visited → CYCLE DETECTED
4. Replace {{A}} with: [⚠️ Cycle detected: {{A}}]
```

**Rendering:**
- Cycle detected: display `[⚠️ Cycle detected: {{uuid}}]`
- Apply highlight group: `LifeModeTransclusionError`
- Log warning: `[LifeMode] WARN: Circular transclusion detected: <title-A> ↔ <title-B>`
- Gutter sign: `⚠` with error color

**Configuration:**
- `config.transclusion.cycle_behavior = "error"` (default) or `"warn"` (show warning but attempt expansion once)

#### 5.4.3 Error State Rendering

**Error Types:**

*Cycle Detected:*
```
[⚠️ Cycle detected: {{a1b2c3d4}}]
```
- Trigger: UUID already in visited set
- Highlight: `LifeModeTransclusionError` (bg `#3a1a1a`, fg `#ff6666`)
- Virtual text: Original token shown for debugging
- Hover: shows cycle path: `A → B → A`

*Node Not Found:*
```
[⚠️ Node not found: {{a1b2c3d4}}]
```
- Trigger: Index query returns null
- Highlight: `LifeModeTransclusionError`
- Possible causes: deleted node, stale reference, index out of sync
- Action hint: virtual text `Run :LifeModeRebuildIndex if node exists`

*Max Depth Reached:*
```
[⚠️ Max depth reached]
```
- Trigger: `depth >= config.max_depth`
- Highlight: `LifeModeTransclusionError`
- Virtual text: `Depth limit: {max_depth}. Increase via config.transclusion.max_depth`
- Prevents runaway expansion in deeply nested structures

*Malformed Token:*
```
[⚠️ Invalid token: {{not-a-uuid}}]
```
- Trigger: token doesn't match UUID format
- Highlight: `LifeModeTransclusionError`
- Likely user error or corrupted reference

**Error Recovery:**
- Errors are non-fatal: rendering continues with error placeholder
- User can fix source and refresh buffer (`:e`)
- Index rebuild available: `:LifeModeRebuildIndex`

#### 5.4.4 Concealment vs Explicit Mode

**Concealment Mode (default):**
- `conceallevel=2` when cursor not on transclusion line
- Raw token `{{uuid}}` hidden, expanded content visible
- Cursor moves to line: token revealed in virtual text at EOL
- Config: `config.transclusion.conceal = true` (default)

**Explicit Mode:**
- `conceallevel=0` always shows token
- Expanded content shown below token as indented block
- Useful for debugging or when editing transclusion structure
- Config: `config.transclusion.conceal = false`

**Explicit Mode Layout:**
```
{{a1b2c3d4:2}}
  ▼ Transcluded from Research Notes
  This is the transcluded content.
  It appears indented below the token.
  ▲ End transclusion
```

**Toggle:**
- `:LifeModeToggleTransclusionConceal` — Switch modes in current buffer
- Keybinding: `<leader>nt` (toggle transclusion visibility)

#### 5.4.5 Performance & Caching Strategy

**Caching:**
- Expanded content cached in buffer-local table: `b:lifemode_transclusion_cache`
- Cache key: `{uuid}:{depth}` (different depths cached separately)
- Cache invalidated on:
  - Source node modified (detected via index mtime check)
  - Manual refresh: `:LifeModeRefreshTransclusions`
  - Buffer reload

**Lazy Expansion:**
- Transclusions outside viewport not expanded immediately
- On scroll: check visible lines, expand as needed
- Prevents slow rendering in buffers with many transclusions

**Async Rendering:**
- Index queries performed async (via `vim.loop` or `plenary.async`)
- Loading state displayed during query: `[Loading transclusion...] ⟳`
- Rendered content replaces loading state when query completes
- Max query timeout: 2000ms (then show error state)

**Performance Config:**
```lua
config.transclusion = {
  max_depth = 10,
  cache_enabled = true,
  lazy_viewport = true,    -- Only expand visible transclusions
  async_queries = true,
  query_timeout_ms = 2000,
}
```

**Reference:** Org-mode folding/unfolding performance (RESEARCH.md §1.3), TiddlyWiki lazy transclusion (§3.2)

## 6. Typing, Rendering, Export
### 6.1 Inference-first typing
- Types are primarily inferred; syntax can assist inference.
- Some types are easy (task, citation/source mentions) but system must support new types without code changes.

### 6.2 User-defined node types
Type definition specifies:
- matchers (regex/predicates)
- optional properties schema
- renderers (short / one-line / full)
- view/index participation
- optional exporters

### 6.3 Projects (LaTeX-shaped)
- Projects live under `projects/<name>/...`.
- Project content is authored as nodes, using transclusion and views.
- Export pipeline (later milestone): compile selected node trees into LaTeX/chapters/books.

### 6.4 Typed rendering
Certain types should render differently by view context:
- Task: shortcode / one-line / full
- Citation/Source: shortcode / one-line / full bibliographic
- General node: text-only or subtree-expanded

## 7. Indexing & Storage
### 7.1 SQLite graph/index
- Persisted at `.lifemode/index.sqlite`.
- Portable and fast.
- Rebuildable from markdown + config + sources.

### 7.2 Derived contexts (automatic indexes)
Nodes are automatically indexed into contexts such as:
- date-created (date nodes / daily logs)
- tasks
- sources/citations
- themes (wikilinks)

Manual structure remains possible via explicit transclusion.

## 8. Org-mode Influences
Borrow deliberately:
- outline structure + visibility cycling
- true narrowing (subtree as buffer)
- sparse/filtered outline views
- side buffers following context
- citation objects with multiple renderings

Explicitly not borrowing:
- mandatory refiling workflows
- single authoritative hierarchy

## 9. Error Handling & Resilience

### 9.1 Malformed Frontmatter
**Detection:**
- On buffer load: attempt YAML parse of frontmatter block (between `---` delimiters)
- Required fields: `id`, `created`
- Optional fields: `type`, user-defined extensions

**Error Responses:**
- **Missing frontmatter**: Show warning, offer to initialize with template via command
- **Invalid YAML**: Show parse error with line number, enter read-only mode, offer to open in external editor
- **Missing required fields**: Show warning with specific fields missing, allow edit, prevent index update until fixed
- **Malformed UUID**: Show error, prevent node operations, offer to regenerate UUID (with warning about broken references)
- **Invalid date format**: Show error, use file mtime as fallback with warning banner

**Recovery Actions:**
- `:LifeModeFixFrontmatter` — Guided repair workflow
- `:LifeModeValidateVault` — Scan entire vault, report all malformed nodes
- Graceful degradation: malformed nodes excluded from index but remain editable

### 9.2 Index Corruption
- SQLite corruption: detect on startup, offer to rebuild from vault
- Rebuild command: `:LifeModeRebuildIndex` — Full vault scan, progress indicator
- Stale index: detect mtime mismatches, auto-refresh affected nodes
- Write conflicts: last-write-wins, log warning with both UUIDs

### 9.3 User-Facing Error Messages
- Prefix: `[LifeMode]` for all messages
- Levels: `ERROR`, `WARN`, `INFO` (map to vim.log.levels)
- Include actionable next steps in error messages
- Link to relevant docs/help with `:help lifemode-troubleshooting`

## 10. BDD Scenarios

### 10.1 Capture Workflow

#### BDD-1.1: New Node Creation

**Scenario: Zero-friction capture**
```gherkin
Given user in any buffer
When executes `:LifeModeNewNode` or `<leader>nc`
Then computes today's directory (YYYY/MM-Mmm/DD)
  And creates directory if missing (mkdir -p behavior)
  And generates UUID v4
  And creates `<uuid>.md` in today's directory
  And writes frontmatter:
    ---
    id: <uuid>
    created: YYYY-MM-DD
    ---
  And opens in new buffer
  And auto-narrows to this node only (scratch buffer)
  And positions cursor on first content line (after frontmatter)
  And statusline shows "[NARROW]" marker
  And extmark attached to frontmatter line with node metadata
```

**Scenario: Vault not found error**
```gherkin
Given vault_path points to non-existent directory
When executes `:LifeModeNewNode`
Then shows error: "[LifeMode] ERROR: Vault not found at <path>"
  And shows hint: "Check config.vault_path in setup()"
  And no file created
  And cursor stays in original buffer
  And vim.log.levels.ERROR used
```

**Scenario: Permission denied on directory creation**
```gherkin
Given vault exists but user lacks write permission
When executes `:LifeModeNewNode`
Then shows error: "[LifeMode] ERROR: Permission denied creating directory: <full-path>"
  And shows hint: "Check directory permissions with :!ls -ld <path>"
  And no file created
  And no partial directories created
```

**Reference:** Org-mode capture templates (RESEARCH.md §1.2), Roam daily notes (§2.3)

#### BDD-1.2: Auto-Narrowing on Capture

**Scenario: New node opens narrowed automatically**
```gherkin
Given new node created via `:LifeModeNewNode`
When buffer loads
Then shows only frontmatter + empty content area (no other nodes)
  And creates scratch buffer named "*Narrow: <uuid>*"
  And sets buffer-local var `b:lifemode_narrow` = {
    source_file = "<vault>/YYYY/MM-Mmm/DD/<uuid>.md",
    source_uuid = "<uuid>",
    original_buf = nil  (new node, no original context)
  }
  And statusline shows "[NARROW]" marker with highlight `LifeModeNarrowStatus`
  And buffer appears as scratch (nofile, noswapfile)
  And virtual text at top: "↑ Context hidden. <leader>nw to widen"
  And window border color: cyan (#5fd7ff)
```

**Scenario: Widen from auto-narrowed capture**
```gherkin
Given newly captured node in auto-narrowed state
  And user has typed content
When types `<leader>nw` or executes `:LifeModeWiden`
Then syncs scratch buffer content to source file
  And writes file to disk
  And closes scratch buffer
  And opens source file buffer (the actual .md file)
  And cursor positioned at frontmatter line
  And statusline flash: "[Syncing...]" → "[Saved]"
  And statusline removes "[NARROW]" marker
  And window border returns to standard gray
  And extmark created for node boundaries
  And index updated with new node
```

**Scenario: Abandon capture (close without saving)**
```gherkin
Given newly captured node in auto-narrowed state
  And no content typed (empty except frontmatter)
When closes buffer (`:q`, `:bd`)
Then prompts: "Empty capture node. Delete file? [y/N]"
When user types 'y'
Then deletes source file
  And closes scratch buffer
  And returns to previous buffer
When user types 'N'
Then keeps file (allows saving empty node)
  And closes scratch buffer
```

**Reference:** Org-mode narrowing (RESEARCH.md §1.2)

### 10.2 Navigation & Focus

#### BDD-2.1: Manual Narrowing to Subtree

**Scenario: Narrow to focus on specific node**
```gherkin
Given LifeMode buffer with multiple nodes
  And cursor on line 42 (within node "Research Notes")
  And node boundaries: lines 38-65
When types `<leader>nn` or executes `:LifeModeNarrow`
Then queries extmark at cursor position for node UUID
  And identifies node "Research Notes" (uuid: a1b2c3d4)
  And identifies node boundaries via extmark metadata
  And creates scratch buffer "*Narrow: Research Notes*"
  And copies lines 38-65 (frontmatter + content) to scratch buffer
  And sets `b:lifemode_narrow` = {
    source_file = "<current-file>",
    source_uuid = "a1b2c3d4",
    source_range = {38, 65},
    original_buf = <buf-number>
  }
  And displays only narrowed content
  And statusline shows "[NARROW: Research Notes]"
  And window border: cyan
  And cursor positioned at same relative offset
```

**Scenario: Narrow when cursor not on a node**
```gherkin
Given LifeMode buffer
  And cursor on line 10 (blank line between nodes)
  And no extmark at cursor position
When types `<leader>nn`
Then shows warning: "[LifeMode] WARN: Cursor not within a node"
  And no action taken
  And vim.log.levels.WARN used
```

**Reference:** Org-mode narrow-to-subtree (RESEARCH.md §1.2)

#### BDD-2.2: Widening from Narrow View

**Scenario: Widen to restore context**
```gherkin
Given narrowed view active for node "Research Notes"
  And content edited in scratch buffer (lines added/removed)
  And original source range was lines 38-65
When types `<leader>nw` or executes `:LifeModeWiden`
Then calculates new node content from scratch buffer
  And computes diff (old vs new boundaries)
  And updates source buffer lines 38-65 with new content
  And updates extmark boundaries if changed (e.g., 38-72)
  And writes source buffer to disk
  And closes scratch buffer
  And displays source buffer
  And restores cursor to node frontmatter line (line 38)
  And statusline flash: "[Syncing...]" (300ms) → "[Saved]" (500ms)
  And marks index for update (triggers on BufWritePost)
```

**Scenario: Warning when not narrowed**
```gherkin
Given normal buffer (not narrowed)
  And `b:lifemode_narrow` is nil
When types `<leader>nw`
Then shows warning: "[LifeMode] WARN: Not in narrowed view"
  And no action taken
```

**Scenario: Conflict detection (source modified while narrowed)**
```gherkin
Given narrowed view active
  And source file modified externally (e.g., git pull)
When types `<leader>nw`
Then detects mtime mismatch on source file
  And shows error: "[LifeMode] ERROR: Source file modified. Reload or force save?"
  And prompts: "[r]eload narrow (lose changes) | [f]orce save (overwrite) | [c]ancel"
When user types 'r'
  Then reloads narrow buffer from source
When user types 'f'
  Then overwrites source with narrow content (logs warning)
When user types 'c'
  Then no action, stays in narrow view
```

**Reference:** Org-mode widen (RESEARCH.md §1.2)

#### BDD-2.3: Jump Between Narrow and Context

**Scenario: Toggle narrow ↔ context**
```gherkin
Given narrowed view active for node "Research Notes" (uuid: a1b2c3d4)
  And `b:lifemode_narrow.source_file` = "vault/2026/01-Jan/20/daily.md"
When types `<leader>nj` or executes `:LifeModeJumpContext`
Then switches to source buffer (daily.md)
  And jumps cursor to line 38 (node frontmatter)
  And highlights node boundaries (lines 38-65) with `LifeModeNarrowContext`
  And neighboring nodes visible (lines 1-100)
  And extmarks show all node boundaries in file
  And highlight persists for 2000ms, then fades (200ms transition)
  And stores jump history for `<leader>nj` toggle
```

**Scenario: Jump back to narrow from context**
```gherkin
Given jumped to context from narrow (previous scenario)
  And jump history records narrow buffer ID
When types `<leader>nj` again (toggle)
Then checks if narrow buffer still exists
  If exists: switches to narrow buffer
  If closed: recreates narrow buffer from source
Then restores cursor position in narrow view
  And statusline shows "[NARROW: Research Notes]"
```

**Scenario: Jump when not in narrow or jumped context**
```gherkin
Given normal buffer with no narrow history
When types `<leader>nj`
Then shows info: "[LifeMode] INFO: Not in narrow view or jumped context"
  And suggests: "Use <leader>nn to narrow first"
```

**Reference:** Org-mode indirect buffers (RESEARCH.md §1.2)

### 10.3 Transclusion & References

#### BDD-3.1: Inserting Transclusions

**Scenario: Insert via slash command**
```gherkin
Given editing node in insert mode
  And cursor at empty line 15
When types `/` (slash command trigger)
Then floating window appears with command palette
  And shows options: ["transclude", "cite", "embed view", ...]
When types "trans" (fuzzy search)
  And list filters to "transclude"
  And presses <CR>
Then node picker appears (Telescope fuzzy finder)
  And shows all nodes in vault (title + preview)
When types "research" (search)
  And list filters to matching nodes
  And selects node "Research Notes" (uuid: a1b2c3d4)
  And presses <CR>
Then inserts `{{a1b2c3d4}}` at cursor (line 15)
  And palette closes
  And insert mode continues (cursor after token)
  And transclusion renders immediately (async)
  And extmark attached with metadata: {uuid: "a1b2c3d4", depth: 0}
```

**Scenario: Transclusion with depth**
```gherkin
Given slash command palette open
When selects "transclude (with depth)"
Then node picker appears
When selects node "Research Notes" (uuid: a1b2c3d4)
Then prompts: "Depth (0=node only, 1+=include children): "
When enters "2"
  And presses <CR>
Then inserts `{{a1b2c3d4:2}}`
  And renders node + 2 levels of children
  And extmark metadata: {uuid: "a1b2c3d4", depth: 2}
```

**Scenario: Cancel insertion**
```gherkin
Given node picker open for transclusion
When presses <Esc> or <C-c>
Then picker closes
  And no token inserted
  And cursor returns to original position
  And insert mode continues
```

**Reference:** Org-mode transclusion (RESEARCH.md §1.4), Roam block embeds (§2.2)

#### BDD-3.2: Rendering Transclusions

**Scenario: Expansion on buffer display**
```gherkin
Given node file contains line: "Introduction {{a1b2c3d4}}"
  And node a1b2c3d4 has content: "This is transcluded content."
  And node a1b2c3d4 title: "Research Notes"
When buffer opens or refreshes (BufEnter, TextChanged events)
Then parses all `{{...}}` tokens via regex
  And queries index for node a1b2c3d4 (async)
  And retrieves content + title
  And replaces token with expanded content (concealment)
  And attaches extmark (namespace: `lifemode_transclusions`)
  And conceals raw token `{{a1b2c3d4}}` (conceallevel=2)
  And displays expanded content: "This is transcluded content."
  And applies highlight `LifeModeTransclusion` (bg #2a2a2a)
  And adds gutter sign `»` on first line
  And virtual text: "▼ Transcluded from Research Notes" (before content)
  And virtual text: "▲ End transclusion" (after content)
```

**Scenario: Visual indicator on cursor hover**
```gherkin
Given transcluded content rendered (concealed)
  And cursor not on transclusion line
When cursor moves to line 15 (transclusion line)
Then raw token becomes visible in virtual text at EOL: "[source: {{a1b2c3d4}}]"
  And token styled with dim gray (highlight `LifeModeTransclusionVirtual`)
When cursor moves away
Then virtual text hidden again
  And only expanded content visible
```

**Reference:** TiddlyWiki transclusion (RESEARCH.md §3.2)

#### BDD-3.3: Cycle Detection

**Scenario: Circular transclusion detected**
```gherkin
Given node A (uuid: aaaa) contains: "Intro {{bbbb}}"
  And node B (uuid: bbbb) contains: "Details {{aaaa}}"
When buffer with node A opens
Then expansion begins:
  1. visited = {aaaa}
  2. expand A: find {{bbbb}}
  3. visited = {aaaa, bbbb}
  4. expand B: find {{aaaa}}
  5. detect: aaaa in visited → CYCLE
Then replaces {{aaaa}} in B with: "[⚠️ Cycle detected: {{aaaa}}]"
  And applies highlight `LifeModeTransclusionError` (bg #3a1a1a, fg #ff6666)
  And gutter sign `⚠` with error color
  And logs: "[LifeMode] WARN: Circular transclusion detected: Research Notes ↔ Daily Note"
  And shows virtual text hover: "Cycle path: A → B → A"
```

**Scenario: Depth limit prevents runaway**
```gherkin
Given 12-level deep transclusion chain (A→B→C→...→L→M)
  And config.transclusion.max_depth = 10
When expansion reaches depth 10 (node K)
Then finds transclusion {{L}} at depth 10
  And depth check: 10 >= 10 (max_depth)
Then replaces {{L}} with: "[⚠️ Max depth reached]"
  And applies error highlight
  And virtual text: "Depth limit: 10. Increase via config.transclusion.max_depth"
  And no further expansion (stops recursion)
```

**Reference:** TiddlyWiki recursion limits (RESEARCH.md §3.2)

#### BDD-3.4: Editing Transcluded Content

**Scenario: Attempt to edit transcluded content (read-only)**
```gherkin
Given transcluded content displayed at lines 20-23
  And extmark marks range as transcluded
  And cursor at line 21 (within transclusion)
When attempts to edit (insert mode, delete, paste)
Then checks extmark metadata: `transcluded = true`
  And blocks modification
  And shows message: "[LifeMode] INFO: Read-only. Use 'gd' to jump to source"
  And briefly highlights boundaries (200ms flash, yellow)
```

**Scenario: Jump to source for editing**
```gherkin
Given cursor on line 21 (transcluded content)
  And extmark metadata: {uuid: "a1b2c3d4", source_file: "..."}
When types `gd` (go to definition)
Then queries extmark for source UUID
  And queries index for node location
  And opens source file
  And jumps cursor to node frontmatter line
  And updates jump list (enables `<C-o>` to return)
  And shows message: "[LifeMode] Jumped to source: Research Notes"
```

**Scenario: Edit source and see transclusion update**
```gherkin
Given jumped to source node (previous scenario)
When edits content in source
  And saves buffer (`:w`)
Then triggers BufWritePost event
  And index update detects node change
  And invalidates transclusion cache for uuid a1b2c3d4
When returns to original buffer (`<C-o>`)
  And buffer re-renders
Then transclusion displays updated content
  And cache refreshed with new content
```

**Reference:** Org-mode transclusion editing (RESEARCH.md §1.4)

### 10.4 Side Window Interactions

#### BDD-4.1: Toggle Side Window

**Scenario: Open side window**
```gherkin
Given side window closed
  And LifeMode buffer active
  And cursor on node "Research Notes" (line 42)
When types `<leader>ns` or executes `:LifeModeSidebar`
Then queries extmark at cursor for node UUID (a1b2c3d4)
  And queries index for node context:
    - citations: [@bible:John.6.35, @bibtex:smith2020]
    - backlinks: [{uuid: "daily-uuid", title: "Daily Note", context: "..."}]
    - outgoing links: [{uuid: "lit-review-uuid", title: "Literature Review"}]
  And creates floating window on right
  And window width: 30% of vim width (or config.sidebar.width_percent)
  And window height: matches vim height (100%)
  And border: rounded with title "Context: Research Notes"
  And renders accordion sections (all folded by default):
    ▸ Context
    ▸ Citations
    ▸ Relations
  And window highlights: `LifeModeSidebar` highlight group
  And sets `w:lifemode_sidebar` = {node_uuid: "a1b2c3d4", last_update: <timestamp>}
```

**Scenario: Close on toggle**
```gherkin
Given side window open
  And focus in main buffer or sidebar
When types `<leader>ns`
Then closes sidebar window
  And focus returns to main buffer (if was in sidebar)
  And clears `w:lifemode_sidebar` var
```

**Scenario: Open when no node at cursor**
```gherkin
Given cursor on blank line (no extmark)
When types `<leader>ns`
Then shows warning: "[LifeMode] WARN: Cursor not within a node"
  And no sidebar opened
```

**Reference:** Org-mode sidebar buffers (RESEARCH.md §2.5)

#### BDD-4.2: Updates on Node Change

**Scenario: Refresh when cursor moves to different node**
```gherkin
Given side window showing context for node A (uuid: aaaa)
  And `w:lifemode_sidebar.node_uuid` = "aaaa"
  And cursor in main buffer on node A (line 10)
When cursor moves to node B (line 50, uuid: bbbb)
  And waits 500ms (debounce via CursorHold)
Then CursorHold autocmd fires
  And queries extmark at cursor: uuid = bbbb
  And compares to last rendered: aaaa ≠ bbbb → CHANGED
Then queries index for node B metadata
  And re-renders sidebar with node B context
  And updates title: "Context: <node-B-title>"
  And updates `w:lifemode_sidebar.node_uuid` = "bbbb"
  And updates `w:lifemode_sidebar.last_update` = <new-timestamp>
  And brief fade transition (100ms dim → 100ms brighten)
```

**Scenario: No update within same node**
```gherkin
Given side window shows node A (uuid: aaaa)
  And cursor on line 15 (within node A, boundaries 10-30)
When cursor moves to line 18 (still within node A)
  And CursorHold fires after 500ms
Then queries extmark at line 18: uuid = aaaa
  And compares to last rendered: aaaa = aaaa → NO CHANGE
  And no re-render (performance optimization)
  And no index query
```

**Scenario: Sidebar closes if node lost**
```gherkin
Given sidebar open for node A
When node A deleted in main buffer
  And cursor moves to blank area
  And CursorHold fires
Then queries extmark: returns nil (no node)
  And shows message: "[LifeMode] INFO: Node lost, closing sidebar"
  And closes sidebar window
```

**Reference:** Org-mode context tracking (RESEARCH.md §2.5)

#### BDD-4.3: Accordion Interactions

**Scenario: Expand section**
```gherkin
Given side window open, all sections folded
  And focus in sidebar buffer
  And cursor on line 3: "▸ Relations"
When types `za` (toggle fold)
Then Relations section expands
  And displays:
    ▾ Relations
      ← Backlinks (2):
        • Daily Note (2026-01-20)
          "Referenced [[Research Notes]]"
        • Project Alpha

      → Outgoing links (1):
        • Literature Review
  And fold indicator changes: ▸ → ▾
  And fold state persisted to session (via view/mkview)
```

**Scenario: Quick action - jump to backlink**
```gherkin
Given Relations section expanded
  And backlinks displayed:
    • Daily Note (2026-01-20)
  And cursor on that line (line 8)
When types `<CR>` (Enter key)
Then extracts uuid from line metadata (extmark or line text)
  And opens backlink source file
  And jumps cursor to reference line (where "Research Notes" mentioned)
  And highlights reference (brief 1s flash, yellow)
  And sidebar remains open
  And sidebar updates context to new node (Daily Note)
  And jump history updated (enables `<C-o>` return)
```

**Scenario: Transclude from sidebar**
```gherkin
Given Relations section showing backlink "Daily Note"
  And cursor on backlink line
When types `t` (transclude shortcut in sidebar)
Then extracts backlink uuid
  And switches focus to main buffer (original cursor position)
  And inserts `{{<backlink-uuid>}}` at cursor in main buffer
  And focus returns to main buffer
  And transclusion renders immediately
  And sidebar updates (may now show transclusion in context)
```

**Reference:** Org-mode agenda quick actions (RESEARCH.md §1.5)

---

## Appendix A: Resolved Design Decisions

### Decision A.1: Node UUID Persistence
**RESOLVED:** Triple Redundancy (Frontmatter + Extmark + Index)

**Implementation:**
- **Frontmatter:** Source of truth, human-editable, survives file moves/renames
- **Extmarks:** Fast in-buffer queries for current node detection (namespace: `lifemode_nodes`)
- **Index (SQLite):** Vault-wide relationship queries and graph traversal

**On Buffer Load:**
1. Parse YAML frontmatter for `id` field
2. Create extmark on frontmatter line with metadata: `{node_id: "<uuid>", node_start: <line>, node_end: <line>}`
3. Verify UUID against index, log warning if mismatch
4. Update index if frontmatter is newer (mtime check)

**On Buffer Save:**
- Re-parse frontmatter
- Update extmark boundaries if node content changed
- Update index with new metadata, content hash, mtime

**Rejected Alternatives:**
- **Hidden marker comment:** Breaks with auto-formatters (Prettier, Black), not robust
- **Property line:** Clutters content, non-standard Markdown, confusing for users
- **Extmark/index-only:** No human-readable UUID, lost on external edits, not portable

**Rationale:**
- Frontmatter is standard, readable, and survives external tools (git, rsync, text editors)
- Extmarks provide O(1) lookup during editing for navigation/narrowing
- Index enables complex queries (backlinks, citations, views) without parsing all files

**Reference:** Roam block UIDs in DOM (RESEARCH.md §2.1), Org-mode property drawers (§1.1), Org-roam database + file properties (§1.4)

---

### Decision A.2: Citation Scheme DSL
**RESOLVED:** YAML Definitions with Embedded Lua Functions

**Schema:**
```yaml
# .lifemode/citation_schemes/bible.yaml
name: bible
description: "Biblical references (John 3:16)"
patterns:
  - regex: '(\w+)\s+(\d+):(\d+)'
    groups: [book, chapter, verse]
  - regex: '(\d+)\s+(\w+)\s+(\d+):(\d+)'  # 1 John 3:16
    groups: [number, book, chapter, verse]
normalize: |
  function(match)
    local book = match.book:lower()
    if match.number then
      book = match.number .. book
    end
    return string.format("@bible:%s.%s.%s",
      book, match.chapter, match.verse)
  end
render:
  short: "[@bible:<key>]"
  one_line: "<Book> <chapter>:<verse>"
  full: "<Book> <chapter>:<verse> (Bible)"
```

**Override Mechanism:**
- User schemes in `.lifemode/citation_schemes/` override built-in schemes (by `name` field)
- Loaded on plugin init, cached in registry: `citation_schemes[name] = scheme`
- Config option: `config.citation_schemes.exclude = {'bibtex'}` (disable built-in schemes)
- Config option: `config.citation_schemes.paths = {'~/.config/lifemode/schemes'}` (additional search paths)

**Rendering Contexts:**
- **short:** Inline in prose, concealed (e.g., `[John 6:35]`)
- **one_line:** Sidebar, tooltips, quick reference (e.g., `John 6:35`)
- **full:** Export, bibliography, full context (e.g., `John 6:35 (Bible, King James Version)`)

**Normalization:**
- User types: `John 6:35` (natural language)
- Parser matches regex, extracts groups
- Normalize function returns: `@bible:john.6.35` (canonical key)
- Stored in index as canonical key
- Rendered back to user as `[John 6:35]` (short form)

**Rejected Alternatives:**
- **JSON schema:** Less readable for complex logic, no native function embedding
- **Pure Lua config:** Less declarative, harder for users to add schemes without Lua knowledge
- **Hardcoded schemes:** Not extensible, doesn't support user's custom sources (Summa, Spiritual Exercises)

**Rationale:**
- YAML is readable and familiar to non-programmers
- Lua functions provide flexibility for complex normalization (e.g., book name variations)
- Declarative regex patterns are easier to debug than procedural code
- Override mechanism allows users to customize without forking plugin

**Reference:** TiddlyWiki filter operators (RESEARCH.md §3.3), Org-mode cite processors (§1.4), Roam canonical sources (§2.4)

---

### Decision A.3: BibTeX UX & Source Management
**RESOLVED:** YAML Sources → Auto-Generate .bib

**Workflow:**
1. User creates canonical source: `.lifemode/sources/smith2020.yaml`
2. YAML contains: title, author, year, url, tags, notes (extensible schema)
3. LifeMode auto-generates: `.lifemode/bib/smith2020.bib` on save (debounced)
4. `gd` on citation jumps to YAML by default (editable, readable)
5. `:LifeModeOpenBib` to view generated .bib (read-only preview)
6. Aggregate file: `.lifemode/bib/generated_all.bib` for LaTeX compilation

**File Layout:**
```
.lifemode/
  sources/
    smith2020.yaml       # user-editable, source of truth
    jones2019.yaml
  bib/
    smith2020.bib        # auto-generated from YAML
    jones2019.bib
    generated_all.bib    # aggregate for LaTeX \bibliography{}
```

**Sync Strategy:**
- **YAML → .bib:** Auto-generate on save (BufWritePost), debounced 500ms
- **.bib → YAML:** NOT supported (YAML is source of truth, .bib is derived)
- **External .bib import:** `:LifeModeImportBib <file>` → parses .bib, creates YAML sources
- **Aggregate update:** Triggered on export (`:LifeModeExportProject`) or manual (`:LifeModeGenerateBib`)

**YAML Schema Example:**
```yaml
key: smith2020
type: article
title: "Knowledge Graphs for Personal Research"
author:
  - Smith, John
  - Doe, Jane
year: 2020
journal: "Journal of Knowledge Management"
url: "https://example.com/paper.pdf"
tags: [knowledge-graphs, PKM]
notes: |
  Key insight: bidirectional links enable serendipity.
  See also: [[Research Notes]]
```

**Rationale:**
- YAML is more readable and extensible than .bib (supports tags, notes, wikilinks)
- Users edit YAML, not cryptic .bib syntax (`@article{...}`)
- Supports non-BibTeX schemes (Bible, Summa) in same `.lifemode/sources/` directory
- Generated .bib ensures LaTeX compatibility without forcing users to write .bib
- One-way sync avoids conflicts and keeps YAML as single source of truth

**Rejected Alternatives:**
- **Edit .bib directly:** Cryptic syntax, doesn't support custom schemes, not extensible
- **Bidirectional sync:** Complex, introduces conflicts, unclear source of truth
- **.bib as source:** Doesn't support non-BibTeX citations, hard to extend with custom fields

**Reference:** Org-roam cite keys (RESEARCH.md §1.5), Zotero metadata + custom fields (§2.4), Calibre library management (§3.4)

---

### Decision A.4: View/Query DSL Syntax
**RESOLVED:** Keyword-Based Filter Syntax (Inspired by TiddlyWiki)

**Core Syntax:**
```
tag:paper status:draft -tag:archived sort:modified first:5
```

**Operators:**
- `tag:value` — Match tag (AND with other filters)
- `type:value` — Match node type (e.g., `type:task`, `type:source`)
- `status:value` — Match frontmatter field value (e.g., `status:draft`)
- `-tag:value` — Exclude (NOT operator)
- `sort:field` — Order by field (default: ascending, prefix `-` for descending: `sort:-created`)
- `first:N` — Limit to first N results
- `created:YYYY-MM-DD` — Date filter (exact match or range: `created:2026-01-20..2026-01-25`)
- `cites:@scheme:key` — Nodes citing a specific source (e.g., `cites:@bible:john.6.35`)
- `backlinks:uuid` — Nodes linking to a specific UUID
- `has:field` — Nodes with a specific frontmatter field (e.g., `has:status`)

**Composition:**
- Space-separated = AND (e.g., `tag:task status:incomplete` → tasks that are incomplete)
- Multiple same operator = OR (e.g., `tag:project tag:research` → nodes with project OR research tag)
- Multiple `first`/`sort` → last wins (e.g., `sort:created sort:modified` → sorted by modified)

**View Embedding in Markdown:**
```markdown
<!-- view: tag:task status:incomplete sort:created -->
```
- On buffer render: Replace comment with query results (live-updating list)
- Results formatted as Markdown list with links: `- [[node-title]] (created: YYYY-MM-DD)`
- Max results in embedded view: 20 (configurable)

**Examples:**
- All incomplete tasks: `tag:task status:incomplete`
- Recent papers citing Smith: `cites:@bibtex:smith2020 sort:-modified first:10`
- Draft nodes excluding archived: `status:draft -tag:archived`
- Nodes created this week: `created:2026-01-15..2026-01-21`

**Rejected Alternatives:**
- **SQL-like syntax:** Too verbose, unfamiliar to non-programmers (`SELECT * FROM nodes WHERE tag = 'task'`)
- **Datalog queries:** Too abstract, steep learning curve
- **JSON query objects:** Not human-readable, can't embed in Markdown comments

**Rationale:**
- Keyword syntax is concise, readable, and familiar (similar to GitHub search, Gmail filters)
- Space-separated AND is intuitive (progressive filtering)
- Embeddable in Markdown comments (doesn't break rendering in other apps)
- Extensible: new operators can be added without breaking existing queries

**Reference:** TiddlyWiki filter syntax (RESEARCH.md §3.3), Org-mode agenda views (§1.5), Dataview query language (§3.1)

---

### Decision A.5: Creative-Relation Discovery
**RESOLVED:** Traversal Affordances with Confidence Signals (No Auto-Links)

**Principle:** Show users **potential connections** with **explicit confidence scores** and **rationale**, but **never auto-create links**.

**UI Surface:** "Potential Connections" section in sidebar (below Relations)

**Display Example:**
```
▾ Potential Connections
  📊 Strength: Shared citations (85%)
  → "Literature Review"
    Shared: @smith2020, @jones2019

  📊 Strength: Temporal proximity (70%)
  → "Project Alpha Notes"
    Both created: 2026-01-20

  📊 Strength: Content similarity (60%)
  → "Research Methods"
    Shared terms: qualitative, interview, thematic

  [View more...] | [Dismiss all]
```

**User Actions:**
- **`<CR>` on suggestion:** Jump to suggested node (preview, doesn't create link)
- **`l` (link):** Prompts: "Link these nodes? [y/N]" → creates wikilink/transclusion
- **`d` (dismiss):** Hide suggestion for this session (persisted to `.lifemode/dismissed_connections.json`)
- **`D` (dismiss all):** Hide all suggestions for current node

**Confidence Scoring:**
- **Shared citations (weight: 3x):** Nodes citing the same source likely related
- **Shared tags (weight: 2x):** Explicit user categorization
- **Temporal proximity (weight: 1x):** Created on same day (weak signal)
- **Content similarity via FTS (weight: 1.5x):** Shared significant terms (TF-IDF)
- **Threshold:** Only show connections with score ≥ 50%

**Prioritization:**
- Top 5 suggestions shown by default
- Sorted by confidence score (descending)
- "View more..." expands to top 20

**No Auto-Conclusions:**
- System **NEVER** creates links automatically
- Creative relations are **suggestions**, not assertions
- User must confirm: system shows "WHY" (rationale), user decides "IF" (create link)
- Productive relations (transclusions, wikilinks) are **explicit only**

**Rejected Alternatives:**
- **Auto-linking:** Presumes semantic equivalence, removes user agency, creates noise
- **"Related" without rationale:** Not transparent, feels like black box, no trust
- **Machine learning embeddings:** Opaque, no explainable rationale, high compute cost

**Rationale:**
- Discovery is about **traversal affordances**, not **editorial conclusions**
- Confidence scores + rationale = **transparent suggestions**, not **hidden algorithms**
- User confirmation = **preserve intentionality**, avoid "link explosion"
- Creative relations require human judgment (e.g., two nodes cite Smith but argue opposite conclusions)

**Reference:** Roam "Unlinked References" (RESEARCH.md §2.2), Obsidian "Unlinked Mentions" (§3.5), Org-roam "Backlinks" context (§1.4)

---

## Appendix B: Visual State Reference

### B.1 Highlight Groups Catalog

**Narrowing & Focus:**
| Group Name | Purpose | Default Foreground | Default Background | Other |
|------------|---------|-------------------|-------------------|-------|
| `LifeModeNarrowStatus` | Statusline narrow indicator | bright white | cyan (#5fd7ff) | bold |
| `LifeModeNarrowHint` | Virtual text hints | dim gray (#6c6c6c) | none | italic |
| `LifeModeNarrowContext` | Context highlight on jump | none | subtle blue (#2d3748) | none |
| `LifeModeStatusInfo` | Syncing status flash | white | blue (#3b82f6) | none |
| `LifeModeStatusOk` | Saved status flash | white | green (#10b981) | none |

**Transclusion:**
| Group Name | Purpose | Default Foreground | Default Background | Other |
|------------|---------|-------------------|-------------------|-------|
| `LifeModeTransclusion` | Transcluded content | inherit | darker (#2a2a2a) | none |
| `LifeModeTransclusionSign` | Gutter sign `»` | dim gray (#6c6c6c) | none | none |
| `LifeModeTransclusionError` | Cycle/error states | bright red (#ff6666) | dark red (#3a1a1a) | none |
| `LifeModeTransclusionVirtual` | Boundary markers | dim gray (#4a4a4a) | none | none |
| `LifeModeTransclusionLoading` | Loading state | dim gray (#6c6c6c) | none | italic |

**Citations:**
| Group Name | Purpose | Default Foreground | Default Background | Other |
|------------|---------|-------------------|-------------------|-------|
| `LifeModeCitation` | Parsed citation | inherit | none | underline |
| `LifeModeCitationMissing` | Missing source | orange (#ff9900) | none | wavy underline |

**Sidebar:**
| Group Name | Purpose | Default Foreground | Default Background | Other |
|------------|---------|-------------------|-------------------|-------|
| `LifeModeSidebar` | Sidebar base | inherit | inherit | none |
| `LifeModeSidebarFolded` | Folded section header | dim (#6c6c6c) | none | none |
| `LifeModeSidebarExpanded` | Expanded section header | bright (#e5e5e5) | none | bold |
| `LifeModeSidebarLink` | Interactive links | cyan (#5fd7ff) | none | underline (on hover) |
| `LifeModeSidebarActions` | Action hints | dim (#6c6c6c) | none | none |

### B.2 Gutter Signs Reference

| Sign | Name | Context | Highlight Group |
|------|------|---------|----------------|
| `»` | Transclusion marker | First line of transcluded content | `LifeModeTransclusionSign` |
| `⚠` | Error marker | Cycle detection, missing node, max depth | `LifeModeTransclusionError` |
| `▸` | Node collapsed | Folded node in outline (future) | `LifeModeFold` |
| `▾` | Node expanded | Expanded node in outline (future) | `LifeModeFold` |

### B.3 Buffer State Transitions

**Normal → Narrowed (Capture):**
```
State: Normal buffer (any content)
  ↓ User: `:LifeModeNewNode` or `<leader>nc`
State: New node created (YYYY/MM-Mmm/DD/<uuid>.md)
  ↓ System: Auto-narrow
State: Scratch buffer "*Narrow: <uuid>*"
  • Statusline: [NARROW]
  • Border: cyan
  • Virtual text: "↑ Context hidden. <leader>nw to widen"
  ↓ User: Types content
State: Content in scratch buffer (unsaved)
  ↓ User: `<leader>nw` or `:LifeModeWiden`
State: Syncing to source file
  • Statusline: [Syncing...] (300ms)
  • Statusline: [Saved] (500ms)
  ↓ System: Save complete
State: Source file buffer (normal view)
  • Extmark created
  • Index updated
```

**Normal → Narrowed (Manual):**
```
State: LifeMode buffer with multiple nodes
  ↓ User: Cursor on node, `<leader>nn`
State: Scratch buffer "*Narrow: <node-title>*"
  • Only node subtree visible
  • Border: cyan
  • Statusline: [NARROW: <node-title>]
  ↓ User: Edits content
State: Content modified in narrow view
  ↓ User: `<leader>nw` or `:LifeModeWiden`
State: Syncing changes to source
  ↓ System: Update source lines, extmarks
State: Source file buffer (normal view)
  • Cursor at node frontmatter
  • Neighboring nodes visible
```

**Narrow ↔ Context (Jump):**
```
State: Narrowed view active
  ↓ User: `<leader>nj`
State: Source buffer (context view)
  • Node boundaries highlighted (2s)
  • Neighboring nodes visible
  ↓ User: `<leader>nj` again
State: Narrowed view restored
  • Same content, cursor preserved
```

### B.4 Sidebar Update Flow

**Node Change Detection:**
```
Event: CursorHold (500ms debounce)
  ↓ Query extmark at cursor
Extmark UUID: <uuid>
  ↓ Compare to w:lifemode_sidebar.node_uuid
Decision: UUID changed?
  ├─ NO → No-op (performance optimization)
  └─ YES → Re-render sidebar
      ↓ Query index for node metadata
      ↓ Fade out (100ms)
      ↓ Update content
      ↓ Fade in (100ms)
      ↓ Update w:lifemode_sidebar.node_uuid
```

**Sidebar Layout States:**
```
State: Sidebar closed
  ↓ User: `<leader>ns`
State: Sidebar open (all sections folded)
  ▸ Context
  ▸ Citations
  ▸ Relations
  ↓ User: Cursor in sidebar, `za` on "Relations"
State: Relations section expanded
  ▾ Relations
    ← Backlinks (2):
      • Daily Note (2026-01-20)
      • Project Alpha
    → Outgoing links (1):
      • Literature Review
  ↓ User: `<CR>` on backlink
State: Main buffer switches to backlink source
  • Sidebar updates to new node context
  • Jump history updated
```

### B.5 Transclusion Rendering States

**Success Path:**
```
Markdown source: "Introduction {{a1b2c3d4}}"
  ↓ Parse on BufEnter
Token found: {{a1b2c3d4}}
  ↓ Query index (async, 100-2000ms)
Loading state: "[Loading transclusion...] ⟳"
  ↓ Index returns: {content, title}
Success state:
  Concealed: {{a1b2c3d4}}
  Displayed:
    ▼ Transcluded from Research Notes
    This is transcluded content.
    ▲ End transclusion
  Extmark: {uuid, depth, transcluded: true}
  Highlight: LifeModeTransclusion (bg #2a2a2a)
  Gutter: »
```

**Error Path (Cycle):**
```
Node A: "Intro {{B}}"
Node B: "Details {{A}}"
  ↓ Expand A
visited = {A}
  ↓ Find {{B}}
visited = {A, B}
  ↓ Expand B
  ↓ Find {{A}}
Cycle detected: A ∈ visited
  ↓ Error rendering
Displayed:
  [⚠️ Cycle detected: {{A}}]
  Highlight: LifeModeTransclusionError
  Gutter: ⚠
  Virtual text: "Cycle path: A → B → A"
```

**Error Path (Not Found):**
```
Token: {{xyz123}}
  ↓ Query index
Result: nil (node not found)
  ↓ Error rendering
Displayed:
  [⚠️ Node not found: {{xyz123}}]
  Highlight: LifeModeTransclusionError
  Virtual text: "Run :LifeModeRebuildIndex if node exists"
```

### B.6 Citation Rendering Pipeline

**Unparsed → Parsed:**
```
Raw text: "John 6:35"
  ↓ BufEnter / TextChanged (debounced)
Pattern match: (\w+)\s+(\d+):(\d+)
  ↓ Extract groups: {book: "John", chapter: "6", verse: "35"}
Normalize: @bible:john.6.35
  ↓ Store in index
Render (short):
  Concealed: "John 6:35"
  Displayed: "[John 6:35]"
  Highlight: LifeModeCitation (underline)
  Hover: Virtual text "@bible:john.6.35"
```

**Missing Source:**
```
Citation: @bibtex:smith2020
  ↓ Query .lifemode/sources/smith2020.yaml
Result: File not found
  ↓ Error rendering
Displayed: "[Smith2020]"
  Highlight: LifeModeCitationMissing (orange wavy underline)
  Virtual text: "⚠️ Source not found"
  ↓ User: `gd` on citation
Error: "[LifeMode] ERROR: Source not found: smith2020"
```

### B.7 Keybinding Quick Reference

**Capture & Narrowing:**
- `<leader>nc` — New node (capture)
- `<leader>nn` — Narrow to node at cursor
- `<leader>nw` — Widen from narrow
- `<leader>nj` — Jump between narrow ↔ context
- `<leader>nt` — Toggle transclusion visibility (conceal/explicit)

**Sidebar:**
- `<leader>ns` — Toggle sidebar
- `za` (in sidebar) — Toggle section fold
- `<CR>` (in sidebar) — Jump to link
- `t` (in sidebar) — Transclude from link
- `l` (in sidebar) — Link nodes (potential connections)
- `d` (in sidebar) — Dismiss suggestion
- `D` (in sidebar) — Dismiss all suggestions

**Navigation:**
- `gd` — Jump to source (citation, transclusion, node reference)
- `<C-o>` — Jump back (standard vim jumplist)
- `/` (insert mode) — Slash command palette

**Commands:**
- `:LifeModeNewNode` — Create new capture node
- `:LifeModeNarrow` — Narrow to current node
- `:LifeModeWiden` — Widen from narrow
- `:LifeModeJumpContext` — Jump to context
- `:LifeModeSidebar` — Toggle sidebar
- `:LifeModeRebuildIndex` — Full vault index rebuild
- `:LifeModeRefreshTransclusions` — Invalidate transclusion cache
- `:LifeModeToggleTransclusionConceal` — Toggle concealment mode
- `:LifeModeOpenBib` — Open generated .bib file
- `:LifeModeGenerateBib` — Regenerate all .bib files
- `:LifeModeImportBib <file>` — Import .bib to YAML sources
- `:LifeModeFixFrontmatter` — Repair malformed frontmatter
- `:LifeModeValidateVault` — Scan for errors

### B.8 Configuration Schema

**Minimal Setup:**
```lua
require('lifemode').setup({
  vault_path = "~/vault"
})
```

**Full Configuration:**
```lua
require('lifemode').setup({
  vault_path = "~/vault",

  sidebar = {
    width_percent = 30,
    position = "right",
    default_folded = true,
    debounce_ms = 500,
  },

  transclusion = {
    max_depth = 10,
    cache_enabled = true,
    lazy_viewport = true,
    async_queries = true,
    query_timeout_ms = 2000,
    conceal = true,
    cycle_behavior = "error",  -- or "warn"
  },

  citation_schemes = {
    exclude = {},  -- e.g., {'bibtex'} to disable
    paths = {},    -- additional scheme directories
  },

  slash_commands = {
    -- user-extensible
  },

  keymaps = {
    new_node = "<leader>nc",
    narrow = "<leader>nn",
    widen = "<leader>nw",
    jump_context = "<leader>nj",
    sidebar = "<leader>ns",
    toggle_transclusion = "<leader>nt",
  },

  index = {
    auto_update = true,
    debounce_ms = 500,
  },
})
```
