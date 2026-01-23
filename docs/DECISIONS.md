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

## Phase 29: Backlinks in Sidebar

### Decision: Query file paths directly from database
**Rationale:** The index find_by_id function returns Node objects but doesn't include file_path in node.meta. Rather than modifying find_by_id (which would affect other phases), created a helper query_file_paths() that batches UUID→file_path lookups. This is more efficient (single query for all UUIDs) and keeps the change localized to sidebar.lua.

### Decision: Show file paths not node titles
**Rationale:** For MVP, displaying relative file paths is simplest and unambiguous. Extracting node titles would require parsing frontmatter or content, adding complexity. File paths are sufficient for navigation. Can enhance to show titles in future.

### Decision: No Context section for MVP
**Rationale:** ROADMAP mentions Context section with metadata (type, created, tags), but nodes don't have types or tags yet. Skipped this section for Phase 29, focusing on Relations (backlinks/outgoing). Can add Context section when those features exist.

### Decision: No accordion folds for MVP
**Rationale:** ROADMAP mentions accordion-style folds, but that's complex UI state management. For MVP, show both sections (Backlinks, Outgoing) always expanded. If sidebar gets crowded later, can add folding.

### Decision: Module-level state for window handles
**Rationale:** Store sidebar winnr/bufnr in module-level variable, not global. Prevents multiple sidebars, makes toggle work correctly (close if open, open if closed). If multi-tabpage support needed later, can refactor to per-tabpage state.

### Decision: Store uuid_to_path mapping in buffer variable
**Rationale:** When rendering sidebar, store uuid→file_path mapping in buffer variable b:lifemode_sidebar_uuid_to_path. This makes jump_to_node simple - just look up UUID without querying database again. Trades small memory (<1KB for typical sidebar) for performance.

### Decision: Find main window by buftype check
**Rationale:** When jumping from sidebar to node, need to find a "main" window (not sidebar, not special buffer). Iterate windows, pick first with buftype=="". Simple heuristic that works for MVP. If complex window layouts needed later, can use more sophisticated logic.

### Decision: Markdown syntax highlighting for sidebar
**Rationale:** Set sidebar buffer filetype="markdown" to get free syntax highlighting (headers, lists). Looks better than plain text, no custom highlighting needed.

## Phase 30: Update Sidebar on Cursor Move

### Decision: Use CursorHold, not custom debouncing
**Rationale:** CursorHold is triggered after updatetime milliseconds of inactivity. This provides natural debouncing. ROADMAP specifies 500ms, but CursorHold respects user's global updatetime setting (default 4000ms). This is better UX - respects user configuration rather than being opinionated. If user wants faster sidebar updates, they set updatetime globally. Alternative (custom vim.defer_fn debounce) adds complexity and doesn't respect user preferences.

### Decision: Create app/sidebar.lua separate from ui/sidebar.lua
**Rationale:** Follows layer separation. ui/sidebar.lua is pure UI (render, toggle, jump). app/sidebar.lua is application orchestration (when to refresh, based on cursor movement). Clean separation of concerns. ROADMAP specified app/sidebar.lua for this phase, confirming this layering decision.

### Decision: Silently ignore errors in auto-update
**Rationale:** Auto-update is background functionality. User didn't explicitly request it. If cursor moves to non-node area or render fails, don't spam with errors. Log warning and keep last valid state. Only explicit user actions (toggle, jump) should show errors. Background automation should be invisible when it fails.

### Decision: Expose is_open() and get_current_uuid() getters
**Rationale:** app/sidebar.lua needs to check sidebar state (is it open? what UUID shown?). Rather than duplicating state or making state public, expose minimal getters. Single source of truth in ui/sidebar.lua. Clean layer boundary - app layer queries ui layer via interface, not direct state access.

### Decision: No custom updatetime setting
**Rationale:** Don't override user's updatetime. This global setting affects LSP hover, diagnostics, CursorHold for all plugins. Respect user configuration. LifeMode shouldn't be opinionated about timing. If user wants faster updates, they control it globally.

### Decision: Pattern *.md only
**Rationale:** LifeMode is markdown-based. Only .md files have nodes with extmarks. No point running auto-update in other file types. Pattern filter makes autocommand efficient (doesn't fire in non-markdown files).

### Decision: No-op when UUID unchanged
**Rationale:** Performance optimization. refresh_if_needed() checks current UUID before rendering. If same node, return immediately. Prevents unnecessary re-renders, database queries, and buffer updates. Makes auto-update invisible when user stays on same node.

## Phase 31: Parse Transclusion Tokens

### Decision: Allow non-UUID identifiers
**Rationale:** Pattern `[a-zA-Z0-9-]+` is more permissive than strict UUID v4 format. This gives users flexibility - can use simple IDs like "intro" or "chapter1" instead of full UUIDs. Strict UUID validation happens at expansion time (Phase 32) when looking up nodes in index. Parser just extracts identifier text without judging validity.

### Decision: No escape mechanism for literal braces
**Rationale:** MVP doesn't define how to write literal `{{` in content. Assume all `{{...}}` are transclusion tokens. If user needs literal braces, they're out of luck for now. Can add escape mechanism later (e.g., `\{{`). Simpler parsing covers 99% of use cases.

### Decision: Depth is optional, defaults to nil
**Rationale:** `{{uuid}}` with no depth expands fully (unlimited recursion up to cycle detection). `{{uuid:2}}` limits to 2 levels deep. nil depth = unlimited. This gives control when needed without forcing users to specify depth every time.

### Decision: 1-indexed positions
**Rationale:** Lua uses 1-indexed strings. string.find returns 1-based positions. Keep positions consistent with Lua conventions. When interfacing with Neovim (0-indexed), caller converts. No reason to deviate from Lua standard.

### Decision: Return empty array for invalid input
**Rationale:** If content is nil, not string, or empty, return `{}` not error. Makes parser forgiving - caller doesn't need type checking first. Simpler API. Only errors if Lua pattern fails (shouldn't happen with our pattern).

### Decision: Skip invalid tokens silently
**Rationale:** If token malformed (e.g., `{{uuid:abc}}`), skip it. Don't include in results, don't error. User sees their token didn't work when it doesn't expand. Strict validation would complicate parsing and error handling without much benefit. Fail silently for robustness.

### Decision: Pattern uses optional depth with `:?(%d*)`
**Rationale:** Lua pattern `{{([a-zA-Z0-9%-]+):?(%d*)}}` captures UUID and optional depth. `:?` makes colon optional. `(%d*)` captures zero or more digits. If no colon, depth_str is empty string. If colon but no digits (e.g., `{{uuid:}}`), depth_str is empty, depth = nil. This handles all variants gracefully.

## Phase 32: Transclusion Expansion

### Decision: Dependency injection for node fetching
**Rationale:** The expand() function takes a fetch_fn parameter instead of directly importing infra/index. This keeps the domain layer pure - no I/O dependencies. In tests, pass mock function. In production, pass index.find_by_id. Functional approach, testable, respects layer boundaries.

### Decision: Inline error replacement not Result<T> failure
**Rationale:** When expansion encounters cycle, max depth, or missing node, replace token with warning text (e.g., "⚠️ Cycle detected: {{uuid}}") and continue. Don't return Err() which would halt entire expansion. This makes expansion resilient - one bad transclusion doesn't break the whole document. User sees which tokens failed and why.

### Decision: Path-local visited set with backtracking
**Rationale:** Copy visited set when recursing, remove UUID after expansion completes. This allows same node to be transcluded in different branches of the tree (A includes B and C, both B and C include D - D appears twice, which is fine). Only cycles in a single path are blocked. Alternative (global visited) would be too restrictive.

### Decision: Ignore token depth field in Phase 32
**Rationale:** ROADMAP says this phase is ~160 lines and focuses on core recursive algorithm. Respecting depth (subtree slicing) adds complexity. Parse depth from token, store it, but just expand full node content for now. Subtree expansion can be future phase. Keep phase atomic and focused on cycle detection + recursion.

### Decision: Multiple passes over content
**Rationale:** Simple algorithm: parse tokens → expand each token → replace in content → repeat until no tokens remain. Alternative (single-pass streaming) is complex and error-prone (positions shift during replacement). Multiple passes is clear, correct, and plenty fast for typical content (<10KB). Premature optimization avoided.

### Decision: string.sub for token replacement
**Rationale:** Lua string manipulation is simple: splice before + replacement + after. No need for regex-based substitution or complex offset tracking. Token has start_pos/end_pos from parser, use those directly. Works for tokens of any length, including nested expansions.

### Decision: Max depth default 10
**Rationale:** Prevents infinite recursion in pathological cases. 10 levels deep is more than any reasonable document needs. User can override via parameter if they have valid use case. Failing safe is better than stack overflow.

## Phase 33: Render Transclusions in Buffer

### Decision: MVP rendering uses virtual text, not replace
**Rationale:** SPEC mentions concealing tokens and showing expanded content, but actually replacing buffer text is complex (shifts positions, breaks undo, confuses user). For MVP, use Neovim's concealment + virtual text: hide {{uuid}} token, show expansion as virtual text at that position. Simpler, non-destructive, reversible. Multi-line transclusions will look ugly but that's acceptable for MVP. Future phase can improve rendering.

### Decision: Separate namespace for transclusion extmarks
**Rationale:** Use `lifemode_transclusions` namespace distinct from `lifemode_nodes`. This keeps node tracking (Phase 14/15) separate from transclusion rendering. Makes it easy to clear/refresh transclusions without affecting node boundaries. Clean separation of concerns.

### Decision: No title resolution in Phase 33
**Rationale:** SPEC shows "Transcluded from <node-title>" but extracting titles from nodes adds complexity (parse frontmatter or content). For MVP, show UUID in virtual text. User can identify which node. Title resolution can be Phase 34 or later. Keep phase atomic.

### Decision: Don't clear existing transclusion extmarks before rendering
**Rationale:** For MVP, just create new extmarks. If called multiple times, will create duplicates (wasteful but not broken). Phase 34 (caching) will add proper clear-then-render cycle. Premature optimization avoided. Simpler implementation for MVP.

### Decision: BufEnter autocommand, not BufReadPost
**Rationale:** BufReadPost fires once on file load. BufEnter fires every time user enters buffer. For transclusions, we want fresh rendering when user switches to buffer (in case index changed). BufEnter is correct trigger. Performance impact acceptable (can optimize in Phase 34 with dirty flag).

### Decision: Inline error rendering, no special error extmarks
**Rationale:** Domain expand() already returns inline error messages (e.g., "⚠️ Cycle detected"). Just render those strings with error highlight. No need for separate error tracking or special extmark types. Simpler, reuses domain logic.

### Decision: Conceallevel=2, not per-extmark conceal
**Rationale:** Set buffer-wide `conceallevel=2` to enable concealment. Then use extmark `conceal=""` option on {{uuid}} tokens. This is standard Neovim pattern (like markdown link concealment). Alternative (manual text replacement) is fragile. Trust the platform.

### Decision: Gutter sign on token line, not on expansion
**Rationale:** Place sign `»` on the line where {{uuid}} token appears, not on expanded content lines. Token line is source of transclusion. Sign indicates "transclusion here". Consistent with how folding signs work. Clear visual indicator.

## Phase 34: Transclusion Cache

### Decision: Buffer-local cache, not global
**Rationale:** Use `vim.b[bufnr].lifemode_transclusion_cache` for per-buffer caching. Each buffer has independent cache. Benefits: (1) Automatic cleanup when buffer deleted, (2) No cross-buffer pollution, (3) Simple API. Alternative (global cache keyed by bufnr) would require manual cleanup and buffer tracking. Buffer-local is idiomatic Neovim pattern.

### Decision: Simple dict cache, no LRU or size limits
**Rationale:** Typical buffer has <100 transclusions. Cache memory footprint is tiny (<10KB). No need for eviction policy. YAGNI principle - premature optimization. If memory becomes issue, can add size limits later. For MVP, simplest implementation.

### Decision: No automatic invalidation on mtime changes
**Rationale:** ROADMAP mentions "invalidate on source node change (check mtime)" but this adds significant complexity: (1) Need file watchers or polling, (2) Need mtime tracking per cached UUID, (3) Node files may not correspond 1:1 with UUIDs. For MVP, manual invalidation via :LifeModeRefreshTransclusions is sufficient. User triggers refresh when they know content changed. Can add automatic invalidation in future phase if needed.

### Decision: Cache key includes depth field (future-proofing)
**Rationale:** Phase 32 doesn't use depth yet (always expands fully), but cache key format is "uuid:depth" to support future subtree expansion. When Phase X adds depth support, cache will work correctly - "uuid:2" and "uuid:5" will be different cache entries. Small addition now saves refactoring later.

### Decision: Refresh command clears cache then renders
**Rationale:** :LifeModeRefreshTransclusions becomes explicit cache invalidation + re-render. User action signals "I know content changed, re-expand everything". Pattern: clear cache → render (which repopulates cache). Simple, predictable behavior.

### Decision: Cache persists for buffer lifetime
**Rationale:** Cache not cleared on BufEnter or other events. Lives as long as buffer exists. Invalidation is explicit (via refresh command) or implicit (buffer delete). Maximizes cache hit rate. Conservative strategy - only invalidate when necessary.

## Phase 35: Citation Value Object

### Decision: Citation as immutable value object
**Rationale:** Follow same pattern as Node and Edge - immutable value objects with validation in constructor. Deep copy location to prevent mutation. Pure domain types with no behavior, just data + validation. Consistent with existing architecture.

### Decision: Scheme is free-form string, not enum
**Rationale:** ROADMAP mentions multiple schemes (BibTeX, Bible, Summa, custom). Rather than hardcode enum, use string to allow extensibility. Future phases will define schemes via config/YAML. Type system can't capture all possible schemes. Free-form string is flexible, validation happens at parser level.

### Decision: Location is optional
**Rationale:** Citations may be created without position tracking (e.g., from index queries, bibliography generation). Location is metadata about where citation appears in source, not intrinsic to citation itself. Optional field makes API flexible - parser can provide location, other consumers can omit it.

### Decision: Validate location UUID if provided
**Rationale:** If location is given, enforce data integrity - node_id must be valid UUID. Prevents corrupted data in domain layer. Fail fast with clear errors. Optional fields still have validation when present.

### Decision: Raw text stored unchanged
**Rationale:** Preserve original citation text for debugging, display, and potential re-parsing. Normalized form lives in scheme+key, but raw text is useful for user-facing features (hover tooltips, error messages). Small memory cost, high utility.

## Phase 36: Parse Basic Citations

### Decision: Pattern allows underscores and hyphens in keys
**Rationale:** BibTeX citation keys often use conventions like `smith_jones-2020` or `acm-survey-2019`. Pattern `@([a-zA-Z0-9_-]+)` matches alphanumeric plus underscore/hyphen. More permissive than strict BibTeX spec but covers real-world usage. Follows principle: be liberal in what you accept.

### Decision: Scheme hardcoded to "bibtex" for MVP
**Rationale:** Phase 36 is basic citation support - one scheme only. Multi-scheme (Bible, Summa, custom) comes in Phase 39. Hardcoding "bibtex" keeps implementation simple and focused. Citation_new accepts any scheme string, but parser always uses "bibtex". Clean separation: parser decides scheme, value object validates.

### Decision: Return empty array for invalid input
**Rationale:** Follow same pattern as link.parse_wikilinks() and transclude.parse(). If content is nil, wrong type, or empty, return `{}` not error. Makes API forgiving - callers don't need defensive type checks. Only errors would be Lua pattern failures (shouldn't happen). Defensive programming.

### Decision: No location tracking in simple parser
**Rationale:** Simple parse_citations() creates citations without location metadata. Location tracking requires buffer context (buffer number, line numbers). This parser is pure string processing - can be used on any text. Future: parse_citations_from_buffer() can add location tracking for buffer-specific use cases.

### Decision: Skip citations that fail validation
**Rationale:** If Citation_new returns Err (shouldn't happen with valid pattern, but defensive), skip that citation and continue. Don't halt entire parse. Collect citations that succeed. Makes parser resilient. User sees which citations worked. Alternative (fail entire parse on first error) is too brittle.

### Decision: Follow transclude.parse() pattern exactly
**Rationale:** Both are domain-layer parsers extracting tokens from text. Same structure: type guard → pattern → while loop → string.find → capture groups → construct object → append → advance. Consistency across codebase. Easy to understand if you've seen one parser.

## Phase 37: Citation Edges in Index

### Decision: Repurpose to_uuid field for citation keys
**Rationale:** Citations reference external sources (e.g., "smith2020") not nodes in vault. Current edges table has `(from_uuid, to_uuid, edge_type)` schema. Rather than add new table, repurpose `to_uuid` field: for citation edges, it stores source key (not UUID). This is pragmatic - reuses existing infrastructure (INSERT OR IGNORE idempotency, delete cascades, query patterns). Trade-off: field name is misleading for citations, but code is simpler. Alternative (new citations table) adds complexity without clear benefit for MVP.

### Decision: insert_citation_edge() bypasses insert_edge()
**Rationale:** Cannot reuse `insert_edge()` because it validates `edge.to` must be UUID, but for citations it's a source key. Two options: (1) modify insert_edge to skip UUID validation for citations, or (2) insert directly in insert_citation_edge. Chose option 2 - cleaner separation, no special cases in insert_edge. Citation edge insertion is simple (INSERT OR IGNORE), acceptable duplication for clearer semantics.

### Decision: find_nodes_citing() returns full Node objects
**Rationale:** Callers (sidebar) need node content to display titles/excerpts. Query edges for UUIDs, then fetch each node via `find_by_id()`. Alternative (return just UUIDs) forces every caller to do the lookup. Trading query efficiency for API convenience. For MVP (small vaults), N+1 queries acceptable. Can optimize later with JOIN if needed.

### Decision: No citation-specific edge deletion function
**Rationale:** Existing `delete_edges_from(uuid)` already handles all edge types. When re-parsing node content, delete all outgoing edges (wikilinks, transclusions, citations) then re-insert. No special case for citations. Simpler API. Consistent with Phase 28 pattern.

### Decision: Skip sidebar integration in Phase 37
**Rationale:** ROADMAP mentions "Display in sidebar under Citations section" but that's UI layer work (ui/sidebar.lua). Phase 37 is infrastructure layer (infra/index/init.lua). Provide `find_nodes_citing()` function, let future phase integrate with sidebar. Respect layer boundaries. One responsibility per phase.

## Phase 38: Jump to Source (`gd`)

### Decision: Create app/citation.lua for business logic
**Rationale:** Keymaps should be thin - just call commands. Commands should be thin - just call app layer. Business logic (detect citation under cursor, compute paths, handle missing files) belongs in application layer. Follows established pattern: ui/keymaps → ui/commands → app layer → domain/infra layers.

### Decision: Override gd only in markdown buffers
**Rationale:** `gd` is Vim's built-in "go to definition". We only override it for markdown files using FileType autocmd with buffer-local keymap. Doesn't affect behavior in other file types. Respects user's existing `gd` bindings outside markdown context.

### Decision: Store sources in .lifemode/sources/{key}.yaml
**Rationale:** Centralized location for bibliography data. Pattern: `.lifemode/` directory is for plugin infrastructure (index, sources, etc.). Each source gets its own file for easy editing/version control. YAML format is human-friendly for manual editing. Future Phase 39 will parse these files for multi-scheme citation support.

### Decision: Use vim.fn.confirm() for user prompt
**Rationale:** Native Neovim confirmation dialog. Simple, works in all environments (terminal, GUI). Two options: Yes/No, defaults to No (safe choice). User can press Esc to cancel. Alternative (vim.ui.select) is more complex without clear benefit for binary choice.

### Decision: Create template YAML with common fields
**Rationale:** Provide starting point for users. Common bibliography fields (title, author, year, type, url, notes) cover most use cases. User can add/remove fields as needed. Empty strings for all values - user fills in. Better UX than empty file.

### Decision: Parse line for citations instead of using treesitter
**Rationale:** Simpler implementation - reuse existing `domain/citation.parse_citations()`. Treesitter would require citation syntax in markdown parser (doesn't exist by default). Line-level parsing is sufficient - citations don't span lines. Performance is fine (single line parse on keypress). Can upgrade to treesitter later if needed.
