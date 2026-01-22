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

