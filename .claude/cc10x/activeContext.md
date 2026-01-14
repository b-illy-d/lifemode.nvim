# Active Context

## Current Focus
T18: Multi-file index (vault scan MVP) COMPLETE
Implemented using TDD (RED → GREEN → REFACTOR cycle)

## Recent Changes
- [T18] Created lua/lifemode/index.lua module for vault-wide indexing - lua/lifemode/index.lua:1
- [T18] Added scan_vault(vault_root) to find all .md files recursively - lua/lifemode/index.lua:8
- [T18] Added build_vault_index(vault_root) to parse all files and build global index - lua/lifemode/index.lua:35
- [T18] Added get_node_location(idx, node_id) to lookup node file/line - lua/lifemode/index.lua:103
- [T18] Added get_backlinks(idx, target) to get all source nodes referencing target - lua/lifemode/index.lua:109
- [T18] Updated find_references_at_cursor() to use vault index when available - lua/lifemode/references.lua:196
- [T18] Added find_references_in_vault() to search across all files - lua/lifemode/references.lua:172
- [T18] Added :LifeModeRebuildIndex command - lua/lifemode/init.lua:470
- [T18] Index stored in config.vault_index for gr to use - lua/lifemode/init.lua:491
- [T18] Updated _reset_for_testing() to include :LifeModeRebuildIndex cleanup - lua/lifemode/init.lua:653
- [T18] Created tests/index_spec.lua (11 tests, all passing)
- [T18] Created manual acceptance test - tests/manual_t18_test.lua (9 tests, all passing)
- [T17] Added get_due(line) to extract @due(YYYY-MM-DD) from line - lua/lifemode/tasks.lua:408
- [T17] Added set_due(line, date) to add/update/remove due dates - lua/lifemode/tasks.lua:416
- [T17] Added set_due_buffer(bufnr, node_id, date) for buffer operations - lua/lifemode/tasks.lua:448
- [T17] Added clear_due_buffer(bufnr, node_id) to remove due dates - lua/lifemode/tasks.lua:490
- [T17] Added set_due_interactive() for prompted due date setting - lua/lifemode/tasks.lua:522
- [T17] Added clear_due_interactive() for due date removal - lua/lifemode/tasks.lua:569
- [T17] Added :LifeModeSetDue command - lua/lifemode/init.lua:458
- [T17] Added :LifeModeClearDue command - lua/lifemode/init.lua:465
- [T17] Added <Space>td keymap for due date in vault files - lua/lifemode/init.lua:516
- [T17] Added <Space>td keymap for due date in view buffers - lua/lifemode/view.lua:134
- [T17] Updated _reset_for_testing() to include :LifeModeSetDue and :LifeModeClearDue - lua/lifemode/init.lua:616-621
- [T17] Created tests/due_spec.lua (21 tests, all passing)
- [T17] Created manual acceptance test - tests/manual_t17_test.lua (10 tests, all passing)
- [T16] Added get_tags(line) to extract all #tag and #tag/subtag from line - lua/lifemode/tasks.lua:221
- [T16] Added add_tag(bufnr, node_id, tag) to add tags to task lines - lua/lifemode/tasks.lua:232
- [T16] Added remove_tag(bufnr, node_id, tag) to remove tags from tasks - lua/lifemode/tasks.lua:291
- [T16] Added add_tag_interactive() for prompted tag addition - lua/lifemode/tasks.lua:334
- [T16] Added remove_tag_interactive() for prompted tag removal - lua/lifemode/tasks.lua:370
- [T16] Added :LifeModeAddTag command - lua/lifemode/init.lua:442
- [T16] Added :LifeModeRemoveTag command - lua/lifemode/init.lua:449
- [T16] Added <Space>tt keymap for tag addition in vault files - lua/lifemode/init.lua:500
- [T16] Added <Space>tt keymap for tag addition in view buffers - lua/lifemode/view.lua:128
- [T16] Created tests/tags_spec.lua (22 tests, all passing)
- [T16] Created manual acceptance test - tests/manual_t16_test.lua (10 tests, all passing)
- [T15] Added max_nodes_per_action config option (default: 100) - lua/lifemode/init.lua:12
- [T15] Added config validation for max_nodes_per_action (1-10000) - lua/lifemode/init.lua:47
- [T15] Implemented cycle detection in expand_instance() - lua/lifemode/render.lua:90
- [T15] Added expansion path tracking to detect cycles - lua/lifemode/render.lua:75
- [T15] Cycle stub renders "↩ already shown" for detected cycles - lua/lifemode/render.lua:100
- [T15] Added depth tracking in expanded_instances metadata - lua/lifemode/render.lua:12
- [T15] Max depth check before expansion (respects config.max_depth) - lua/lifemode/render.lua:107
- [T15] Max nodes per action limit enforced during child rendering - lua/lifemode/render.lua:118
- [T15] Updated expanded_instances to include depth and expansion_path - lua/lifemode/render.lua:177
- [T15] Created tests/expansion_limits_spec.lua (6 tests, all passing)
- [T15] Created manual acceptance test - tests/manual_t15_test.lua (6 tests, all passing)
- [T14] Added expand_instance(bufnr, line) to expand nodes with children - lua/lifemode/render.lua:23
- [T14] Added collapse_instance(bufnr, line) to remove expanded children - lua/lifemode/render.lua:133
- [T14] Added is_expanded(bufnr, instance_id) to track expansion state - lua/lifemode/render.lua:14
- [T14] Added module-level expanded_instances table for state tracking - lua/lifemode/render.lua:7
- [T14] Added module-level _node_cache for accessing node data during expand - lua/lifemode/render.lua:186
- [T14] Node cache populated in render_page_view() for all nodes_by_id - lua/lifemode/render.lua:189
- [T14] Expand renders children using choose_lens() and lens.render() - lua/lifemode/render.lua:72
- [T14] Expand inserts child lines after parent span and sets extmarks - lua/lifemode/render.lua:95
- [T14] Collapse deletes child lines using buffer line operations - lua/lifemode/render.lua:147
- [T14] Expansion state includes child_instance_ids, insert_line, line_count - lua/lifemode/render.lua:119
- [T14] Repeated expand is idempotent (early return if already expanded) - lua/lifemode/render.lua:37
- [T14] Added keymaps <Space>e (expand) and <Space>E (collapse) to view buffers - lua/lifemode/render.lua:237
- [T14] Created tests/expand_spec.lua (6 tests, all passing)
- [T14] Created manual acceptance test - tests/manual_t14_test.lua (11 tests, all passing)
- [T13] Created lua/lifemode/render.lua with render_page_view() function - lua/lifemode/render.lua:1
- [T13] Added generate_instance_id() for unique instance identification - lua/lifemode/render.lua:11
- [T13] Added choose_lens(node_data) to select appropriate lens (task/brief or node/raw) - lua/lifemode/render.lua:18
- [T13] Implemented render_page_view(source_bufnr) parsing source and rendering root nodes - lua/lifemode/render.lua:26
- [T13] View buffer creation with proper options (nofile, swapfile=false, bufhidden=wipe) - lua/lifemode/render.lua:37
- [T13] Extmark metadata set after buffer populated (fixed async issue) - lua/lifemode/render.lua:87
- [T13] Renders only root nodes (top-level, no parents) to view - lua/lifemode/render.lua:52
- [T13] Handles both string and table return types from lens.render() - lua/lifemode/render.lua:61
- [T13] Added :LifeModePageView command - lua/lifemode/init.lua:498
- [T13] Integrated active node tracking in PageView command - lua/lifemode/init.lua:505
- [T13] Updated _reset_for_testing() to include :LifeModePageView cleanup - lua/lifemode/init.lua:577
- [T13] Created tests/render_spec.lua (11 tests, all passing)
- [T13] Created manual acceptance test - tests/manual_t13_test.lua (11 tests, all passing)
- [T12] Created lua/lifemode/activenode.lua with active node tracking - lua/lifemode/activenode.lua:1
- [T12] Added highlight_active_span(bufnr, start_line, end_line) for visual distinction - lua/lifemode/activenode.lua:25
- [T12] Added clear_active_highlight(bufnr) to remove highlights - lua/lifemode/activenode.lua:47
- [T12] Added update_winbar(bufnr, node_info) to show type/ID/lens - lua/lifemode/activenode.lua:64
- [T12] Added update_active_node(bufnr) to sync highlight + winbar with cursor - lua/lifemode/activenode.lua:102
- [T12] Added track_cursor_movement(bufnr) with CursorMoved autocmd - lua/lifemode/activenode.lua:138
- [T12] Defined LifeModeActiveNode highlight group (subtle gray background) - lua/lifemode/activenode.lua:14
- [T12] Integrated active node tracking into view.create_buffer() - lua/lifemode/view.lua:153
- [T12] Winbar is window-local, updates all windows showing buffer - lua/lifemode/activenode.lua:88
- [T12] Type extracted from node_id prefix if not in metadata - lua/lifemode/activenode.lua:117
- [T12] Created tests/activenode_spec.lua (15 tests, all passing)
- [T12] Created manual acceptance test - tests/manual_t12_test.lua (10 tests, all passing)
- [T11] Created lua/lifemode/lens.lua with lens registry and render functions - lua/lifemode/lens.lua:1
- [T11] Added get_available_lenses() returning lens_order array - lua/lifemode/lens.lua:12
- [T11] Added render(node, lens_name) with fallback to node/raw - lua/lifemode/lens.lua:59
- [T11] Added cycle_lens(current_lens, direction) with wrapping - lua/lifemode/lens.lua:74
- [T11] Implemented task/brief lens (hides ID, shows title + priority) - lua/lifemode/lens.lua:21
- [T11] Implemented task/detail lens (shows all metadata including tags) - lua/lifemode/lens.lua:30
- [T11] Implemented node/raw lens (exact body_md) - lua/lifemode/lens.lua:50
- [T11] Added :LifeModeLensNext command - lua/lifemode/init.lua:472
- [T11] Added :LifeModeLensPrev command - lua/lifemode/init.lua:483
- [T11] Added <Space>ml keymap for lens cycle next in view buffers - lua/lifemode/view.lua:129
- [T11] Added <Space>mL keymap for lens cycle prev in view buffers - lua/lifemode/view.lua:139
- [T11] Updated _reset_for_testing() to include :LifeModeLensNext and :LifeModeLensPrev cleanup
- [T11] Created tests/lens_spec.lua (23 tests, all passing)
- [T11] Created manual acceptance test - tests/manual_t11_test.lua (15 tests, all passing)
- [T10] Added get_priority(line) to extract priority from task line - lua/lifemode/tasks.lua:83
- [T10] Added set_priority(line, priority) to update/add/remove priority - lua/lifemode/tasks.lua:93
- [T10] Added inc_priority(bufnr, node_id) to increase priority (toward !1) - lua/lifemode/tasks.lua:117
- [T10] Added dec_priority(bufnr, node_id) to decrease priority (toward !5) - lua/lifemode/tasks.lua:155
- [T10] Added :LifeModeIncPriority command - lua/lifemode/init.lua:394
- [T10] Added :LifeModeDecPriority command - lua/lifemode/init.lua:409
- [T10] Added <Space>tp keymap for inc_priority in vault files - lua/lifemode/init.lua:427
- [T10] Added <Space>tP keymap for dec_priority in vault files - lua/lifemode/init.lua:445
- [T10] Added <Space>tp keymap for inc_priority in view buffers - lua/lifemode/view.lua:95
- [T10] Added <Space>tP keymap for dec_priority in view buffers - lua/lifemode/view.lua:110
- [T10] Created tests/priority_spec.lua (24 tests, all passing)
- [T10] Created manual acceptance test - tests/manual_t10_test.lua (9 tests, all passing)
- [T10] Updated _reset_for_testing() to include :LifeModeIncPriority and :LifeModeDecPriority cleanup
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
| Index storage (T18) | Store in config.vault_index after rebuild | Simple MVP approach - no persistent cache, rebuild on demand |
| Index scope (T18) | node_id → (file, line) + backlinks map | Core data structures for cross-file navigation and references |
| File scanning (T18) | Use find command with *.md pattern | Simple, portable, works on macOS/Linux |
| Node location lookup (T18) | Match ^id pattern in lines | Find exact line containing node ID marker |
| Backlinks merging (T18) | Accumulate from all files during index build | Single pass to build complete backlinks map |
| References fallback (T18) | Use current buffer when index not available | Graceful degradation - gr works without index |
| Config safety (T18) | pcall around get_config in references.lua | Avoid errors when lifemode not configured |
| Due date syntax (T17) | `@due(YYYY-MM-DD)` inline marker | Per SPEC.md requirement, strict format validation |
| Due date pattern (T17) | `@due%((%d%d%d%d%-%d%d%-%d%d)%)` | Validates YYYY-MM-DD format at extraction time |
| Due date placement (T17) | Before ^id if present, else end of line | Consistent with priority and tag placement patterns |
| Due date validation (T17) | Format check only (YYYY-MM-DD) | MVP approach - semantic validation (valid dates, not in past) deferred |
| Due date removal (T17) | set_due(line, nil) or empty string | Consistent API - nil removes, string sets |
| Interactive prompt (T17) | vim.fn.input() with current due shown | Simple MVP approach, shows current date as default |
| Keymap for due (T17) | <Space>td for set_due_interactive | Per SPEC.md requirement, mnemonic "task due" |
| Tag syntax (T16) | `#tag/subtag` with slash for hierarchy | Per SPEC.md requirement, consistent with common tag conventions |
| Tag pattern (T16) | `#([%w_/-]+)` | Matches word chars, underscore, slash, hyphen for flexible tagging |
| Tag placement (T16) | Before ^id if present, else end of line | Consistent with priority placement pattern |
| Duplicate tag handling (T16) | Skip silently (return true) | Idempotent add operation - no error on duplicate |
| Tag removal spacing (T16) | Match tag with leading space, clean up doubles | Prevents double spaces after removal |
| Interactive prompt (T16) | vim.fn.input() with current tags shown | Simple MVP approach, shows context to user |
| Tag input cleanup (T16) | Strip # prefix and whitespace | User can type "#tag" or "tag", both work |
| Keymap for tags (T16) | <Space>tt for add_tag_interactive | Per SPEC.md requirement, mnemonic "task tags" |
| Cycle stub text (T15) | "↩ already shown" | Simple, clear indicator that node already in expansion path |
| Cycle detection scope (T15) | Per-expansion-path, not global | Same node in different branches is OK, only detect in current path |
| Max nodes per action default (T15) | 100 | Balance between performance and utility, configurable 1-10000 |
| Max depth check timing (T15) | Before expanding children | Prevents unnecessary work when at depth limit |
| Cycle stub interactivity (T15) | Non-interactive (no span metadata) | Stub is informational only, not expandable |
| Depth tracking storage (T15) | In expanded_instances metadata | Enables depth checking without re-traversing tree |
| Expansion path tracking (T15) | Array of node_ids in expansion order | Simple structure for cycle detection |
| Expand/collapse keybindings (T14) | <Space>e (expand), <Space>E (collapse) | Per SPEC.md requirement |
| Expansion state storage (T14) | Module-level expanded_instances table | Tracks which instances are expanded per buffer |
| Node data access during expand (T14) | Module-level _node_cache populated by render_page_view | Enables expand to access node children without re-parsing |
| Repeated expand behavior (T14) | Idempotent (early return if already expanded) | Prevents duplicate children per acceptance criteria |
| Collapse implementation (T14) | Delete lines using nvim_buf_set_lines | Simple buffer manipulation, extmarks auto-removed |
| Expansion depth (T14) | One level only | MVP approach - expand shows immediate children, not grandchildren |
| Lens order (T11) | task/brief, task/detail, node/raw | Simple progression from brief to detailed to raw |
| Lens render return type (T11) | string or table of lines | Allows multiline rendering for detail lens |
| Lens fallback (T11) | node/raw for unknown lenses | Graceful degradation - always show something |
| Lens cycling wrap (T11) | Wrap at boundaries | UX: cycle continuously, no dead ends |
| Lens commands MVP (T11) | Show message, no re-render | Core lens system first, view integration later (T12-T14) |
| Lens keymaps (T11) | <Space>ml (next), <Space>mL (prev) | Per SPEC.md requirement |
| task/brief display (T11) | Hide ID, show title + priority | Brief lens for quick scanning |
| task/detail display (T11) | Show all metadata including ID and tags | Full context for detailed inspection |
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
| Priority syntax (T10) | !1 to !5 inline markers | Per SPEC.md - !1 highest, !5 lowest |
| Priority extraction (T10) | Pattern match `!([1-5])` | Validates range 1-5, ignores invalid values |
| Priority placement (T10) | Before ^id if present, else end of line | Keeps priority close to task content, before ID |
| Inc priority default (T10) | Add !5 when no priority exists | Start at lowest when first adding priority |
| Dec priority on no priority (T10) | Do nothing | Don't add priority when decreasing - only remove |
| Priority boundary behavior (T10) | Stop at !1 and !5 | Don't wrap around - stay at boundaries |
| Active node highlight (T12) | Subtle gray background (#2d3436) | Visual distinction without distraction |
| Winbar format (T12) | "Type: X \| ID: Y \| Lens: Z" | Pipe-separated for clarity |
| Node type extraction (T12) | From node_id prefix if not in metadata | Extract before hyphen (task-123 → task) |
| Highlight namespace (T12) | Separate from span metadata namespace | Different concerns, different namespaces |
| Cursor tracking scope (T12) | Per-buffer autocmd group | Named 'LifeModeActiveNode_' + bufnr |

## Learnings This Session

### Multi-file Indexing (T18)
- vim.loop.fs_stat() checks if path exists and gets type (directory/file)
- find command with shellescape handles paths with spaces: `find <path> -type f -name '*.md'`
- Building index requires parsing each file: read into buffer, parse, extract locations
- Node location lookup: search for ^id pattern in file lines, store file + line number
- Backlinks accumulate across files: merge each file's backlinks into global map
- Parser only creates nodes for block types (headings, lists, tasks) - not plain paragraphs
- References.find_references_at_cursor should handle missing config gracefully with pcall
- Vault index stored in config, persists until setup() called again (resets config)
- Index rebuild is on-demand via :LifeModeRebuildIndex command
- gr automatically uses vault index if available, falls back to buffer search if not
- Test files must use proper block types (list items) for IDs to be indexed
- find command returns newline-separated paths - use gmatch to split into array
- Temporary buffers for parsing must set filetype to 'markdown' for proper parsing

### Due Date Operations (T17)
- Due date pattern `@due%((%d%d%d%d%-%d%d%-%d%d)%)` strictly validates YYYY-MM-DD format
- Lua pattern `%d%d%d%d` requires exactly 4 digits (validates year format)
- Due date placement follows same pattern as priority and tags (before ^id)
- set_due(line, nil) and set_due(line, '') both remove due date
- Multiple gsub cleanup steps needed: remove due, clean double spaces, clean trailing spaces
- Spacing cleanup pattern: `%s%s+` → ` ` collapses multiple spaces to single space
- Format validation at both extraction (get_due) and setting (set_due_buffer) ensures consistency
- Empty string handling: treat '' same as nil for removal operations
- Interactive prompt shows current due date as default input for easy editing
- Date format validation message guides user: "Use YYYY-MM-DD" when format invalid

### Expansion Limits (T15)
- Cycle detection checks if child_id appears in expansion_path array before rendering
- Expansion path tracks node_ids from root to current node during expansion
- Cycle stub is non-interactive (no span metadata) - just an informational line
- Same node in different branches is NOT a cycle - only same path matters
- max_nodes_per_action limits children rendered per expand action, not total nodes
- Depth is tracked per-instance in expanded_instances metadata
- Check depth BEFORE expanding to avoid unnecessary work
- Manual cache manipulation in tests simulates cyclic references not expressible in markdown
- Unique IDs mean markdown can't directly express cycles (A→B→A creates single "a" node)
- Cycle detection: check if child is in ancestors, not if current node was seen before

### Expand/Collapse (T14)
- Module-level state (_node_cache and expanded_instances) enables expand/collapse without re-parsing
- Node cache must be populated during render_page_view for all nodes_by_id, not just roots
- Expansion tracking per buffer: expanded_instances[bufnr][instance_id] = {child_instance_ids, insert_line, line_count}
- Early return pattern for idempotent expand: check is_expanded before adding children
- Collapse by deleting lines: nvim_buf_set_lines(bufnr, start, end, false, {}) removes child spans
- Extmarks automatically cleaned up when lines deleted - no manual cleanup needed
- One level expansion: only immediate children shown, grandchildren remain hidden until parent child is expanded
- Keymaps must reference correct buffer in closure: use view_bufnr not dynamic buffer query
- Cache key format: string.format("%d:%s", bufnr, node_id) for unique buffer+node identification

### Compiled View Rendering (T13)
- Extmarks must be set AFTER buffer lines are populated, not before
- Store span metadata in intermediate structure, then apply after buffer set
- Root nodes are top-level (no parent) - hierarchy determines what gets rendered
- Blank lines don't break hierarchy - list items after heading remain children
- choose_lens pattern: tasks use task/brief, everything else uses node/raw
- Instance IDs must be unique per rendered node instance (not per node_id)
- lens.render() can return string or table - handle both with type() check
- View buffer integrated with active node tracking via track_cursor_movement()
- :LifeModePageView creates compiled view from current source buffer
- Rendering pipeline: parse → build nodes → filter roots → render each → set extmarks

## Previous Learnings

### Active Node Tracking (T12)
- Winbar is window-local, not buffer-local - must use nvim_win_set_option not nvim_buf_set_option
- Set winbar for ALL windows showing buffer using nvim_list_wins() + nvim_win_get_buf()
- CursorMoved and CursorMovedI autocmds track both normal and insert mode cursor movement
- Highlight group with `default = true` allows user overrides in their config
- hl_eol = true extends highlight to end of line even if text is shorter
- Type field can be extracted from node_id prefix with pattern matching (e.g., "task-123" → "task")
- Extmark namespace for highlights is separate from span metadata namespace
- Test module loading: require() fresh in each test when package.loaded is reset
- Autocmd groups named per buffer prevent conflicts: 'LifeModeActiveNode_' .. bufnr
- Integration point: call track_cursor_movement() in view.create_buffer() for automatic activation

### Lens System (T11)
- Lens registry as ordered array enables simple cycling with wraparound
- Return type flexibility (string or table) allows single-line and multiline rendering
- Fallback to node/raw ensures lens.render() always returns something
- MVP approach: build lens rendering first, defer view integration to T12-T14
- task/brief: strip ID with gsub pattern `%s*%^[%w%-_]+%s*$` for clean display
- task/detail: multiline rendering for rich metadata display (tags, etc.)
- node/raw: simplest lens - just return body_md as-is
- Lens cycling: modulo arithmetic with wraparound for seamless UX
- Commands and keymaps registered even if re-render not yet implemented

### Task Priority Bump (T10)
- Priority pattern `!([1-5])` validates range at extraction time - invalid values return nil
- set_priority must handle three cases: update existing, add new, remove (nil)
- Priority placement: before ^id with space preservation using capture groups `(%s+)(%^[%w%-_]+%s*)$`
- inc_priority adds !5 as default when no priority - start at lowest when first adding
- dec_priority does nothing when no priority - don't add priority on decrease
- Boundary behavior: stop at !1 and !5, don't wrap around
- Keymaps: <Space>tp (increase) and <Space>tP (decrease) work in view buffers and vault files
- Normalized keymap lhs: Neovim stores `<Space>` as ` ` (space char) in keymap table

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
2026-01-14 23:45 EST
