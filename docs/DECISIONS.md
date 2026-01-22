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

