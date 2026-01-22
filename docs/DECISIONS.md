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

