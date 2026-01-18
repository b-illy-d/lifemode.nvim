type:: note
id:: architecture
created:: 2026-01-12

# Architecture Decision

We decided to use a view-first approach. See [[task-pr-review]] for related review.

The key insight from [[source-smith2019]] influenced this decision.

Key principles:
- Markdown is source of truth
- Views are computed, not stored
- 1 file = 1 node
