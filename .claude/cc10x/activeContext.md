# Active Context

## Current Focus
T09: Minimal task state toggle COMPLETE
Implemented using TDD (RED → GREEN → REFACTOR cycle)

## Recent Changes
- [T09] Created lua/lifemode/tasks.lua with toggle_task_state() - lua/lifemode/tasks.lua:1
- [T09] Added get_task_at_cursor() helper function - lua/lifemode/tasks.lua:60
- [T09] Added :LifeModeToggleTask command - lua/lifemode/init.lua:375
- [T09] Added <leader><leader> keymap for task toggle in vault files - lua/lifemode/init.lua:353
- [T09] Added <Space><Space> keymap for task toggle in view buffers - lua/lifemode/view.lua:77
- [T09] Created tests/tasks_spec.lua (17 tests, all passing)
- [T09] Created manual acceptance test - tests/manual_t09_test.lua (9 tests, all passing)
- [T09] Updated _reset_for_testing() to include :LifeModeToggleTask cleanup
- [T08] Created lua/lifemode/navigation.lua with goto_definition() - lua/lifemode/navigation.lua:1
- [T08] Added parse_wikilink_target() to parse [[Page]], [[Page#Heading]], [[Page^id]] - lua/lifemode/navigation.lua:14
- [T08] Added find_file_in_vault() to search vault recursively - lua/lifemode/navigation.lua:35
- [T08] Added jump_to_heading() to navigate to headings in buffer - lua/lifemode/navigation.lua:67
- [T08] Added jump_to_block_id() to navigate to block IDs in buffer - lua/lifemode/navigation.lua:96
- [T08] Added `gd` keymap to view buffers - lua/lifemode/view.lua:72
- [T08] Added `gd` keymap to markdown files in vault via FileType autocmd - lua/lifemode/init.lua:337
- [T08] Added :LifeModeGotoDef command - lua/lifemode/init.lua:328
- [T08] Created tests/navigation_spec.lua (19 tests, all passing)
- [T08] Created manual acceptance test - tests/manual_t08_test.lua (9 tests, all passing)
- [T08] Updated _reset_for_testing() to include :LifeModeGotoDef cleanup
- [T07a] Created lua/lifemode/references.lua with find_references_at_cursor() - lua/lifemode/references.lua:1
- [T07a] Added extract_target_at_cursor() for wikilinks and Bible refs - lua/lifemode/references.lua:14
- [T07a] Added find_references_in_buffer() for quickfix population - lua/lifemode/references.lua:72
- [T07a] Added `gr` keymap to view buffers - lua/lifemode/view.lua:65
- [T07a] Created tests/references_spec.lua (18 tests, all passing)
- [T07a] Created manual acceptance test - tests/manual_t07a_test.lua
- [T07] Created lua/lifemode/bible.lua with parse_bible_refs() - lua/lifemode/bible.lua:1
- [T07] Integrated Bible ref extraction into node.lua - lua/lifemode/node.lua:69
- [T07] Added :LifeModeBibleRefs command - lua/lifemode/init.lua:276
- [T07] Created tests/bible_spec.lua (19 tests, all passing)
- [T07] Created tests/bible_integration_spec.lua (8 tests, all passing)
- [T07] Created manual acceptance test - tests/manual_t07_test.lua
- [T07] Updated _reset_for_testing() to include :LifeModeBibleRefs cleanup
- [T06] Added extract_wikilinks() function to node.lua - lua/lifemode/node.lua:36
- [T06] Updated build_nodes_from_buffer() to extract refs and build backlinks map - lua/lifemode/node.lua:63
- [T06] Added :LifeModeRefs command - lua/lifemode/init.lua:194
- [T06] Created tests/refs_spec.lua (18 tests, all passing)
- [T06] Created manual acceptance test - tests/manual_t06_test.lua
- [T06] Updated _reset_for_testing() to include :LifeModeRefs cleanup
- [T05] Created lua/lifemode/node.lua with build_nodes_from_buffer() - lua/lifemode/node.lua:1
- [T05] Updated parser.lua to handle indented list items - lua/lifemode/parser.lua:32
- [T05] Added :LifeModeShowNodes command - lua/lifemode/init.lua:136
- [T05] Created tests/node_spec.lua (15 tests, all passing)
- [T05] Created manual acceptance test - tests/manual_t05_test.lua
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
1. T10: Continue with remaining tasks per SPEC.md

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
| Node ID generation (T05) | Auto-generate for blocks without explicit ID | Synthetic IDs using timestamp + random for uniqueness |
| Heading hierarchy (T05) | Stack-based parent tracking by heading level | # is parent of ##, ## is parent of ###, etc. |
| List hierarchy (T05) | Stack-based parent tracking by indentation | More indented items are children of less indented |
| Parser indentation (T05) | Allow leading spaces in list/task patterns | Changed `^([%-%*])` to `^%s*([%-%*])` to support nested lists |
| Extmark metadata storage (T02) | Separate table indexed by bufnr:mark_id | Neovim extmarks don't allow arbitrary keys |
| Multi-line span retrieval (T02) | Query with overlap detection | Check if extmark end_row covers target line |
| Parser block types (T03) | heading, list_item, task | Minimal set for MVP - ignore prose paragraphs |
| Task checkbox syntax (T03) | `[ ]` for todo, `[x]` or `[X]` for done | Standard Markdown syntax |
| ID extraction pattern (T03) | `^[%w%-_]+` at end of line | Matches UUID and simple IDs |
| Wikilink pattern (T06) | `%[%[([^%]]+)%]%]` | Matches [[...]] with content between brackets |
| Refs storage (T06) | Array in node.refs field | Each ref: { target, type = "wikilink" } |
| Backlinks index (T06) | Map from target → array of source node IDs | Enables quick backlink lookup |
| Wikilink target parsing (T08) | Split on # for heading, ^ for block ID | Supports [[Page]], [[Page#Heading]], [[Page^id]] formats |
| File search strategy (T08) | Use find command to search vault recursively | Case-sensitive, finds first match |
| Heading jump (T08) | Pattern match for ^#+%s+heading_text | Matches any level heading with exact text |
| Block ID jump (T08) | Pattern match for %^block_id in line | Escapes special chars in ID for pattern matching |
| Bible ref navigation (T08) | Show message stub for MVP | Provider implementation deferred to T24 |
| gd keymap scope (T08) | View buffers + markdown files in vault | FileType autocmd checks file path vs vault_root |
| Task toggle scope (T09) | Direct buffer modification | MVP approach - reparse handled by application layer |
| Task toggle keymap (T09) | <Space><Space> (leader+leader) | Per SPEC.md keybinding for task state cycle |
| Task toggle implementation (T09) | Pattern-based gsub for checkbox | Simple, reliable, preserves all content except checkbox |
| get_task_at_cursor (T09) | Parse buffer + match line_num | Uses existing parser - consistent with other features |

## Learnings This Session

### Task State Toggle (T09)
- gsub with pattern `%[ %]` and `%[[xX]%]` handles checkbox replacement reliably
- Preserving indentation: no special handling needed, gsub operates on full line
- Pattern-based toggle simpler than AST manipulation for MVP
- get_task_at_cursor: parse full buffer to find task at cursor line_num
- Return false for non-task nodes provides clear API contract
- Both hyphen and asterisk list markers work with same toggle logic
- Multiple toggles: state alternates correctly without special tracking
- FileType autocmd: keymap added to markdown files in vault automatically

### Navigation (T08)
- vim.fn.shellescape() required for paths with spaces in shell commands
- find command: `find /path -type f -name "filename.md" 2>/dev/null | head -n 1` returns first match
- Lua heredoc cannot contain nested `[[` or `]]` - use placeholders and gsub
- vim.pesc() escapes pattern chars for string comparison (used in path matching)
- nvim_set_current_buf() required before nvim_win_set_cursor() when jumping to different buffer
- Special chars in block IDs need escaping: `id:gsub("([%-%.%+%[%]%(%)%$%^%%%?%*])", "%%%1")`
- FileType autocmd with vim.api.nvim_buf_get_name() checks if file is in vault
- Navigation errors should show user-friendly messages, not throw errors
- Bible verse navigation stub for MVP - full provider deferred to T24

### Quickfix References (T07a)
- `vim.fn.setqflist()` API: cannot pass both list and options dict in same call
- Must call `vim.fn.setqflist(items, 'r')` then `vim.fn.setqflist({}, 'a', {title=...})` separately
- `string.find(pattern)` returns `(start, end, captures...)` - order matters for assignment
- Extract target at cursor: need to check if cursor position falls within match bounds
- Bible ref extraction at cursor: use first verse of range as primary target
- Wikilink targets include full syntax: `[[Page#Heading]]` is different from `[[Page]]`
- Quickfix automatically opens when `vim.cmd('copen')` is called
- Buffer-local keymaps survive quickfix window switches
- Multiple references in same line need while loop with search_pos tracking

### Bible Reference Parsing (T07)
- Lua pattern `([%d]?%s?[%a]+)%s+(%d+):(%d+)%-?(%d*)` matches Bible refs in text
- Book name normalization: remove spaces, lowercase, lookup in mapping table
- Book name mapping covers all 66 books + common abbreviations (Gen, Rom, Matt, Ps, etc.)
- Numbered books (1 Cor, 2 Tim, 1 John) handled by allowing optional digit + space in pattern
- Psalm/Psalms both normalize to "psalms" for consistency
- Verse ranges expand to individual verse IDs at extraction time (not query time)
- Bible refs automatically added to node.refs with type="bible_verse"
- Bible refs participate in backlinks system same as wikilinks
- Deterministic ID format: bible:book:chapter:verse (all lowercase, no spaces)
- Pattern-based extraction works in free text, not just isolated refs
- :LifeModeBibleRefs shows all Bible refs in buffer with node context

### Wikilink Extraction (T06)
- Lua pattern `%[%[([^%]]+)%]%]` captures content between [[ and ]]
- Pattern `[^%]]+` matches any character except ], stopping at first closing bracket
- Empty wikilinks [[]] should be filtered out with target:match("%S") check
- Backlinks map structure: { [target] = {source_id1, source_id2, ...} }
- Node refs field: array of { target = "Page", type = "wikilink" }
- Wikilink targets include full syntax: "Page", "Page#Heading", "Page^block-id"
- Build backlinks during node creation to avoid second pass
- :LifeModeRefs command requires cursor-to-node mapping (simplified for MVP)

### Node Model (T05)
- Stack-based hierarchy tracking is clean for both heading levels and list indentation
- Parser needed enhancement to support indented lists (added `%s*` prefix to patterns)
- Node structure: { id, type, body_md, children, props }
- Synthetic ID generation uses timestamp + random for uniqueness
- Tree context must reset when switching between headings and lists
- List items under a heading become children of that heading

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
2026-01-14 23:15 EST
