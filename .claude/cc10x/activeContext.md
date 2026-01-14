# Active Context

## Current Focus
T04: Ensure IDs for indexable blocks COMPLETE
Implemented using TDD (RED → GREEN → REFACTOR cycle)

## Recent Changes
- [T04] Created lua/lifemode/uuid.lua for UUID v4 generation - lua/lifemode/uuid.lua:1
- [T04] Created lua/lifemode/blocks.lua with ensure_ids_in_buffer() - lua/lifemode/blocks.lua:1
- [T04] Added :LifeModeEnsureIDs command - lua/lifemode/init.lua:115
- [T04] Created tests/uuid_spec.lua (5 tests, all passing)
- [T04] Created tests/ensure_id_spec.lua (12 tests, all passing)
- [T04] Created manual acceptance test - tests/manual_t04_test.lua
- [T03] Created lua/lifemode/parser.lua with parse_buffer() function - lua/lifemode/parser.lua:1
- [T03] Added :LifeModeParse command - lua/lifemode/init.lua:86
- [T03] Created tests/parser_spec.lua (22 tests, all passing)
- [T03] Created manual acceptance test - tests/manual_t03_test.lua
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
1. T05: Build in-memory Node model
2. T06: Basic wikilink extraction
3. T07: Bible reference extraction and parsing

## Active Decisions
| Decision | Choice | Why |
|----------|--------|-----|
| Testing approach | Custom minimal test runner | plenary not installed, needed working tests for TDD |
| Config validation | Assert vault_root required | Spec requirement |
| Leader default | `<Space>` | Spec default, user-configurable |
| ID format | UUID v4 | Spec requirement for stable, globally unique IDs |
| TDD cycle | RED → GREEN → REFACTOR | Strict adherence to TDD principles |
| UUID generation (T04) | vim.fn.system('uuidgen') | Simple, reliable, available on macOS/Linux |
| ID scope (T04) | Tasks only initially | Per spec - can expand to headings later |
| Buffer naming (T01) | `[LifeMode]` with collision handling | Use unique buffer numbers if name exists |
| View buffer options (T01) | `buftype=nofile`, `swapfile=false`, `bufhidden=wipe` | Per SPEC.md requirement |
| Extmark metadata storage (T02) | Separate table indexed by bufnr:mark_id | Neovim extmarks don't allow arbitrary keys |
| Multi-line span retrieval (T02) | Query with overlap detection | Check if extmark end_row covers target line |
| Parser block types (T03) | heading, list_item, task | Minimal set for MVP - ignore prose paragraphs |
| Task checkbox syntax (T03) | `[ ]` for todo, `[x]` or `[X]` for done | Standard Markdown syntax |
| ID extraction pattern (T03) | `^[%w%-_]+` at end of line | Matches UUID and simple IDs |

## Learnings This Session

### UUID Generation (T04)
- vim.fn.system('uuidgen') returns UUID with newline - must strip with :gsub('%s+', '')
- UUIDs from uuidgen are uppercase by default - need :lower() for consistent format
- Generated UUIDs are 36 characters (8-4-4-4-12 format with hyphens)
- Each call generates unique UUID - suitable for concurrent ID generation

### Buffer Line Manipulation (T04)
- nvim_buf_get_lines returns 1-indexed table but line numbers are 0-indexed for set_lines
- Must track line changes when modifying buffer in loop - lines table becomes stale
- nvim_buf_set_lines replaces lines in-place - update local copy for subsequent iterations
- Line modification pattern: get all lines, update each, track changes, set back

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

### Lua Pattern Matching (T03)
- `^#+ ` matches headings (one or more # at start, then space)
- `^[%-%*] ` matches list items (- or * at start, then space)
- `%[([%sxX])%]` captures checkbox state (space, x, or X)
- `%^([%w%-_]+)%s*$` extracts ID at end of line (^id format)
- Lua patterns are NOT regex - use character classes like `[%-%*]` not `[-*]`

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
2026-01-14 20:15 EST
