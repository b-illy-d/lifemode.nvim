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

