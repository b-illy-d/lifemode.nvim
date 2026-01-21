# LifeMode (Neovim) — Product Spec (Architect Draft)

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
1) compute today’s directory: `YYYY/MM-Mmm/DD/` (create if missing)
2) create a new node file: `<uuid>.md`
3) write frontmatter (`id`, `created`, optional `type`)
4) open the file and **narrow** to the root subtree (effectively: the file is the node)

Rationale: capture must show only the node being written; chronology is stored without implying semantic relation.

### 4.2 Focus & Navigation
- True narrowing is the primary focus mechanic.
- Jump actions should always exist to:
  - jump to node in original context
  - jump to node in narrowed view
  - jump “through” relations (backlinks/transclusions)

### 4.3 Side Window (passive, accordion)
- Updates on **node change** (not every cursor move).
- Accordion sections:
  1) Context (themes, inferred type, key properties)
  2) Citations (in-node; other nodes citing same sources)
  3) Relations (backlinks/transclusions; creative traversal affordances)
- Quick actions: jump, narrow, transclude, manage source, embed view

### 4.4 Slash Commands
- Unified slash-command palette to avoid keybinding explosion.
- Must cover:
  - insert/transclude
  - change/infer type
  - attach/normalize citations
  - embed views
  - manage sources (jump/edit)

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

## 9. Open Questions (remaining)
- Node UUID persistence mechanism choice (hidden marker vs property line vs extmark/index-only)
- Canonical citation scheme DSL: exact syntax, override/packaging model
- BibTeX UX specifics: default edit target (source yaml), optional edit `.bib`, file layout, sync strategy
- View/query DSL and view embedding syntax
- Creative-relation discovery surfaces: traversal affordances + prioritization (not “machine conclusions”)
