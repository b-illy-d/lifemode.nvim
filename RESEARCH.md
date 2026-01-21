# Research: Robbing the Egyptians

This document contains deep implementation details, UI/UX patterns, and concrete code insights from three major influences: **Org-mode**, **Roam Research**, and **TiddlyWiki**. We're not just listing features - we're documenting exactly how they work so we can steal the best patterns and adapt them to LifeMode.

---

## 1. Org-mode: Power User Affordances

### 1.1 Visibility Cycling

**What It Does:**
Org-mode provides two types of cycling through outline visibility states with a single key.

**Exact Keybindings:**
- `TAB` - Local cycling at current headline:
  - FOLDED → CHILDREN → SUBTREE → (repeat)
- `S-TAB` - Global cycling across entire document:
  - OVERVIEW → CONTENTS → SHOW ALL → (repeat)
- `C-u TAB` - Global cycle from anywhere (without moving cursor)

**Implementation Details:**
- Core function: `org-fold.el` module
- Uses `org-flag-region` for performance (marks regions as invisible)
- State stored in text properties, not buffer modification
- Efficient for large documents (doesn't re-parse)

**Adaptable Pattern:**
- `<Tab>` in normal mode: Cycle fold state at cursor
- `<leader>zz` or `<S-Tab>`: Global cycle through document
- Use Neovim's native foldmethod with extmarks for state tracking
- Three-state local cycle, three-state global cycle

---

### 1.2 Narrowing (True Focus)

**What It Does:**
Temporarily restrict buffer view to a single subtree, making it the entire context. Everything else exists but is hidden. True focus without losing document state.

**Exact Keybindings:**
- `C-x n s` - Narrow to subtree
- `C-x n w` - Widen (restore full buffer)
- Speed command: `s` at headline start (one-key narrowing)

**Implementation Details:**
- Buffer-local narrowing: sets `(point-min)` and `(point-max)`
- Original content unchanged, only view restricted
- Functions respect narrowing automatically
- Undo/redo works across narrow/widen operations

**Adaptable Pattern:**
- `<leader>n` - Narrow to current node (hide everything else)
- `<leader>w` - Widen back to full document
- Neovim implementation: Use marks or window-local view state
- Maintain full buffer in memory, restrict visible region only
- Side panels automatically filter to narrowed context

---

### 1.3 Sparse Trees (Filtered Views)

**What It Does:**
Show only nodes matching a search query, plus their parent hierarchy for context. Non-destructive filtering that preserves document structure.

**Boolean Logic Syntax:**
- `+boss+urgent-project1` - AND (+include) and NOT (-exclude)
- `Kathy|Sally` - OR logic
- Stackable filters: Apply multiple in sequence
- Always shows parent hierarchy (controlled by `org-show-hierarchy-above`)

**Implementation Details:**
- Creates "sparse tree" view by folding non-matching branches
- Highlights matching entries
- Preserves full document state
- Fast: doesn't create new buffer or modify document

**Adaptable Pattern:**
- `/` or `<leader>f` - Open filter/search prompt
- Support: `+tag1+tag2-tag3` and `term1|term2` syntax
- Always show ancestor chain to root for context
- Use Neovim's concealment or folding to hide non-matches
- Multiple active filters stack (intersection of results)

---

### 1.4 Database Layer (org-roam)

**What It Does:**
Maintains a persistent SQLite index alongside plain-text org files. Enables fast queries without re-parsing the entire corpus.

**Architecture:**
- Dual representation: Plain-text files (user-editable) + SQLite (queryable)
- Library: `emacsql` for SQLite interaction
- Updates on file save (async)

**Schema (Simplified):**
```sql
nodes: id, file, title, level, todo, tags, properties
links: source_id, target_id, type (id/fuzzy/cite)
refs: node_id, ref_key, ref_type
aliases: node_id, alias
tags: node_id, tag
```

**Key Abstractions:**
- `org-roam-db-query` - SQL query interface
- `org-roam-db-sync` - Manual reindex
- Incremental updates: Only re-parse changed files

**Adaptable Pattern:**
- SQLite database in `~/.local/share/nvim/lifemode.db`
- Schema: nodes, edges (bidirectional), tags, metadata
- Update on BufWritePost (async using vim.loop)
- Expose `:LifeModeQuery [SQL]` for power users
- Fast lookups: backlinks, graph queries, tag searches

---

### 1.5 Agenda Views

**What It Does:**
Composite views that aggregate data from multiple files without modifying them. Query-based dynamic documents.

**View Types:**
1. **Calendar/Timeline** - See all entries by date
2. **TODO/Task lists** - All tasks across files
3. **Tag search** - All entries with specific tags
4. **Text search** - Full-text matching
5. **Stuck projects** - Projects with no next actions
6. **Custom views** - User-defined queries

**Implementation Details:**
- Opens in separate buffer (doesn't modify source files)
- "Skip functions" for conditional filtering
- Jump back to source file from agenda entry
- Supports bulk operations (change state, add tags)

**Adaptable Pattern:**
- `<leader>a` - Open agenda menu
- Aggregate views across all LifeMode files
- Floating window with results
- `<CR>` jumps to source node
- Pre-built views: tasks, recent, tags, citations
- Custom view syntax: `view:"tag:paper & status:draft"`

---

## 2. Roam Research: Graph-First Thinking

### 2.1 Block-Level References

**What It Does:**
Every block (paragraph, list item, heading) has a unique ID and can be referenced/transcluded individually.

**Syntax:**
- Block reference: `((GGv3cyL6Y))` - 9-character UID
- Creates backlink to source block
- Transcluded blocks update when source changes

**Data Model:**
- **Dual-ID architecture**:
  - Internal: entity-id (integer, Datascript)
  - Public: uid (string, user-facing)
- Each block stores:
  - `:block/uid` - The 9-char identifier
  - `:block/string` - The content
  - `:block/order` - Position among siblings
  - `:block/page` - Root page reference
  - `:block/parents` - ALL ancestor blocks (not just direct parent)
  - `:block/children` - Direct child blocks only

**Why It Works:**
- UIDs are short enough to remember and type
- Stable across renames/moves
- Internal ID enables fast queries
- Public ID enables human sharing

**Adaptable Pattern:**
- Generate 9-char alphanumeric UIDs (base62: `[a-zA-Z0-9]`)
- Frontmatter: `uuid: GGv3cyL6Y`
- Extmarks: Store UUID as metadata on heading line
- Database: `uuid` column (TEXT, indexed, unique)
- Triple storage: Frontmatter (source of truth) + Extmarks (fast lookup) + DB (queries)
- Reference syntax: `{{GGv3cyL6Y}}` for transclusion
- Link syntax: `[[GGv3cyL6Y]]` or `[[Title::GGv3cyL6Y]]` for explicit UUID links

---

### 2.2 Bidirectional Links

**What It Does:**
When you write `[[Note B]]` in Note A, Note B automatically knows about this incoming link.

**Syntax:**
- Forward link: `[[note name]]` or `[[note alias]]`
- Backlinks appear in "Links to this Note" section
- Shows context snippet (surrounding text)

**Implementation:**
- Forward links parsed from content
- Backlinks auto-generated (reverse lookup)
- Stored in graph database

**Adaptable Pattern:**
- Parse `[[Title]]` or `[[Title::UUID]]` during indexing
- Store edges table: `(source_uuid, target_uuid, type)`
- For each node, query: `SELECT source_uuid FROM edges WHERE target_uuid = ?`
- Display in "Backlinks" fold section at bottom of node
- Show 1-2 lines of context around the link
- Click to jump to source location (file + line number)

---

### 2.3 Graph Database (Datomic/Datascript)

**What It Does:**
Roam uses Datascript (ClojureScript port of Datomic), an immutable in-memory graph database. Enables powerful queries across the entire knowledge graph.

**Datom Structure:**
```clojure
[entity-id attribute value transaction-id]
```

**Example Data:**
```clojure
[123 :block/string "This is a note" 456]
[123 :block/uid "GGv3cyL6Y" 456]
[123 :block/children 124 456]
[124 :block/parents 123 456]
```

**Forest Model:**
- Pages are roots (no parents)
- Paragraphs are children of pages
- Nested bullets/headings create depth
- Bidirectional pointers:
  - `:block/children` - List of direct children
  - `:block/parents` - List of ALL ancestors (not just parent)

**Datalog Query Example:**
```clojure
[:find ?title ?count
 :where
 [?page :node/title ?title]
 [?link :block/page ?page]
 [?link :block/refs ?ref]]
```
(Find all pages and count their references)

**Adaptable Pattern:**
- **SQLite instead of Datascript** (simpler, better Lua bindings)
- Schema:
  ```sql
  nodes: uuid, file_path, title, content, created, modified
  edges: from_uuid, to_uuid, edge_type (link/child/cite)
  tags: node_uuid, tag
  ancestors: node_uuid, ancestor_uuid, depth
  ```
- **Bidirectional edges**: Store both directions explicitly
  - Insert `(A, B, 'link')` AND `(B, A, 'backlink')`
- **Ancestor tracking**: Materialize ancestor paths for fast upward queries
- **Query DSL**: Expose simple query syntax that compiles to SQL
  - `query: backlinks(uuid)` → `SELECT from_uuid FROM edges WHERE to_uuid = ? AND edge_type = 'link'`

---

### 2.4 Daily Notes Materialization

**What It Does:**
Roam auto-creates a note for each day. Becomes the default entry point and organizational anchor.

**Patterns:**
- Automatically opened on app start
- Template-based content (optional)
- Link to yesterday/tomorrow
- Users develop two patterns:
  1. **Context-first**: Tag today's work with project links
  2. **Daily-first**: View project by finding all daily notes that mention it

**Adaptable Pattern:**
- **Virtual date nodes**: Don't create files upfront
- Filter all nodes by `created` field: `created: 2026-01-21`
- `:Today` command: Filter to today's created/modified nodes
- `:Yesterday`, `:LastWeek`, etc.
- Optional template: Create `~/.config/nvim/lifemode/templates/daily.md`
- Actual date file created only on first write

---

### 2.5 Sidebar Architecture

**What It Does:**
Persistent auxiliary panels for navigation and multi-note viewing. Doesn't steal main editing space.

**Layout:**
- **Left Sidebar**: Navigation tree
  - Daily Notes (chronological)
  - Graph Overview (visual)
  - All Pages (alphabetical)
  - Shortcuts (user-defined)
  - Collapsible sections
- **Right Sidebar**: Multi-panel note viewing
  - Open multiple notes side-by-side
  - Compare/reference without losing context
  - Independent scroll and fold states

**State Persistence:**
- Open/closed state saved
- Panel arrangement persisted
- Scroll positions maintained

**Adaptable Pattern:**
- `<leader>e` - Toggle left panel (NvimTree-style file browser)
- `<leader>o` - Toggle right panel (reference window)
- Left panel sections (accordion-style folds):
  - Recent nodes
  - Tag tree
  - Backlinks to current node
  - Outgoing links from current node
- Right panel:
  - Split horizontally for multi-note viewing
  - `:LifeModeOpen <uuid>` in right panel
  - Independent buffer per pane
- Save state in session file

---

### 2.6 Search & Navigation

**What It Does:**
Fast, global search with keyboard-driven UI. Fuzzy matching and live filtering.

**Keybindings:**
- `CMD-U` - Universal search (all nodes)
- `CMD-DOWN` - Expand children in outline
- `CMD-UP` - Collapse children
- Autocomplete during typing

**Features:**
- Fuzzy match on title and content
- Live preview of results
- Jump to match within node

**Adaptable Pattern:**
- `<leader>ff` - Fuzzy find nodes (Telescope integration)
- `<leader>fg` - Live grep across all content
- `<leader>fb` - Backlinks picker (Telescope)
- `<leader>ft` - Tags picker
- `<CR>` opens node, `<C-v>` opens in vsplit, `<C-x>` in split
- Use Telescope extensions for node-specific pickers:
  - `telescope.extensions.lifemode.nodes`
  - `telescope.extensions.lifemode.backlinks`

---

## 3. TiddlyWiki: Transclusion Mastery

### 3.1 Transclusion Syntax Hierarchy

**What It Does:**
TiddlyWiki has five levels of transclusion, from simple to advanced.

**Syntax Hierarchy:**

1. **Basic**: `{{tiddler}}`
   - Include entire tiddler content

2. **Field-specific**: `{{tiddler!!field}}`
   - Include specific field only (e.g., `{{MyNote!!tags}}`)

3. **Templated**: `{{tiddler||Template}}`
   - Apply template to content (pipe operator)

4. **Parameterized**: `{{tiddler|param1|param2}}`
   - Pass positional parameters to transclusion

5. **Filtered**: `{{{ [filter-expression] }}}`
   - Triple braces: Dynamic query-based transclusion
   - Example: `{{{ [tag[TODO]first[5]] }}}` (first 5 TODO items)

**Adaptable Pattern for LifeMode:**
- `{{uuid}}` - Basic transclusion (entire node)
- `{{uuid:depth}}` - Transclusion with depth limit (e.g., `{{GGv3cyL6Y:2}}` = 2 levels deep)
- `{{uuid?field}}` - Specific field (e.g., `{{uuid?title}}`, `{{uuid?content}}`)
- `{{{ [filter-expression] }}}` - Query-based dynamic lists
  - Example: `{{{ tag:paper status:draft }}}` (all draft papers)

---

### 3.2 Cycle Detection Algorithm

**What It Does:**
Prevents infinite recursion when Node A transcludes Node B which transcludes Node A.

**TiddlyWiki's Approach:**
- **Recursion marker signature**: `{currentTiddler|title|field|index|subTiddler}`
  - Tracks the full transclusion path, not just UUIDs
  - Allows same node to appear multiple times if context differs
- **Two-phase processing**:
  1. **Collection phase**: Gather transclusion tree (max 50 transclusions)
  2. **Resolution phase**: Expand content
- **Loop detection**: If signature appears twice in ancestry, render error widget

**Error Widget:**
```html
<div class="tc-error">Recursive transclusion error</div>
```

**Adaptable Pattern:**
- **Visited set with depth tracking**:
  ```lua
  visited = {
    [uuid] = depth
  }
  ```
- **Max depth**: 10 levels
- **Max transclusions per render**: 100
- **Cycle detection**: If `uuid` in `visited` and `visited[uuid] < current_depth`, error
- **Error rendering**: Replace `{{uuid}}` with `⚠️ Cycle detected: {{uuid}}`
- **Context-aware**: Same UUID can appear in different branches

**Implementation Sketch:**
```lua
function expand_transclusions(content, visited, depth)
  if depth > 10 then return "⚠️ Max depth reached" end

  for match in content:gmatch("{{([^}]+)}}") do
    local uuid = parse_uuid(match)
    if visited[uuid] then
      content = content:gsub("{{" .. match .. "}}", "⚠️ Cycle: " .. uuid)
    else
      visited[uuid] = depth
      local node_content = get_node(uuid)
      local expanded = expand_transclusions(node_content, visited, depth + 1)
      content = content:gsub("{{" .. match .. "}}", expanded)
      visited[uuid] = nil
    end
  end

  return content
end
```

---

### 3.3 Filter Syntax for Dynamic Transclusion

**What It Does:**
TiddlyWiki filters are composable query operators that select and transform tiddlers.

**Core Operators:**

- **Selection**: `[tag[TagName]]` - Select by tag
- **Limiting**: `[first[N]]` - Take first N results
- **Counting**: `[count[]]` - Return count instead of items
- **Enumeration**: `[enlist{!!field}]` - Parse field as list
- **Sorting**: `[sort[field]]` - Order by field
- **Boolean**: `[tag[A]tag[B]]` - AND logic, `[tag[A]] [tag[B]]` - OR logic

**Soft Parameters:**
- `{!!field}` - Reference field from current tiddler (curly braces)
- `<variable>` - Reference variable (angle brackets)

**Example:**
```
{{{ [tag[Project]!tag[Archived]sort[modified]first[10]] }}}
```
(10 most recently modified non-archived projects)

**Adaptable Pattern:**
- **Query DSL**: `{{{ query-expression }}}`
- **Operators**:
  - `tag:value` - Filter by tag
  - `status:value` - Filter by field
  - `type:value` - Filter by node type
  - `-tag:value` - Exclusion (NOT)
  - `sort:field` - Sort by field
  - `first:N` - Limit results
- **Composition**: Space-separated = AND
- **Example**: `{{{ tag:paper status:draft sort:modified first:5 }}}`
  - "First 5 draft papers, most recent first"

---

### 3.4 Parameterized Transclusion

**What It Does:**
Pass parameters to transcluded content, enabling reusable templates.

**Procedures (TiddlyWiki v5.3+):**
```
\procedure greet(name:"World")
Hello, <<name>>!
\end
```

**Invocation:**
```
<<greet "Alice">>  → "Hello, Alice!"
<<greet>>          → "Hello, World!" (default)
```

**Slots ($fill widget):**
```
\procedure card(title)
<div class="card">
  <h3><<title>></h3>
  <$fill $name="content"/>
</div>
\end

<<card "My Title">>
  <$fill $name="content">
    This is the card body
  </$fill>
<</card>>
```

**Named vs Positional:**
- Positional: Fragile, order-dependent
- Named: Recommended for maintainability

**Adaptable Pattern:**
- **Template nodes**: Special node type with parameter definitions
- **Parameter syntax**: Frontmatter declares parameters
  ```yaml
  template: true
  params:
    - name: title
      default: "Untitled"
    - name: depth
      default: 1
  ```
- **Invocation**: `{{template-uuid | title="My Paper" | depth=2}}`
- **Replacement**: Use Lua string patterns to replace `${param}` in template content
- **Use cases**:
  - Bibliography entry formatting
  - Project status summaries
  - Repeated document structures

---

### 3.5 Navigation Architecture

**What It Does:**
TiddlyWiki manages navigation state independently of content. Supports multiple "views" of same content.

**StoryView Modes:**
- **classic** - Traditional wiki navigation
- **zoomin** - Animated transitions
- **pop** - Modal-style overlays
- **stacked** - Side-by-side panels

**History Management:**
- `$:/HistoryList` tiddler - LIFO navigation stack
- Stores: `{title, fromPageRect, scrollPosition}`
- Browser-style back/forward

**Navigator Widget:**
- Central state manager for TiddlyWiki navigation
- Handles: Open tiddler, close tiddler, navigate, edit mode
- Events: `tm-navigate`, `tm-close-tiddler`, etc.

**ActionNavigate:**
- Programmatic navigation
- Add to history or not (silent navigation)

**Adaptable Pattern:**
- **Jump list integration**: Use Neovim's native `<C-o>` / `<C-i>` for back/forward
- **Location list**: Store navigation history per window
  - `{file, line, col, timestamp}`
- **Marks**: Set mark before navigation (e.g., `mL` for "last LifeMode jump")
- **`:LifeModeBack` / `:LifeModeForward`**: Dedicated commands
- **State persistence**: Save jump list to session file
- **Commands**:
  - `:LifeModeOpen <uuid>` - Navigate to node (add to jump list)
  - `:LifeModeOpenSilent <uuid>` - Jump without history (like previews)
  - `:LifeModeHistory` - Show navigation history (Telescope picker)

---

## Concrete Patterns to Steal

### Keybinding Philosophy

**Single Key for State Cycling:**
- Org-mode: `TAB` cycles fold states
- Adapt: `<Tab>` cycles node fold (normal mode)

**Prefix for Variants:**
- Org-mode: `C-u TAB` for global cycle
- Adapt: `<leader>z` prefix for all fold operations

**Speed Commands:**
- Org-mode: Single key at headline start (no prefix needed)
- Adapt: When cursor on headline, map single keys: `o` (new child), `p` (promote), `d` (demote)

**Vim Conventions:**
- Use `<leader>` for LifeMode namespace
- Integrate with existing vim commands (`g`, `z`, `[`, `]`)

---

### Data Architecture

**Dual Representation:**
- Plain-text files (user-editable, version control, portable)
- Database index (fast queries, graph traversal)
- Keep in sync: Update index on BufWritePost

**Bidirectional Edges:**
- Store forward link: `A → B`
- Automatically create reverse: `B ← A`
- Query backlinks: Simple SELECT

**Triple Storage for IDs:**
1. **Frontmatter** - Source of truth (user can edit)
2. **Extmarks** - Fast lookup in buffer (ephemeral)
3. **Index** - Fast global queries (persistent)

**Ancestor Tracking:**
- Materialize ancestor paths: `ancestors(uuid) → [root, parent, grandparent, ...]`
- Enables: "Show all papers under this project" without recursion

---

### UI Patterns

**Accordion Sections:**
- Collapsible sections with persistent state
- Save open/closed state to session
- Visual hierarchy with indentation

**Context Preservation:**
- Filtered views always show ancestor chain
- Breadcrumbs: `Root > Project > Paper > Current Node`
- Never orphan results

**Multi-Panel Viewing:**
- Don't destroy main editing context
- Side panels for reference
- Independent scroll and fold states

**Floating Windows:**
- Telescope pickers for search/select
- Temporary overlays (don't rearrange splits)
- Quick access without layout disruption

---

### Transclusion Engine

**Marker-Based Cycle Detection:**
- Track full transclusion path (signatures), not just UUIDs
- Same node can appear in different contexts
- Error at boundary (don't crash, show marker)

**Lazy Evaluation:**
- Don't expand transclusions on file parse
- Expand on render only (buffer display)
- Cache expanded results per UUID

**Parameter Passing:**
- Support positional: `{{uuid | arg1 | arg2}}`
- Support named: `{{uuid | name="value" | depth=2}}`
- Named preferred for clarity

**Filter Composition:**
- Triple-brace syntax: `{{{ expression }}}`
- Query DSL compiles to SQL or Lua filter
- Returns list of UUIDs or content blocks

---

### Query/Filter Syntax

**Boolean Logic:**
- `+include` (AND)
- `-exclude` (NOT)
- `term1|term2` (OR)
- Example: `+paper+published-journal|conference`

**Composable Operators:**
- `tag:value` - Match tag
- `type:value` - Match node type
- `first:N` - Limit results
- `sort:field` - Order by field
- `count` - Return count instead of items

**Soft Parameters:**
- Reference current context in queries
- `{current.tag}` - Tag of current node
- `{current.uuid}` - UUID of current node

**Stackable Filters:**
- Apply multiple filters in sequence
- Each filter narrows results
- `/filter1 /filter2 /filter3` (intersection)

---

## Implementation Insights

### From vim-org-mode

**Repo:** [jceb/vim-orgmode](https://github.com/jceb/vim-orgmode)

**Key Features:**
- Pure Vimscript implementation
- Tree-sitter parser for org grammar
- TAB-based cycling: `<Plug>OrgToggleFolding`
- Supports reverse cycling with S-Tab
- Agenda views (basic)

**Limitations:**
- No database layer (file-based only)
- Limited query capabilities
- Single-file focus

**Takeaway:**
- Good reference for vim integration patterns
- Fold cycling implementation
- Don't replicate single-file limitations

---

### From nvim-orgmode

**Repo:** [nvim-orgmode/orgmode](https://github.com/nvim-orgmode/orgmode)

**Key Features:**
- Tree-sitter integration: `:Org install_treesitter_grammar`
- Modern Lua implementation
- Tag inheritance from parent headlines
- Keybindings: `<Leader>oa` for agenda
- Priorities and TODO states

**Limitations:**
- Still file-centric (no database)
- No block-level references
- No transclusion

**Takeaway:**
- Tree-sitter for parsing (fast, accurate)
- Lua plugin architecture
- Async processing for large files

---

### From Logseq

**Repo:** [logseq/logseq](https://github.com/logseq/logseq)

**Key Features:**
- Privacy-first: Local Markdown/Org files
- Block-based outliner
- Bidirectional links: `[[Page]]` and `#tag`
- Datalog-style queries
- Plugin ecosystem (ClojureScript)
- Graph visualization
- Active development (not archived)

**Architecture:**
- Electron app (web tech)
- SQLite + Datascript hybrid
- File-per-page model
- Block references: `((uuid))`

**Takeaway:**
- Best reference for Roam-like features
- Open source, actively maintained
- Study: Query language, graph rendering, plugin API
- Don't replicate: Electron overhead, page-first model

---

### From Athens Research

**Repo:** [athensresearch/athens](https://github.com/athensresearch/athens) (Archived)

**Key Features:**
- Superior graph visualization (3D rendering)
- Real-time collaboration (multiplayer editing)
- Open-source Roam alternative

**Status:**
- **Archived** - No longer maintained
- Code available for reference

**Takeaway:**
- Graph rendering techniques (D3.js-based)
- Collaborative editing architecture (CRDTs)
- Don't replicate: Clojure stack, archived project

---

### From TiddlyWiki Core

**Repo:** [Jermolene/TiddlyWiki5](https://github.com/Jermolene/TiddlyWiki5)

**Key Files:**
- `core/modules/widgets/transclude.js` - Main transclusion widget
- `core/modules/parsers/` - Wikitext parser
- `core/modules/filters/` - Filter operators

**Transclusion Implementation:**
- Recursive widget tree
- Refresh optimization: Only re-render on source change
- Parser type comparison for cache invalidation
- Slot mechanism for parameterized content

**Takeaway:**
- Transclusion engine architecture
- Cycle detection algorithm
- Filter composition patterns
- Widget-based rendering (similar to Neovim extmarks/virtual text)

---

## Critical Design Decisions

### Database: SQLite

**Why:**
- Better Lua bindings than Datascript
- Standard, well-understood
- Local file (no server)
- Fast full-text search (FTS5)

**Schema:**
```sql
CREATE TABLE nodes (
  uuid TEXT PRIMARY KEY,
  file_path TEXT NOT NULL,
  title TEXT,
  content TEXT,
  created INTEGER,
  modified INTEGER,
  type TEXT
);

CREATE TABLE edges (
  from_uuid TEXT NOT NULL,
  to_uuid TEXT NOT NULL,
  edge_type TEXT NOT NULL,
  context TEXT,
  PRIMARY KEY (from_uuid, to_uuid, edge_type)
);

CREATE TABLE tags (
  node_uuid TEXT NOT NULL,
  tag TEXT NOT NULL,
  PRIMARY KEY (node_uuid, tag)
);

CREATE TABLE ancestors (
  node_uuid TEXT NOT NULL,
  ancestor_uuid TEXT NOT NULL,
  depth INTEGER NOT NULL,
  PRIMARY KEY (node_uuid, ancestor_uuid)
);

CREATE VIRTUAL TABLE nodes_fts USING fts5(title, content, uuid);
```

---

### File Format: Markdown + YAML Frontmatter

**Why Markdown:**
- Universal, readable
- Existing tooling (formatters, linters)
- Git-friendly

**Why YAML Frontmatter:**
- Clean separation of metadata and content
- Standard (Jekyll, Hugo, Obsidian)
- Easy to parse

**Example Node:**
```markdown
---
uuid: GGv3cyL6Y
title: My Research Note
created: 2026-01-21
modified: 2026-01-21
tags: [research, ai, paper]
type: paper
---

# My Research Note

This is the content. It can contain [[links]] and {{transclusions}}.

## Subsection

More content here.
```

---

### Keybinding Namespace: `<leader>l`

**Mnemonic:** "l" for **L**ifeMode

**Core Bindings:**
- `<leader>ln` - New node
- `<leader>lo` - Open node (Telescope)
- `<leader>lb` - Backlinks
- `<leader>lf` - Filter/search
- `<leader>ll` - Follow link under cursor
- `<leader>li` - Insert link
- `<leader>lt` - Transclusion at cursor
- `<leader>la` - Agenda view
- `<leader>le` - Toggle explorer (left panel)
- `<leader>lv` - Toggle reference panel (right panel)

**Folding (reuse vim conventions):**
- `<Tab>` - Cycle fold at cursor
- `<S-Tab>` - Global fold cycle
- `zo` / `zc` - Open/close fold (standard vim)
- `zR` / `zM` - Open/close all (standard vim)

---

## Sources

### Org-mode
- [Org Mode Visibility Cycling](https://orgmode.org/manual/Visibility-Cycling.html)
- [Org Mode Sparse Trees](https://orgmode.org/manual/Sparse-Trees.html)
- [Org Mode Narrowing](https://orgmode.org/manual/Narrowing.html)
- [Org Mode Agenda Views](https://orgmode.org/manual/Agenda-Views.html)
- [Org-roam User Manual](https://www.orgroam.com/manual.html)
- [Vim-orgmode GitHub](https://github.com/jceb/vim-orgmode)
- [Nvim-orgmode GitHub](https://github.com/nvim-orgmode/orgmode)
- [Org-roam GitHub](https://github.com/org-roam/org-roam)
- [Tree-sitter-org Grammar](https://github.com/emiasims/tree-sitter-org)

### Roam Research
- [Graph Databases, RoamResearch, and PKM](https://louisshulman.medium.com/graph-databases-roamresearch-and-personal-knowledge-management-61fe5c3eac4b)
- [Deep Dive Into Roam's Data Structure](https://www.zsolt.blog/2021/01/Roam-Data-Structure-Query.html)
- [A Short History of Bi-Directional Links](https://maggieappleton.com/bidirectionals)
- [Roam Research Datalog Cheatsheet](https://gist.github.com/2b3pro/231e4f230ed41e3f52e8a89ebf49848b)
- [Datalog Queries for Roam Research](https://davidbieber.com/snippets/2020-12-22-datalog-queries-for-roam-research/)
- [GitHub - Athens Research](https://github.com/athensresearch/athens) (archived)
- [GitHub - Logseq](https://github.com/logseq/logseq) (active, best reference)
- [Roam Research Beginner's Guide](https://thesweetsetup.com/a-thorough-beginners-guide-to-roam-research/)

### TiddlyWiki
- [TiddlyWiki TranscludeWidget](https://tiddlywiki.com/static/TranscludeWidget.html)
- [Grok TiddlyWiki - Transclusion](https://groktiddlywiki.com/static/Transclusion.html)
- [Grok TiddlyWiki - Filters and Transclusions](https://groktiddlywiki.com/static/Filters%20and%20Transclusions.html)
- [TiddlyWiki Procedures Documentation](https://tiddlywiki.com/static/Procedures.html)
- [TiddlyWiki Parameters Widget](https://tiddlywiki.com/static/ParametersWidget.html)
- [TiddlyWiki Navigator Widget](https://tiddlywiki.com/static/NavigatorWidget.html)
- [TiddlyWiki Filter Syntax](https://tiddlywiki.com/static/Filter%20Syntax.html)
- [TiddlyWiki GitHub - transclude.js](https://github.com/Jermolene/TiddlyWiki5/blob/master/core/modules/widgets/transclude.js)

### Additional References
- [Obsidian](https://obsidian.md/) - Markdown-based, local-first, plugin ecosystem
- [Notion](https://www.notion.so/) - Block-based, database views, transclusion
- [Dendron](https://www.dendron.so/) - VSCode extension, hierarchical notes
- [Foam](https://foambubble.github.io/foam/) - VSCode + Markdown, Roam-like
- [Neuron](https://neuron.zettel.page/) - Zettelkasten, static site generation
