# Active Context

## Current Focus
T02: Extmark-based span mapping COMPLETE
Implemented using TDD (RED → GREEN → REFACTOR cycle)

## Recent Changes
- [T02] Created lua/lifemode/extmarks.lua with namespace and span metadata helpers - lua/lifemode/extmarks.lua:1
- [T02] Added :LifeModeDebugSpan command - lua/lifemode/init.lua:54
- [T02] Updated view.create_buffer() with example spans - lua/lifemode/view.lua:27
- [T02] Created tests/extmarks_spec.lua (15 tests, all passing)
- [T01] Created lua/lifemode/view.lua with create_buffer() function - lua/lifemode/view.lua:1
- [T01] Added :LifeModeOpen command registration - lua/lifemode/init.lua:49
- [T01] Created tests/view_spec.lua (10 tests, all passing)
- [T01] Updated _reset_for_testing() to clean up :LifeModeOpen command
- [AUDIT] Created tests/edge_cases_spec.lua (21 tests, 5 failures = 5 bugs found)
- [AUDIT] Created tests/runtime_edge_cases_spec.lua (15 tests, all pass but expose risks)
- [AUDIT] Created SILENT_FAILURE_AUDIT.md with comprehensive findings
- [T00] Created lua/lifemode/init.lua with setup() and :LifeModeHello command
- [T00] Implemented config validation (required: vault_root, optional: leader/max_depth/bible_version)
- [T00] Created minimal test runner (tests/run_tests.lua) - 7/7 tests passing
- [T00] Initialized git repository and created initial commit (0dd2003)

## Next Steps
1. T03: Minimal Markdown block parser
2. T04: Ensure IDs for indexable blocks
3. T05: Build in-memory Node model

## Active Decisions
| Decision | Choice | Why |
|----------|--------|-----|
| Testing approach | Custom minimal test runner | plenary not installed, needed working tests for TDD |
| Config validation | Assert vault_root required | Spec requirement |
| Leader default | `<Space>` | Spec default, user-configurable |
| ID format | UUID v4 | Spec requirement for stable, globally unique IDs |
| TDD cycle | RED → GREEN → REFACTOR | Strict adherence to TDD principles |
| Buffer naming (T01) | `[LifeMode]` with collision handling | Use unique buffer numbers if name exists |
| View buffer options (T01) | `buftype=nofile`, `swapfile=false`, `bufhidden=wipe` | Per SPEC.md requirement |
| Extmark metadata storage (T02) | Separate table indexed by bufnr:mark_id | Neovim extmarks don't allow arbitrary keys |
| Multi-line span retrieval (T02) | Query with overlap detection | Check if extmark end_row covers target line |

## Learnings This Session

### Extmark API (T02)
- Neovim extmarks don't support arbitrary key-value pairs in details
- Must store custom metadata separately and index by extmark ID
- end_row in extmarks is exclusive (need to add 1 when setting, subtract 1 when checking)
- Multi-line spans require overlap detection - query from buffer start and check if extmark covers line
- Use `{details = true, overlap = true}` options in nvim_buf_get_extmarks for span queries

### Silent Failure Patterns Discovered
1. **Type validation gaps**: vim.tbl_extend accepts any type, no post-merge validation
2. **Empty string edge case**: Lua treats "" as truthy, passes `if not x` checks
3. **Boundary validation missing**: No min/max checks on numeric configs
4. **Config merge semantics**: setup() REPLACES config, doesn't accumulate
5. **Path validation deferred**: No existence/normalization at setup time

### Neovim Plugin Patterns
- Neovim plugin structure: lua/plugin-name/init.lua with setup()
- Config merging: vim.tbl_extend('force', defaults, user_config)
- Command creation: vim.api.nvim_create_user_command()
- Test isolation requires _reset_for_testing() helper
- Buffer creation: vim.api.nvim_create_buf(false, true) for scratch buffers
- Buffer options set via: vim.api.nvim_buf_set_option(bufnr, key, value)
- Buffer names may include full path - check with vim.fn.bufnr() for collisions

### Testing Insights
- Edge case testing catches what happy path tests miss
- Type coercion is silent in Lua - must validate explicitly
- Boundary values (0, negative, huge numbers) expose assumptions
- Runtime environment variations need explicit tests

## Blockers / Issues

### Critical Issues Found (5 total)
1. **Type validation missing** - leader, max_depth, bible_version accept any type
2. **Empty string accepted** - vault_root = '' or '   ' silently succeeds
3. **No max_depth bounds** - Negative, zero, or huge values accepted
4. **Config merge resets** - Second setup() loses previous values (may be intended)
5. **No path normalization** - Trailing slashes, ~, multiple // not handled

### Decision Required
Should critical issues be fixed before T01, or documented and deferred?

## User Preferences Discovered
- Git initialized in T00
- Initial commit created after implementation
- Prefers commit-sized tasks with clear acceptance criteria
- Requested silent failure hunt after T00 completion

## Last Updated
2026-01-14 18:15 EST
