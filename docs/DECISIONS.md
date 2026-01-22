# LifeMode Implementation Decisions

This document tracks design decisions and rationale made during implementation of the ROADMAP phases.

---

## Phase 10: Capture Node Use Case

### Decision: Return both node and file_path
**Rationale:** Caller (UI layer in Phase 12) needs both the node object (for display) and the file path (to open in buffer). Returning both avoids forcing caller to reconstruct the path.

### Decision: initial_content parameter is optional
**Rationale:** Allows for two workflows:
1. Capture with immediate content (e.g., from visual selection)
2. Capture empty node and let user type (more common case)

Default to empty string for simplicity.

### Decision: Error propagation, not error handling
**Rationale:** This is the application layer. We orchestrate, we don't decide policy. UI layer will handle user-facing error messages. Our job is to propagate failures faithfully using Result pattern.

### Decision: No buffer operations in this phase
**Rationale:** Separation of concerns. This module is pure coordination (app layer). Buffer operations (opening file, setting cursor) belong in Phase 11 (infra/nvim) and Phase 12 (ui/commands).

### Decision: Use config.get() not direct config access
**Rationale:** Config module owns the configuration state. Going through get() accessor respects encapsulation and allows config module to change implementation without breaking callers.

---

## Phase 11: Open Node in Buffer

### Decision: get_lines doesn't return Result<T>
**Rationale:** Following Neovim API conventions. `nvim_buf_get_lines` throws Lua errors on invalid input, which is the expected Neovim pattern. Wrapping in Result<T> would add ceremony without value. Callers can use pcall if they need error handling.

### Decision: open() returns Result<bufnr> not Result<()>
**Rationale:** Caller needs the buffer number to perform subsequent operations. Returning it directly avoids forcing caller to query current buffer separately.

### Decision: Use vim.cmd.edit not vim.api.nvim_open_buf
**Rationale:** `vim.cmd.edit` provides expected editor behavior (respects 'hidden', triggers autocmds, updates jumplist). `nvim_open_buf` is lower-level and would require manually handling those concerns.

### Decision: Check file existence before opening
**Rationale:** Provides better error message than letting vim.cmd.edit fail. We can distinguish "file doesn't exist" from other errors (permissions, etc).

### Decision: Thin wrapper, minimal logic
**Rationale:** Infrastructure layer should be transparent adapter to external system (Neovim). Business logic belongs in app/domain layers.

---

## Phase 12: NewNode Command

### Decision: No auto-narrowing in this phase
**Rationale:** Auto-narrowing is Phase 16. This phase focuses on basic command → capture → open workflow. Narrowing requires extmark infrastructure (Phase 14) and buffer parsing (Phase 15). Keep phases atomic.

### Decision: Position cursor after frontmatter (line 4)
**Rationale:** User expects to immediately start typing content. Frontmatter is metadata, user shouldn't edit it manually. Line 4 is first content line (after ---, id, created, ---).

### Decision: Use vim.notify for all user feedback
**Rationale:** Respects user's notification configuration (nvim-notify, noice, etc.). Standard Neovim pattern. ERROR level for failures, INFO level for success.

### Decision: setup_commands() separate from new_node()
**Rationale:** Separation of registration (called once on plugin load) from handler (called each time command runs). Makes testing easier (can call new_node() directly without command system).

### Decision: Capture with empty content
**Rationale:** User wants to create node then type into it. Passing empty string to capture_node() creates minimal valid node. Future: could pass visual selection or current line as initial content.

---

## Phase 13: Keymaps Setup

### Decision: Only register new_node keymap in this phase
**Rationale:** Other keymaps (narrow, widen, jump_context, sidebar) require features from future phases. Keep phase atomic. Add keymaps as features are implemented.

### Decision: Allow disabling keymaps with empty string
**Rationale:** User may want to define their own keymaps or use different bindings. Empty string or nil means "don't register this keymap". Provides flexibility without complex opt-out mechanism.

### Decision: Use desc parameter for which-key compatibility
**Rationale:** Popular plugin which-key.nvim shows keymap descriptions. Setting desc="LifeMode: ..." provides good UX for users who have which-key installed.

### Decision: Register keymaps in setup(), not lazily
**Rationale:** Keymaps are global, should be set up once on plugin load. Lazy registration would complicate state tracking. Simple eager registration matches Neovim plugin conventions.

### Decision: Call setup_keymaps() from init.lua
**Rationale:** init.lua is the plugin entry point, setup() is the initialization function. Centralizing setup calls there makes the flow clear and ensures correct initialization order (commands first, then keymaps).

---

## Phase 14: Extmark Tracking

### Decision: Use single global namespace "lifemode_nodes"
**Rationale:** All node tracking happens in one namespace for simplicity. Alternative (per-buffer namespaces) adds complexity without benefit. Single namespace makes queries fast and consistent.

### Decision: Store metadata on extmark, not in separate table
**Rationale:** Neovim extmarks support arbitrary metadata via opts. Storing metadata directly on extmark keeps data colocated with position tracking. No synchronization issues. Simpler than maintaining separate lookup table.

### Decision: Attach extmark to frontmatter line (node start)
**Rationale:** Frontmatter is stable (users don't edit it). Content lines may change frequently. Attaching to start line ensures extmark survives content edits. Node boundaries stored in metadata can be updated without moving extmark.

### Decision: query() returns Err when no extmark found
**Rationale:** Absence of extmark is not exceptional (cursor may be in blank area, between nodes). Returning Err makes it explicit. Caller can check result.ok and handle accordingly. Consistent with Result pattern.

### Decision: get_node_at_cursor() uses current buffer/cursor
**Rationale:** Common pattern: user triggers action, we need node at cursor. Taking no parameters makes it ergonomic for UI commands. Alternative (passing bufnr/line) is verbose and error-prone.

### Decision: Return extmark_id from query()
**Rationale:** Caller may need to delete or update extmark after querying. Returning ID along with metadata avoids second query. Small performance win, better API.

### Decision: No automatic cleanup on buffer unload
**Rationale:** Neovim automatically clears extmarks when buffer is unloaded. We don't need manual cleanup. Trust the platform. Keep it simple.

---

## Phase 15: Parse Buffer for Nodes

### Decision: Node boundaries detected by frontmatter delimiters
**Rationale:** Each node starts with `---` frontmatter. Node extends from frontmatter line to either (1) line before next `---`, or (2) end of buffer. Simple heuristic, works for our use case. Alternative (explicit end markers) adds complexity without benefit.

### Decision: Continue parsing on malformed nodes
**Rationale:** Graceful degradation. If one node has bad frontmatter, don't fail entire buffer. Log warning, skip that node, continue. Users can fix errors incrementally. Better UX than blocking all operations.

### Decision: Don't clear existing extmarks before parsing
**Rationale:** For Phase 15, just create new extmarks. Clearing and recreating would require:
1. Tracking which extmarks are "ours"
2. Comparing old vs new to detect changes
3. Updating only what changed

That's future optimization (Phase 23: incremental updates). Phase 15: simple path, create extmarks on buffer load.

### Decision: Autocommand uses BufReadPost not BufEnter
**Rationale:** `BufReadPost` fires once when file is read from disk. `BufEnter` fires every time user switches to buffer (too frequent). We want to parse once on load, not on every buffer switch. Performance and correctness.

### Decision: parse_and_mark_buffer returns Node[] not ()
**Rationale:** Caller may need parsed nodes for display, indexing, or validation. Returning them avoids re-parsing. Small memory cost (nodes are lightweight), big flexibility win.

### Decision: Async autocommand execution via vim.schedule
**Rationale:** Parsing large buffers may take time. Don't block buffer load. Use `vim.schedule()` to defer parsing until after buffer is displayed. User sees content immediately, extmarks appear shortly after. Better perceived performance.

---


## Phase 16: Narrow to Node

### Decision: Use scratch buffer not floating window
**Rationale:** Scratch buffer (`buftype=nofile`) is simpler than floating window. User can resize, split, move freely. Floating windows require manual layout management. Scratch buffer integrates naturally with Neovim workflow. Window borders can be added later if desired.

### Decision: Store narrow context in buffer-local variable
**Rationale:** `vim.b[bufnr].lifemode_narrow` ties context to specific buffer. When buffer is deleted, context is automatically cleaned up. No separate tracking needed. Standard Neovim pattern.

### Decision: Extract title from first heading or content line
**Rationale:** Gives user-friendly buffer names like `*Narrow: Research Notes*` instead of `*Narrow: node-uuid*`. Improves UX when switching buffers (`:buffers` list is readable). Falls back to "Untitled" if no content yet.

### Decision: Virtual text hint vs window border
**Rationale:** Virtual text at top of buffer is more visible and informative than border color change. User immediately sees "Press <leader>nw to widen" hint. Border color (cyan) mentioned in SPEC but may be overkill - defer to future phase if user feedback indicates it's needed.

### Decision: Don't auto-narrow in this phase
**Rationale:** Phase 16 is manual narrowing only (user triggers via command/keymap). Auto-narrowing on capture (SPEC §4.1) requires integration with capture workflow - that's a future enhancement. Keep phase atomic.

### Decision: Narrow creates new buffer, doesn't modify source
**Rationale:** Source buffer remains untouched. User can switch back to source buffer anytime (`:b <source>`). Narrow buffer is ephemeral workspace. When user wants changes synced back, they'll use Widen (Phase 17). Clear separation of concerns.

### Decision: Use get_node_at_cursor not manual line detection
**Rationale:** Extmarks are source of truth for node boundaries. Don't re-parse or guess. Trust Phase 14's extmark system. If extmark doesn't exist, node isn't tracked - that's an error condition.

---


## Phase 17: Widen from Narrow

### Decision: Narrow buffer is source of truth during widen
**Rationale:** User made edits in narrow view - that's the canonical version. Widen overwrites source file even if externally modified. Alternative (3-way merge) adds massive complexity for rare edge case. Simple overwrite matches user intent.

### Decision: Update extmarks after line changes
**Rationale:** Adding/removing lines shifts node boundaries. Must update extmark's node_end to reflect new size. Query existing extmark, delete it, create new one with updated metadata. Keeps system consistent.

### Decision: Reopen source file if buffer closed
**Rationale:** User might close source buffer while editing in narrow view. Widen should still work - use `buf.open(source_file)` to reload. Graceful recovery, no data loss.

### Decision: Write file immediately with :write
**Rationale:** Explicit persistence. Don't rely on Neovim's write-on-buffer-leave or autosave. User expects widen to save - make it explicit. Use vim.cmd.write() on source buffer.

### Decision: Delete narrow buffer after successful widen
**Rationale:** Narrow buffer is scratch/temporary. After syncing back, no reason to keep it. Delete with `nvim_buf_delete(narrow_bufnr, {force=true})`. Avoids buffer list clutter.

### Decision: Simplify statusline flash for MVP
**Rationale:** Full "[Syncing...] → [Saved]" animation requires complex async coordination (vim.defer_fn chains, timing state). For Phase 17, just show "[Saved]" briefly with vim.notify(). Polish animation is future work if user feedback indicates it's valuable.

### Decision: Calculate node size delta to update extmarks
**Rationale:** If narrow buffer has more/fewer lines than original, node boundaries changed. Calculate delta = new_size - old_size. Add delta to node_end when creating new extmark. This keeps extmark metadata accurate.

---


## Phase 18: Jump Between Narrow and Context

### Decision: Use buffer-local variable for jump history
**Rationale:** `vim.b[bufnr].lifemode_jump_from` ties history to specific buffer. When buffer deleted, history automatically cleared. Simple, no global state, no cleanup needed.

### Decision: Highlight via extmark with end_row
**Rationale:** Extmarks support range highlighting with `end_row` parameter. Creates highlight from node_start to node_end. Clean, built-in solution. Alternative (virtual text everywhere) would be complex and ugly.

### Decision: Clear highlight after 2s with vim.defer_fn
**Rationale:** User needs visual feedback of node boundaries, but persistent highlight would be distracting. 2 seconds (per SPEC) is enough to register location, then fade. Use `vim.defer_fn()` for async timeout.

### Decision: Toggle behavior not stack-based
**Rationale:** Simple toggle (narrow ↔ source) is intuitive. Stack-based (track multiple jumps) would be complex and likely unused. Keep it simple - one level of "jump back" is enough.

### Decision: Cursor to node_start when jumping to context
**Rationale:** User wants to see the node they were editing. Put cursor at first line of node (frontmatter). Predictable, consistent with narrow behavior.

### Decision: Error when narrow buffer no longer valid
**Rationale:** If user deleted narrow buffer while in source, jump back impossible. Return Err with clear message. Don't try to recreate narrow buffer - user probably closed it intentionally.

---


## Phase 19: SQLite Schema

### Decision: Use kkharji/sqlite.lua library
**Rationale:** Most mature SQLite binding for Neovim. Pure Lua FFI, no C compilation needed. Well-maintained, used by telescope.nvim and other plugins. API is clean and Result-friendly.

### Decision: schema_version table for migrations
**Rationale:** Explicit versioning enables future schema changes without breaking existing installations. Single source of truth for current version. Industry standard pattern (e.g., Rails migrations, Alembic).

### Decision: WAL journal mode
**Rationale:** Write-Ahead Logging provides better concurrency - readers don't block writers. Critical for Neovim where index updates may happen while user is querying. Standard recommendation for applications with concurrent access.

### Decision: Composite primary key on edges
**Rationale:** `(from_uuid, to_uuid, edge_type)` as PK enforces uniqueness - can't have duplicate edges of same type between same nodes. Avoids need for synthetic ID. Efficient for common queries.

### Decision: Separate indexes on from_uuid and to_uuid
**Rationale:** Two most common queries: (1) outgoing edges from node, (2) backlinks to node. Composite PK already indexes from_uuid, but explicit index ensures optimal performance. to_uuid needs separate index for backlinks query.

### Decision: content column stores full text
**Rationale:** Enables full-text search (Phase 24) without re-reading files. Denormalization is acceptable - content is source of truth in markdown files, index is derived. Rebuild command (Phase 22) will resync if needed.

### Decision: created/modified as INTEGER (Unix timestamp)
**Rationale:** SQLite's INTEGER is efficient for date range queries. Unix timestamp is unambiguous (no timezone issues). Conversion to/from human-readable dates happens in application layer.

### Decision: No foreign key constraints yet
**Rationale:** For MVP, edges may reference nodes that don't exist in index yet (stale references during incremental updates). Soft referential integrity - query logic handles missing nodes gracefully. Could add FK constraints in later phase if needed.

---


## Phase 20: SQLite Adapter

### Decision: Use kkharji/sqlite.lua (not sqlite3 CLI)
**Rationale:** ROADMAP mentions both options. sqlite.lua is superior: (1) No shell process overhead, (2) Native Lua integration, (3) Better error handling, (4) Already used in schema.lua. CLI would require parsing text output - fragile and slow.

### Decision: Thin wrapper, minimal abstraction
**Rationale:** This is infrastructure layer - just adapt sqlite.lua API to Result<T> pattern. No query builders, no ORM, no magic. Higher layers (Index Facade, Phase 21) will provide domain-specific APIs. Keep this simple and predictable.

### Decision: Caller manages connections (no pooling yet)
**Rationale:** Connection pooling adds complexity for uncertain benefit. SQLite is designed for embedded use - opening connection is fast. Future phase can add pooling if profiling shows it's needed. YAGNI principle.

### Decision: Explicit transaction function
**Rationale:** Transactions are critical for data integrity but not every operation needs them. Explicit `transaction(db, fn)` makes intent clear. Alternative (implicit transactions) would hide important behavior. Functional approach - pass function to execute in transaction context.

### Decision: pcall wraps all sqlite.lua calls
**Rationale:** sqlite.lua throws Lua errors on failure. We use Result<T> pattern throughout codebase. pcall converts exceptions to Result<T>. Preserves error messages for debugging.

### Decision: Empty query result returns Ok([])
**Rationale:** No rows is not an error - it's valid result. Returning Ok(empty_table) is consistent with SQL semantics. Caller can check `#rows == 0` without error handling.

### Decision: Close is idempotent
**Rationale:** Multiple close() calls should not error. Makes cleanup code simpler - no need to track "already closed" state. sqlite.lua close is idempotent, we preserve that.

---


## Phase 21: Index Facade (Insert/Update)

### Decision: Store file_path in nodes table
**Rationale:** Need to map nodes back to source files for editing operations. Also useful for displaying file locations in UI. Path stored as absolute path for consistency.

### Decision: Store content as TEXT not hash
**Rationale:** ROADMAP mentions "hash content for change detection" but we need full content for full-text search (Phase 24). Store full content, compute hash only if needed for change detection. Content column enables FTS5 later.

### Decision: delete_node() is idempotent
**Rationale:** Deleting non-existent node is not an error - end state is the same (node doesn't exist). Simplifies caller logic - no need to check existence before delete.

### Decision: find_by_id() returns Ok(nil) not Err()
**Rationale:** Not finding a node is valid result, not error. Returning Ok(nil) makes it explicit - caller checks `result.value == nil`. Alternative (Err) would force error handling for non-error case.

### Decision: Facade manages database lifecycle
**Rationale:** Open connection → execute operation → close connection. Each function is self-contained. Caller doesn't manage connections. Alternative (caller passes connection) would leak infrastructure concerns to application layer.

### Decision: Node reconstruction via domain.types.Node_new()
**Rationale:** Ensures returned nodes are valid domain objects. Use same constructor that domain layer uses. Maintains type safety and validation.

### Decision: Delete edges with node
**Rationale:** When node is deleted, its edges become invalid (dangling references). Delete them atomically. Prevents index corruption. Both outgoing and incoming edges removed.

### Decision: Update requires existing node
**Rationale:** Clear semantics - insert creates, update modifies. If node doesn't exist, that's caller error. Alternative (upsert) would hide whether operation was create or update. Explicit is better.

---


## Phase 22: Index Builder (Full Scan)

### Decision: Clear index before rebuild (not incremental)
**Rationale:** Rebuild is full refresh - delete everything, scan everything. Ensures index matches vault state exactly. Incremental updates are separate feature (Phase 23). Full rebuild is simpler, more reliable for initial implementation.

### Decision: Continue on errors, collect in array
**Rationale:** One bad file shouldn't block entire rebuild. Collect errors for user review but process all other files. Resilient operation is critical for large vaults with mixed quality markdown.

### Decision: Progress reporting every 10 files
**Rationale:** Provides feedback for long-running operation without spamming notifications. 10 files is reasonable granularity - not too frequent, not too sparse. User knows it's working.

### Decision: Use vim.fn.glob() not vim.loop.fs_scandir()
**Rationale:** vim.fn.glob() handles recursive patterns natively ("**/*.md"). Simpler than manually walking directory tree. Returns all matches at once. Acceptable for MVP - can optimize later if performance issue.

### Decision: Parse frontmatter inline (not separate YAML library)
**Rationale:** Our frontmatter is simple (id: value, created: value). Full YAML parser is overkill. Simple line-by-line parsing is sufficient. Avoids external dependency. Can upgrade later if needed.

### Decision: Skip nodes with invalid frontmatter
**Rationale:** Parsing errors shouldn't crash rebuild. Skip problematic nodes, log error, continue. User can fix and re-run rebuild. Graceful degradation.

### Decision: builder.lua in infra/index/
**Rationale:** Builder operates on infrastructure (filesystem, database). Not pure domain logic, not application orchestration. Fits infrastructure layer - adapts external systems (filesystem) to index operations.

### Decision: Command shows summary + first 3 errors
**Rationale:** User needs to know rebuild succeeded and statistics. If errors, show first few for context but don't spam with hundreds of lines. User can check logs for full details.

---



## Phase 23: Incremental Index Updates

### Decision: Upsert pattern (try insert, fall back to update)
**Rationale:** Simpler than checking existence first. Insert is optimistic path (most common for incremental updates). If node exists, database returns UNIQUE constraint error, handle by calling update. One less query in common case.

### Decision: vim.schedule() not vim.loop
**Rationale:** Index operations are fast (<10ms per node). vim.schedule() is simpler and sufficient. Don't need true async coroutines for this. Reserve vim.loop for future expensive operations like FTS5 indexing.

### Decision: 500ms debounce
**Rationale:** Balance between responsiveness and avoiding redundant work. User might have auto-save plugins or save multiple times rapidly. 500ms is imperceptible but prevents thrashing.

### Decision: Silent on success, notify on errors
**Rationale:** Avoid notification spam. User doesn't need confirmation every save. Only notify if something goes wrong. Collect errors and show summary, not one notification per error.

### Decision: Parse buffer inline, don't call parse_and_mark_buffer
**Rationale:** parse_and_mark_buffer creates extmarks which we don't need here. Reuse the parsing logic but not the full function. Avoids unnecessary extmark operations on every save.

---



## Phase 24: Full-Text Search (FTS5)

### Decision: FTS5 over FTS4/FTS3
**Rationale:** FTS5 is latest with better performance, BM25 ranking, more features. All recent SQLite builds include it.

### Decision: Index only content, not metadata
**Rationale:** Users search for node content, not UUIDs or timestamps. Indexing metadata wastes space. Can add later if needed.

### Decision: Don't fail index operations if FTS fails
**Rationale:** FTS is auxiliary - if FTS update fails, node operation should still succeed. Log warning, continue. User can rebuild FTS index later.

### Decision: Default limit 50 results
**Rationale:** Balance between usefulness and performance. 50 fits most UIs. User can increase via opts.limit.

### Decision: No query DSL, use FTS5 MATCH directly
**Rationale:** FTS5 syntax is powerful and well-documented. Building DSL adds complexity and limits flexibility. Users can learn FTS5 syntax.

---



## Phase 26: Edge Value Object

### Decision: Edge is pure value object
**Rationale:** No behavior, just data validation. Fits domain layer - no I/O, no side effects. Relationships managed by index layer.

### Decision: Three edge kinds (wikilink, transclusion, citation)
**Rationale:** Covers core linking patterns. Wikilinks for connections, transclusions for embeds, citations for references. Extensible for future kinds.

### Decision: Context is optional
**Rationale:** Useful for backlink preview but not always meaningful. Keeps API flexible.

### Decision: Validate both UUIDs
**Rationale:** Edges reference nodes. Invalid UUIDs would cause foreign key violations. Fail early with clear errors.

### Decision: Immutable value object
**Rationale:** Edges are facts about relationships. To change, delete old and create new. Prevents mutation bugs.

---



## Phase 27: Parse Wikilinks

### Decision: Pure parsing, no resolution
**Rationale:** Keep domain layer pure - no index lookups. Parser just extracts raw link text. Resolution happens in application layer.

### Decision: Return Link array, not Edge array
**Rationale:** Links ≠ Edges. A link is unresolved text. An edge is a validated UUID relationship. Application layer converts Links → Edges.

### Decision: Position tracking
**Rationale:** Essential for UI (hover, jump, refactoring). Small overhead for significant functionality.

### Decision: Whitespace trimming
**Rationale:**  should match . Trim for consistency. Leading/trailing whitespace never intentional.

### Decision: Skip empty links
**Rationale:**  is invalid. Silently skip rather than error (user may be typing).

### Decision: Simple regex, not full markdown parser
**Rationale:** Full markdown parsing is complex. For MVP, simple regex sufficient. Known limitation: won't handle code blocks/escapes. Can improve later.

---


## Phase 27: Parse Wikilinks

### Decision: Pure parsing, no resolution
**Rationale:** Keep domain layer pure - no index lookups. Parser just extracts raw link text. Resolution happens in application layer.

### Decision: Return Link array, not Edge array
**Rationale:** Links ≠ Edges. A link is unresolved text. An edge is a validated UUID relationship. Application layer converts Links → Edges.

### Decision: Position tracking
**Rationale:** Essential for UI (hover, jump, refactoring). Small overhead for significant functionality.

### Decision: Whitespace trimming
**Rationale:** User might write wikilinks with spaces. Trim for consistency.

### Decision: Skip empty links
**Rationale:** Empty brackets are invalid. Silently skip rather than error (user may be typing).

### Decision: Simple regex, not full markdown parser
**Rationale:** Full markdown parsing is complex. For MVP, simple regex sufficient. Can improve later.

---

## Phase 28: Store Edges in Index

### Decision: Context field not stored in database
**Rationale:** The edges table schema doesn't include a context column. For MVP, we skip storing edge.context. This can be added in a future schema migration if needed. The domain Edge type still has the context field for API compatibility.

### Decision: INSERT OR IGNORE for idempotent inserts
**Rationale:** Using INSERT OR IGNORE makes insert_edge() idempotent. If the same edge (same from/to/kind triple) is inserted twice, the second insert succeeds silently. This prevents errors when re-parsing unchanged wikilinks and makes the API easier to use. Primary key constraint on (from_uuid, to_uuid, edge_type) naturally enforces uniqueness.

### Decision: delete_edges_from only deletes outgoing edges
**Rationale:** When re-parsing a node's content, we need to clear its outgoing edges before inserting new ones. However, edges TO that node (backlinks) are owned by other nodes and should not be deleted. This matches the ownership model: each node owns its outgoing edges. The function name makes this clear.

### Decision: find_edges with "both" direction uses simple OR query
**Rationale:** For MVP, a simple OR query (WHERE from_uuid = ? OR to_uuid = ?) is sufficient and easy to understand. For large graphs with millions of edges, this might be slower than UNION, but premature optimization is evil. Can optimize later if profiling shows it's a bottleneck.

### Decision: Validate kind parameter even when optional
**Rationale:** In find_edges, kind is optional (can be nil to get all edge types). However, if kind IS provided, we validate it strictly. This catches typos early ("wikilnk" → error) rather than silently returning empty results. Fail fast principle.

### Decision: Convert database rows to domain Edge objects
**Rationale:** find_edges returns Edge objects from types.Edge_new, not raw database rows. This maintains the layer boundary - callers work with domain objects. Also catches data corruption - if database has invalid edge_type, Edge_new validation fails and we return error rather than garbage data.
