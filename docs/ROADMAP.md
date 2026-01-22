# LifeMode Implementation Roadmap

Each phase represents **approximately one git commit** (10-500 lines). Phases marked **[MVP]** are required for minimum viable product.

---

## CRITICAL ALWAYS READ AND APPLY THIS SECTION: How to develop in Phases:

### Testing Strategy

EACH PHASE includes **Test:** section with acceptance criteria.

**Unit tests:**
- Where needed, no need for 100% coverage, be tactical
- Domain layer: pure functions, no mocks
- Test: `lua/lifemode/domain/*_spec.lua`

**Integration tests:**
- Should be plenty of these, probably at least a few per phase, once we get going
- Application layer: mock infrastructure
- Test: `lua/lifemode/tests/*_spec.lua`

**Manual QA:**
- UI layer: smoke tests, user workflows
- Test: Example vault, common operations
- Document How to QA per phase in QA.md

**Tools:**
- `plenary.nvim` for test runner
- `luassert` for assertions
- CI: GitHub Actions on PR

### Architecture Enforcement

Ensure layer boundaries via import checks:

```lua
-- In tests/check_imports.lua
assert_no_imports("domain", {"infra", "app", "ui"})
assert_no_imports("infra", {"app", "ui"})
assert_no_imports("app", {"ui"})
```

Run on pre-commit hook.

### Documentation Plan

**Phase 1-13 (MVP):**
- Inline code comments (Lua LSP annotations)
- README with quickstart
- Basic command reference

**Phase 14-38 (MVP complete):**
- Full `doc/lifemode.txt` help file
- Architecture guide (ARCHITECTURE.md reference)
- Example vault with samples
- TUTORIAL.md with step-by-step instructions for learning all the features with the example vault.

---

Here begin the tasks in Phases

## Foundation Layer

### Phase 1: Result Type & Utilities **[MVP]** REVIEW (01/21/2026)
**~50 lines | `lua/lifemode/util.lua`**

Build error-handling primitives.

```lua
Ok(value) → {ok = true, value = value}
Err(error) → {ok = false, error = error}
```

**Tasks:**
- Implement `Ok()` and `Err()` constructors
- Add `Result:unwrap()` and `Result:unwrap_or(default)`
- UUID v4 generator (8-4-4-4-12 format)
- ISO date parser `parse_date(str) → timestamp`

**Test:** Create Result, chain operations, generate UUIDs

---

### Phase 2: Configuration Schema **[MVP]** REVIEW (01/21/2026)
**~80 lines | `lua/lifemode/config.lua`**

Define user-facing config with validation.

```lua
{
  vault_path = "~/vault",
  sidebar = { width_percent = 30 },
  keymaps = { ... }
}
```

**Tasks:**
- Config table with defaults
- `validate_config(user_config)` → merge with defaults or error
- Required field validation (`vault_path` must exist)
- Export `get(key)` accessor

**Test:** Valid config merges, invalid config errors

---

### Phase 3: Plugin Entry Point **[MVP]** REVIEW (01/21/2026)
**~40 lines | `lua/lifemode/init.lua`**

Bootstrap the plugin.

```lua
require('lifemode').setup({ vault_path = "~/notes" })
```

**Tasks:**
- `setup(opts)` function
- Call `config.validate_config(opts)`
- Store validated config globally
- Register autocommands group

**Test:** Setup succeeds with valid config, fails with invalid

---

## Domain Layer (Pure Logic)

### Phase 4: Node Value Object **[MVP]** REVIEW (01/21/2026)
**~100 lines | `lua/lifemode/domain/types.lua`**

Define immutable Node structure.

```lua
Node = {
  id: UUID,
  content: string,
  meta: {created, modified, type?, ...},
  bounds: {file, lines}
}
```

**Tasks:**
- Node constructor with validation
- Required fields: `id`, `meta.created`
- `Node.new(content, meta)` → `Result<Node>`
- Deep copy helper (immutability)

**Test:** Valid node creates, invalid node errors

---

### Phase 5: Node Operations (Create) **[MVP]** REVIEW (01/21/2026)
**~120 lines | `lua/lifemode/domain/node.lua`**

Core node creation logic (pure, no I/O).

**Tasks:**
- `create(content, meta)` → `Result<Node>`
  - Generate UUID
  - Validate required fields
  - Set created/modified timestamps
- `validate(node)` → `Result<Node>` (check field types, UUIDs)
- `to_markdown(node)` → `string` (serialize with frontmatter)

**Test:** Create node, serialize to markdown, validate

---

### Phase 6: Node Parsing **[MVP]** REVIEW (01/21/2026)
**~150 lines | `lua/lifemode/domain/node.lua`**

Parse markdown files back into Node objects.

**Tasks:**
- `parse(text)` → `Result<Node>`
  - Extract YAML frontmatter (between `---` delimiters)
  - Parse YAML into meta table
  - Extract content (everything after frontmatter)
  - Validate structure
- Handle malformed frontmatter (return Err with details)

**Test:** Parse valid markdown, handle malformed YAML

---

## Infrastructure Layer (I/O Adapters)

### Phase 7: Filesystem Write **[MVP]** REVIEW (01/21/2026)
**~90 lines | `lua/lifemode/infra/fs/write.lua`**

Safe file writing with error handling.

**Tasks:**
- `write(path, content)` → `Result<()>`
  - Create parent directories if missing
  - Write atomically (temp file + rename)
  - Handle permission errors
- `mkdir(path)` → `Result<()>` (recursive)
- `exists(path)` → `boolean`

**Test:** Write file, create dirs, handle errors

---

### Phase 8: Filesystem Read **[MVP]** REVIEW (01/22/2026)
**~70 lines | `lua/lifemode/infra/fs/read.lua`**

**Tasks:**
- `read(path)` → `Result<string>`
- `mtime(path)` → `Result<number>` (modification time)
- Handle missing files, permission errors

**Test:** Read file, get mtime, handle errors

---

### Phase 9: Date Path Computation **[MVP]** REVIEW (01/22/2026)
**~60 lines | `lua/lifemode/infra/fs/path.lua`**

Compute date-based directory paths.

**Tasks:**
- `date_path(vault_root, date)` → `string`
  - Format: `{vault}/YYYY/MM-Mmm/DD/`
  - Example: `~/vault/2026/01-Jan/21/`
- `resolve(vault_root, relative_path)` → `string` (absolute path)

**Test:** Correct path format, month abbreviations

---

## Application Layer (Orchestration)

### Phase 10: Capture Node Use Case **[MVP]** REVIEW (01/22/2026)
**~130 lines | `lua/lifemode/app/capture.lua`**

First complete workflow: create and save a new node.

**Tasks:**
- `capture_node()` → `Result<Node>`
  1. Compute date path for today
  2. Create node with `domain.node.create`
  3. Serialize to markdown
  4. Write to `{date_path}/{uuid}.md`
  5. Return node
- Error handling at each step

**Test:** End-to-end capture, file exists on disk

---

### Phase 11: Open Node in Buffer **[MVP]** REVIEW (01/22/2026)
**~80 lines | `lua/lifemode/infra/nvim/buf.lua`**

Neovim buffer operations.

**Tasks:**
- `open(file_path)` → `Result<bufnr>`
  - Use `vim.cmd.edit()` or `nvim_open_buf()`
  - Focus buffer
- `get_lines(bufnr, start, end)` → `string[]`
- `set_lines(bufnr, start, end, lines)` → `Result<()>`

**Test:** Open file, read lines, modify lines

---

## UI Layer (Commands)

### Phase 12: NewNode Command **[MVP]** REVIEW (01/22/2026)
**~50 lines | `lua/lifemode/ui/commands.lua`**

Expose capture workflow as command.

**Tasks:**
- `:LifeModeNewNode` command
  - Call `app.capture.capture_node()`
  - Open file in buffer (`infra.nvim.buf.open`)
  - Notify success or error
- User notification with vim.notify

**Test:** Run command, file created, buffer opens

---

### Phase 13: Keymaps Setup **[MVP]** REVIEW (01/22/2026)
**~40 lines | `lua/lifemode/ui/keymaps.lua`**

**Tasks:**
- `<leader>nc` → `:LifeModeNewNode`
- Register in `setup()`
- Respect user config (`keymaps` table)

**Test:** Keymap triggers command

---

## Extmarks & Narrowing

### Phase 14: Extmark Tracking **[MVP]** TODO
**~110 lines | `lua/lifemode/infra/nvim/extmark.lua`**

Track node boundaries in buffers.

**Tasks:**
- `set(bufnr, line, metadata)` → `Result<extmark_id>`
  - Namespace: `lifemode_nodes`
  - Store UUID in metadata
- `query(bufnr, line)` → `Result<metadata>`
- `delete(bufnr, extmark_id)` → `Result<()>`
- `get_node_at_cursor()` → `Result<{uuid, start, end}>`

**Test:** Set extmark, query by line, delete

---

### Phase 15: Parse Buffer for Nodes **[MVP]** TODO
**~100 lines | `lua/lifemode/app/parse_buffer.lua`**

Identify node boundaries in open buffers.

**Tasks:**
- `parse_and_mark_buffer(bufnr)` → `Result<Node[]>`
  - Read buffer lines
  - Parse frontmatter to find node boundaries
  - Create extmark at frontmatter line with UUID metadata
  - Store node range in extmark
- Autocommand: `BufReadPost *.md` → parse buffer

**Test:** Open multi-node file, extmarks created

---

### Phase 16: Narrow to Node **[MVP]** TODO
**~140 lines | `lua/lifemode/app/narrow.lua`**

True narrowing: focus on single node subtree.

**Tasks:**
- `narrow_to_current()` → `Result<()>`
  1. Get node at cursor via extmark
  2. Extract node lines (start..end)
  3. Create scratch buffer
  4. Copy node content to scratch
  5. Store context: `b:lifemode_narrow = {source_file, source_uuid, source_range, original_buf}`
  6. Set buffer options (nofile, scratch)
  7. Set statusline: `[NARROW: <title>]`
  8. Set window border: cyan
- `:LifeModeNarrow` command + `<leader>nn` keymap

**Test:** Narrow buffer shows only node content, statusline changes

---

### Phase 17: Widen from Narrow **[MVP]** TODO
**~120 lines | `lua/lifemode/app/narrow.lua`**

**Tasks:**
- `widen()` → `Result<()>`
  1. Check `b:lifemode_narrow` exists
  2. Read scratch buffer content
  3. Open source file
  4. Update node lines in source buffer
  5. Update extmark boundaries if changed
  6. Write source file to disk
  7. Close scratch buffer
  8. Restore cursor to node start
- Statusline flash: `[Syncing...]` → `[Saved]`
- `:LifeModeWiden` command + `<leader>nw` keymap

**Test:** Changes in narrow view persist to source file

---

### Phase 18: Jump Between Narrow and Context **[MVP]** TODO
**~90 lines | `lua/lifemode/app/narrow.lua`**

**Tasks:**
- `jump_context()` → `Result<()>`
  1. If in narrow: switch to source buffer, highlight node
  2. If in source with narrow history: switch back to narrow buffer
  3. Store jump history for toggle behavior
- Highlight node boundaries (2s timeout)
- `:LifeModeJumpContext` command + `<leader>nj` keymap

**Test:** Toggle between narrow and context views

---

## SQLite Index

### Phase 19: SQLite Schema **[MVP]** TODO
**~100 lines | `lua/lifemode/infra/index/schema.lua`**

Define database structure.

```sql
CREATE TABLE nodes (
  uuid TEXT PRIMARY KEY,
  file_path TEXT NOT NULL,
  created INTEGER,
  modified INTEGER,
  content TEXT
);

CREATE TABLE edges (
  from_uuid TEXT NOT NULL,
  to_uuid TEXT NOT NULL,
  edge_type TEXT NOT NULL,
  PRIMARY KEY (from_uuid, to_uuid, edge_type)
);

CREATE INDEX idx_edges_from ON edges(from_uuid);
CREATE INDEX idx_edges_to ON edges(to_uuid);
```

**Tasks:**
- SQL schema definitions
- `init_db(db_path)` → create tables if not exist
- `migrate(db, from_version, to_version)` → schema upgrades

**Test:** Create DB, tables exist, indexes exist

---

### Phase 20: SQLite Adapter **[MVP]** TODO
**~130 lines | `lua/lifemode/infra/index/sqlite.lua`**

Raw SQL execution interface.

**Tasks:**
- `exec(sql, params)` → `Result<()>` (insert/update/delete)
- `query(sql, params)` → `Result<rows>` (select)
- Use `vim.fn.system()` with `sqlite3` CLI or `sqlite.lua` plugin
- Connection pooling/reuse
- Transaction support

**Test:** Execute SQL, query rows, handle errors

---

### Phase 21: Index Facade (Insert/Update) **[MVP]** TODO
**~150 lines | `lua/lifemode/infra/index/init.lua`**

High-level index operations.

**Tasks:**
- `insert_node(node)` → `Result<()>`
  - Insert into `nodes` table
  - Hash content for change detection
- `update_node(node)` → `Result<()>`
  - Update if UUID exists
- `delete_node(uuid)` → `Result<()>`
- `find_by_id(uuid)` → `Result<Node?>`

**Test:** Insert node, query by ID, update, delete

---

### Phase 22: Index Builder (Full Scan) **[MVP]** TODO
**~180 lines | `lua/lifemode/infra/index/builder.lua`**

Build index from vault files.

**Tasks:**
- `rebuild_index(vault_path)` → `Result<{scanned, indexed, errors}>`
  1. Find all `.md` files recursively
  2. Parse each file for nodes
  3. Insert into index
  4. Report progress (every 10 files)
- `:LifeModeRebuildIndex` command
- Error collection (continue on failures, report at end)

**Test:** Rebuild index from vault, nodes queryable

---

### Phase 23: Incremental Index Updates **[MVP]** TODO
**~100 lines | `lua/lifemode/app/index.lua`**

Update index on file save.

**Tasks:**
- `update_index_for_buffer(bufnr)` → `Result<()>`
  1. Parse buffer nodes
  2. For each node: `index.update_node(node)`
- Autocommand: `BufWritePost *.md` → update index
- Debounce (500ms) to avoid thrashing
- Async execution (vim.loop) to avoid blocking

**Test:** Save file, index updates, query returns new data

---

## Search & Navigation

### Phase 24: Full-Text Search (FTS5) **[MVP]** TODO
**~120 lines | `lua/lifemode/infra/index/search.lua`**

Add full-text search capability.

**Tasks:**
- Add FTS5 virtual table: `CREATE VIRTUAL TABLE nodes_fts USING fts5(content, uuid)`
- `search(query_text)` → `Result<Node[]>`
  - Use FTS5 MATCH syntax
  - Return ranked results
- Update FTS table on node insert/update

**Test:** Search for text, results ranked

---

### Phase 25: Node Finder (Telescope) **[MVP]** TODO
**~140 lines | `lua/lifemode/ui/pickers.lua`**

Fuzzy find nodes.

**Tasks:**
- Telescope picker for nodes
  - Data source: `index.find_all()`
  - Display: `<title> (<created>)`
  - Preview: show node content
  - Actions: open, open in split, narrow
- `:LifeModeFindNode` command + `<leader>ff` keymap
- Fallback to `vim.ui.select` if Telescope not available

**Test:** Open picker, fuzzy search, select node

---

## Linking & Backlinks

### Phase 26: Edge Value Object **[MVP]** TODO
**~80 lines | `lua/lifemode/domain/types.lua`**

Define Edge structure.

```lua
Edge = {
  from: UUID,
  to: UUID,
  kind: string, -- "wikilink", "transclusion", "citation"
  context: string? -- surrounding text
}
```

**Tasks:**
- Edge constructor with validation
- `Edge.new(from, to, kind, context)` → `Result<Edge>`

**Test:** Create edge, validate fields

---

### Phase 27: Parse Wikilinks **[MVP]** TODO
**~110 lines | `lua/lifemode/domain/link.lua`**

Extract wikilinks from content.

**Tasks:**
- `parse_wikilinks(content)` → `Link[]`
  - Regex: `\[\[([^\]]+)\]\]`
  - Extract link text
  - Resolve to UUID (fuzzy match on titles or explicit UUID)
- Handle: `[[Title]]`, `[[Title|Display]]`, `[[uuid]]`

**Test:** Parse links, resolve to UUIDs

---

### Phase 28: Store Edges in Index **[MVP]** TODO
**~100 lines | `lua/lifemode/infra/index/init.lua`**

Persist relationships.

**Tasks:**
- `insert_edge(edge)` → `Result<()>`
- `delete_edges_from(uuid)` → `Result<()>` (when re-parsing node)
- `find_edges(uuid, direction, kind?)` → `Result<Edge[]>`
  - direction: "in" (backlinks), "out" (outgoing), "both"
- Update edges on node save

**Test:** Insert edge, query backlinks, query outgoing

---

### Phase 29: Backlinks in Sidebar **[MVP]** TODO
**~180 lines | `lua/lifemode/ui/sidebar.lua`**

Display contextual info in side window.

**Tasks:**
- Create floating window (right side, 30% width)
- Sections (accordion-style folds):
  - **Context**: metadata (type, created, tags)
  - **Relations**: backlinks + outgoing links
- `toggle_sidebar()` → show/hide
- `<CR>` on link: jump to source
- `:LifeModeSidebar` command + `<leader>ns` keymap

**Test:** Open sidebar, see backlinks, jump to source

---

### Phase 30: Update Sidebar on Cursor Move **[MVP]** TODO
**~90 lines | `lua/lifemode/app/sidebar.lua`**

Refresh sidebar when cursor enters new node.

**Tasks:**
- Autocommand: `CursorHold` (500ms debounce)
  1. Get node UUID at cursor (via extmark)
  2. Compare to last rendered UUID
  3. If changed: query edges, re-render sidebar
- No-op if UUID unchanged (performance)

**Test:** Move cursor between nodes, sidebar updates

---

## Transclusion

### Phase 31: Parse Transclusion Tokens **[MVP]** TODO
**~100 lines | `lua/lifemode/domain/transclude.lua`**

Extract `{{uuid}}` tokens from content.

**Tasks:**
- `parse(content)` → `Token[]`
  - Regex: `{{([a-zA-Z0-9-]+)(?::(\d+))?}}`
  - Extract UUID and optional depth
- `Token = {uuid, depth?, start_pos, end_pos}`

**Test:** Parse tokens, extract UUIDs and depths

---

### Phase 32: Transclusion Expansion **[MVP]** TODO
**~160 lines | `lua/lifemode/domain/transclude.lua`**

Recursively expand transclusions.

**Tasks:**
- `expand(content, visited, depth, max_depth)` → `Result<string>`
  1. Find all `{{...}}` tokens
  2. For each token:
     - Check cycle (UUID in visited set)
     - Check max depth
     - Fetch node from index
     - Recursively expand node content
     - Replace token with expanded content
- Cycle detection: return `⚠️ Cycle detected: {{uuid}}`
- Max depth: return `⚠️ Max depth reached`

**Test:** Expand transclusions, detect cycles, enforce depth

---

### Phase 33: Render Transclusions in Buffer TODO
**~140 lines | `lua/lifemode/app/transclude.lua`**

Display transcluded content inline.

**Tasks:**
- `render_transclusions(bufnr)` → `Result<()>`
  1. Read buffer content
  2. Expand transclusions via `domain.transclude.expand`
  3. Create extmarks for transcluded ranges
     - Namespace: `lifemode_transclusions`
     - Highlight: `LifeModeTransclusion` (darker bg)
     - Gutter sign: `»`
  4. Conceal original tokens (conceallevel=2)
  5. Virtual text: `▼ Transcluded from <title>` / `▲ End`
- Autocommand: `BufEnter *.md` → render transclusions
- `:LifeModeRefreshTransclusions` command

**Test:** Buffer shows expanded content, conceals tokens

---

### Phase 34: Transclusion Cache **[MVP]** TODO
**~90 lines | `lua/lifemode/app/transclude.lua`**

Cache expanded transclusions for performance.

**Tasks:**
- Buffer-local cache: `b:lifemode_transclusion_cache`
  - Key: `{uuid}:{depth}`
  - Value: expanded content
- Invalidate on source node change (check mtime)
- `:LifeModeRefreshTransclusions` → clear cache

**Test:** Repeated renders use cache, changes invalidate

---

## Citations (Basic)

### Phase 35: Citation Value Object **[MVP]** TODO
**~70 lines | `lua/lifemode/domain/types.lua`**

```lua
Citation = {
  scheme: string,
  key: string,
  raw: string,
  location: {node_id, line, col}
}
```

**Tasks:**
- Citation constructor with validation
- `Citation.new(scheme, key, raw, location)` → `Result<Citation>`

**Test:** Create citation, validate fields

---

### Phase 36: Parse Basic Citations **[MVP]** TODO
**~110 lines | `lua/lifemode/domain/citation.lua`**

Support one simple scheme (BibTeX-style).

**Tasks:**
- `parse_citations(content)` → `Citation[]`
  - Regex: `@([a-zA-Z0-9]+)`
  - Extract key (e.g., `@smith2020` → key="smith2020", scheme="bibtex")
- Normalize to `@bibtex:key` format
- Store in index as citation edges

**Test:** Parse citations, extract keys

---

### Phase 37: Citation Edges in Index **[MVP]** TODO
**~80 lines | `lua/lifemode/infra/index/init.lua`**

Store citation relationships.

**Tasks:**
- Insert citation edges: `(node_uuid, source_key, "citation")`
- Query citations: `find_nodes_citing(source_key)` → `Node[]`
- Display in sidebar under "Citations" section

**Test:** Insert citation edge, query citing nodes

---

### Phase 38: Jump to Source (`gd`) **[MVP]** TODO
**~90 lines | `lua/lifemode/ui/keymaps.lua`**

**Tasks:**
- `gd` on citation: jump to `.lifemode/sources/{key}.yaml`
- If source doesn't exist: error message with option to create
- `:LifeModeEditSource` command

**Test:** Jump to source file, create if missing

---

## Post-MVP Features

### Phase 39: Citation Scheme Loading BLOCKED
**~150 lines | `lua/lifemode/infra/citation_schemes.lua`**

Load user-defined citation schemes from YAML.

**Tasks:**
- Scan `.lifemode/citation_schemes/*.yaml`
- Schema: `{name, patterns, normalize, render}`
- Register schemes in global registry
- Apply multiple schemes during parsing

**Test:** Load custom scheme, parse citations with it

---

### Phase 40: Source YAML to BibTeX BLOCKED
**~120 lines | `lua/lifemode/infra/bib.lua`**

Auto-generate `.bib` files from YAML sources.

**Tasks:**
- `generate_bib(source_yaml)` → BibTeX string
- Watch `.lifemode/sources/*.yaml` for changes
- Write to `.lifemode/bib/{key}.bib`
- Aggregate: `.lifemode/bib/generated_all.bib`

**Test:** Create source YAML, `.bib` generated

---

### Phase 41: Advanced Query DSL BLOCKED
**~180 lines | `lua/lifemode/domain/query.lua`**

Parse complex queries.

**Tasks:**
- `parse(dsl_string)` → `Query` object
- Operators: `tag:`, `type:`, `status:`, `cites:`, `backlinks:`, `created:`, `sort:`, `first:`
- Boolean: `+include`, `-exclude`, `|` for OR
- Compile to SQL

**Test:** Parse query, compile to SQL, execute

---

### Phase 42: Embedded Views BLOCKED
**~110 lines | `lua/lifemode/app/views.lua`**

Inline query results in markdown.

**Tasks:**
- Parse `<!-- view: query-dsl -->` comments
- Expand to node list
- Auto-update on index change
- Render as markdown list with links

**Test:** Embed view, see results, update on change

---

### Phase 43: Slash Command Palette BLOCKED
**~160 lines | `lua/lifemode/ui/slash.lua`**

Unified command interface.

**Tasks:**
- Trigger on `/` in insert mode
- Fuzzy picker with commands:
  - transclude, cite, link, change type, embed view
- Extensible registry for user commands
- Insert result at cursor

**Test:** Trigger palette, select command, insert result

---

### Phase 44: Node Type System BLOCKED
**~200 lines | `lua/lifemode/app/types.lua`**

User-defined types with inference.

**Tasks:**
- Load type definitions from `.lifemode/node_types/*.yaml`
- Matchers: regex, field checks, content analysis
- Inference: score each type, assign highest
- Type-specific rendering

**Test:** Define type, infer from content, render

---

### Phase 45: LaTeX Export BLOCKED
**~250 lines | `lua/lifemode/app/export.lua`**

Export project to LaTeX.

**Tasks:**
- Detect project directory structure
- Map nodes to chapters/sections
- Expand transclusions
- Collect citations → generate bibliography
- Write `.tex` file + `.bib` file

**Test:** Export project, compile LaTeX successfully

---

## MVP Summary

**Phases 1-38 constitute the minimum viable product.**

With these phases complete, users can:

✅ **Capture** thoughts to daily directories
✅ **Focus** via true narrowing
✅ **Link** nodes bidirectionally
✅ **Discover** relationships via backlinks
✅ **Compose** via transclusion
✅ **Cite** sources (basic BibTeX style)
✅ **Search** full-text across vault
✅ **Navigate** with side panel context

**Total MVP estimate:** ~4,500 lines of Lua across 38 atomic commits

---

## Post-MVP Roadmap

Phases 39-45 add:
- Multi-scheme citations (Bible, Summa, custom)
- Advanced query DSL with embedded views
- Slash command palette
- Type inference system
- LaTeX/PDF export

**Beyond Phase 45:**
- Graph visualization
- Mobile app
- Sync infrastructure
- Plugin ecosystem
- AI-powered discovery


## Performance Targets

| Operation | Target | Method |
|-----------|--------|--------|
| Capture node | <100ms | Async file write |
| Narrow/widen | <50ms | Extmark lookup |
| Search vault | <200ms | FTS5 index |
| Sidebar refresh | <100ms | Cached queries |
| Transclusion render | <150ms | Lazy + cache |

Benchmark with 1000+ node vault.

---


## Dependencies

**Required:**
- Neovim 0.9+ (extmarks, lua 5.1+, floating windows)
- SQLite3 CLI or `sqlite.lua` plugin

**Optional (graceful degradation):**
- Telescope (fallback to `vim.ui.select`)
- Treesitter (fallback to regex parsing)
- `plenary.nvim` (fallback to sync operations)

---

## Success Criteria

**MVP is done when:**
1. ✅ All Phases 1-38 implemented
2. ✅ Core workflows tested (capture → narrow → link → discover)
3. ✅ No regressions (test suite passes)
4. ✅ Documentation complete (`:help lifemode`)
5. ✅ Performance acceptable (meets targets above)
6. ✅ Example vault runnable

**Post-MVP milestones:**
- Phase 45: Export feature complete
- Phase 50+: Plugin ecosystem API stable

---

## Long-Term Vision

**Version 1.0:** MVP (Phases 1-38)
**Version 1.5:** Advanced features (Phases 39-45)
**Version 2.0:** Ecosystem (plugins, sync, mobile)
**Version 3.0:** AI integration (discovery, summarization)

This is a fucking beautiful roadmap. Each phase is atomic, testable, and builds on previous work. No bullshit time estimates, just concrete deliverables.
