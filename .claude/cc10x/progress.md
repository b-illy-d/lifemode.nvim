# Progress Tracking

## Current Workflow
T07a COMPLETE

## Completed
- [x] Memory files initialized
- [x] T00 - Repo skeleton + plugin bootstrap - commit 0dd2003
  - Status: CONDITIONAL PASS (needs hotfix for 3 critical bugs)
  - Code Review: Grade A- (approved)
  - Tests: 7/7 happy path, 16/21 edge cases (5 failures expected)
  - Silent Failures: 5 found (3 blocking for T01)
- [x] T01 - View buffer creation utility
  - TDD: RED (exit 1) → GREEN (exit 0) → REFACTOR
  - Tests: 10/10 passing
  - Files: lua/lifemode/view.lua (created), lua/lifemode/init.lua (modified)
  - Acceptance: :LifeModeOpen creates buffer with correct options
- [x] T02 - Extmark-based span mapping
  - TDD: RED (exit 1) → GREEN (exit 0) → REFACTOR
  - Tests: 15/15 passing
  - Files: lua/lifemode/extmarks.lua (created), lua/lifemode/init.lua (modified), lua/lifemode/view.lua (modified)
  - Acceptance: :LifeModeDebugSpan prints metadata at cursor
- [x] T03 - Minimal Markdown block parser
  - TDD: RED (exit 1) → GREEN (exit 0) → REFACTOR
  - Tests: 22/22 passing
  - Files: lua/lifemode/parser.lua (created), lua/lifemode/init.lua (modified)
  - Acceptance: :LifeModeParse parses current buffer and prints block + task count
- [x] T04 - Ensure IDs for indexable blocks
  - TDD: RED (exit 1) → GREEN (exit 0) → REFACTOR
  - Tests: 17/17 passing (5 UUID tests + 12 ensure_id tests)
  - Files: lua/lifemode/uuid.lua (created), lua/lifemode/blocks.lua (created), lua/lifemode/init.lua (modified)
  - Acceptance: :LifeModeEnsureIDs adds UUIDs to tasks and preserves content
- [x] T05 - Build in-memory Node model
  - TDD: RED (exit 1) → GREEN (exit 0) → REFACTOR
  - Tests: 15/15 passing (node_spec.lua)
  - Files: lua/lifemode/node.lua (created), lua/lifemode/parser.lua (modified), lua/lifemode/init.lua (modified)
  - Acceptance: :LifeModeShowNodes prints node tree with hierarchy
- [x] T06 - Basic wikilink extraction
  - TDD: RED (exit 1, 18 failures) → GREEN (exit 0, 18 passes) → REFACTOR
  - Tests: 18/18 passing (refs_spec.lua)
  - Files: lua/lifemode/node.lua (modified), lua/lifemode/init.lua (modified)
  - Acceptance: :LifeModeRefs shows outbound refs and backlinks for node at cursor

## In Progress
None

## Just Completed
- [x] T07a - Quickfix "references" view
  - TDD: RED (exit 1, module not found) → GREEN (exit 0, 18/18) → REFACTOR
  - Tests: 18/18 references_spec.lua
  - Files: lua/lifemode/references.lua (created), lua/lifemode/view.lua (modified)
  - Acceptance: `gr` opens quickfix with correct matches for wikilinks and Bible verses; handles edge cases gracefully

## Blocked
None

## Remaining
- [ ] T08: "Definition" jump for wikilinks and Bible refs
- [ ] T09-T30: (remaining per SPEC.md)

## Verification Evidence

### T00
| Check | Command | Exit Code | Result |
|-------|---------|-----------|--------|
| Happy Path Tests | `nvim -l tests/run_tests.lua` | 0 | **PASS (7/7)** |
| Edge Case Tests | `nvim -l tests/edge_cases_spec.lua` | 1 | FAIL (16/21, 5 bugs found) |
| Runtime Tests | `nvim -l tests/runtime_edge_cases_spec.lua` | 0 | **PASS (15/15)** |

### T01
| Check | Command | Exit Code | Result |
|-------|---------|-----------|--------|
| View Tests | `nvim -l tests/view_spec.lua` | 0 | **PASS (10/10)** |
| All Unit Tests | `nvim -l tests/run_tests.lua` | 0 | **PASS (7/7)** |
| Manual Test | `:LifeModeOpen` | 0 | Buffer created with correct options |

### T02
| Check | Command | Exit Code | Result |
|-------|---------|-----------|--------|
| Extmarks Tests | `nvim -l tests/extmarks_spec.lua` | 0 | **PASS (15/15)** |
| View Tests | `nvim -l tests/view_spec.lua` | 0 | **PASS (10/10)** |
| All Unit Tests | `nvim -l tests/run_tests.lua` | 0 | **PASS (7/7)** |
| Manual Test | `nvim -l tests/manual_t02_test.lua` | 0 | All acceptance criteria met |

### T03
| Check | Command | Exit Code | Result |
|-------|---------|-----------|--------|
| Parser Tests | `nvim -l tests/parser_spec.lua` | 0 | **PASS (22/22)** |
| Regression: Init | `nvim -l tests/run_tests.lua` | 0 | **PASS (7/7)** |
| Regression: View | `nvim -l tests/view_spec.lua` | 0 | **PASS (10/10)** |
| Regression: Extmarks | `nvim -l tests/extmarks_spec.lua` | 0 | **PASS (15/15)** |
| Manual Test | `nvim -l tests/manual_t03_test.lua` | 0 | All acceptance criteria met |

### T04
| Check | Command | Exit Code | Result |
|-------|---------|-----------|--------|
| UUID Tests | `nvim -l tests/uuid_spec.lua` | 0 | **PASS (5/5)** |
| Ensure ID Tests | `nvim -l tests/ensure_id_spec.lua` | 0 | **PASS (12/12)** |
| Regression: Init | `nvim -l tests/run_tests.lua` | 0 | **PASS (7/7)** |
| Regression: View | `nvim -l tests/view_spec.lua` | 0 | **PASS (10/10)** |
| Regression: Extmarks | `nvim -l tests/extmarks_spec.lua` | 0 | **PASS (15/15)** |
| Regression: Parser | `nvim -l tests/parser_spec.lua` | 0 | **PASS (22/22)** |
| Manual Test | `nvim -l tests/manual_t04_test.lua` | 0 | All acceptance criteria met |

### T05
| Check | Command | Exit Code | Result |
|-------|---------|-----------|--------|
| Node Tests | `nvim -l tests/node_spec.lua` | 0 | **PASS (15/15)** |
| Regression: Init | `nvim -l tests/run_tests.lua` | 0 | **PASS (7/7)** |
| Regression: View | `nvim -l tests/view_spec.lua` | 0 | **PASS (10/10)** |
| Regression: Extmarks | `nvim -l tests/extmarks_spec.lua` | 0 | **PASS (15/15)** |
| Regression: Parser | `nvim -l tests/parser_spec.lua` | 0 | **PASS (22/22)** |
| Regression: UUID | `nvim -l tests/uuid_spec.lua` | 0 | **PASS (5/5)** |
| Regression: Ensure ID | `nvim -l tests/ensure_id_spec.lua` | 0 | **PASS (12/12)** |
| Manual Test | `nvim -l tests/manual_t05_test.lua` | 0 | All acceptance criteria met |

### T06
| Check | Command | Exit Code | Result |
|-------|---------|-----------|--------|
| Refs Tests | `nvim -l tests/refs_spec.lua` | 0 | **PASS (18/18)** |
| Regression: Init | `nvim -l tests/run_tests.lua` | 0 | **PASS (7/7)** |
| Regression: View | `nvim -l tests/view_spec.lua` | 0 | **PASS (10/10)** |
| Regression: Extmarks | `nvim -l tests/extmarks_spec.lua` | 0 | **PASS (15/15)** |
| Regression: Parser | `nvim -l tests/parser_spec.lua` | 0 | **PASS (22/22)** |
| Regression: UUID | `nvim -l tests/uuid_spec.lua` | 0 | **PASS (5/5)** |
| Regression: Ensure ID | `nvim -l tests/ensure_id_spec.lua` | 0 | **PASS (12/12)** |
| Regression: Node | `nvim -l tests/node_spec.lua` | 0 | **PASS (15/15)** |
| Manual Test | `nvim -l tests/manual_t06_test.lua` | 0 | All acceptance criteria met |

### T07
| Check | Command | Exit Code | Result |
|-------|---------|-----------|--------|
| Bible Tests | `nvim -l tests/bible_spec.lua` | 0 | **PASS (19/19)** |
| Integration Tests | `nvim -l tests/bible_integration_spec.lua` | 0 | **PASS (8/8)** |
| Regression: Init | `nvim -l tests/run_tests.lua` | 0 | **PASS (7/7)** |
| Regression: View | `nvim -l tests/view_spec.lua` | 0 | **PASS (10/10)** |
| Regression: Extmarks | `nvim -l tests/extmarks_spec.lua` | 0 | **PASS (15/15)** |
| Regression: Parser | `nvim -l tests/parser_spec.lua` | 0 | **PASS (22/22)** |
| Regression: UUID | `nvim -l tests/uuid_spec.lua` | 0 | **PASS (5/5)** |
| Regression: Ensure ID | `nvim -l tests/ensure_id_spec.lua` | 0 | **PASS (12/12)** |
| Regression: Node | `nvim -l tests/node_spec.lua` | 0 | **PASS (15/15)** |
| Regression: Refs | `nvim -l tests/refs_spec.lua` | 0 | **PASS (18/18)** |
| Manual Test | `nvim -l tests/manual_t07_test.lua` | 0 | All acceptance criteria met |

### T07a
| Check | Command | Exit Code | Result |
|-------|---------|-----------|--------|
| References Tests | `nvim -l tests/references_spec.lua` | 0 | **PASS (18/18)** |
| Regression: Init | `nvim -l tests/run_tests.lua` | 0 | **PASS (7/7)** |
| Regression: View | `nvim -l tests/view_spec.lua` | 0 | **PASS (10/10)** |
| Regression: Extmarks | `nvim -l tests/extmarks_spec.lua` | 0 | **PASS (15/15)** |
| Regression: Parser | `nvim -l tests/parser_spec.lua` | 0 | **PASS (22/22)** |
| Regression: UUID | `nvim -l tests/uuid_spec.lua` | 0 | **PASS (5/5)** |
| Regression: Ensure ID | `nvim -l tests/ensure_id_spec.lua` | 0 | **PASS (12/12)** |
| Regression: Node | `nvim -l tests/node_spec.lua` | 0 | **PASS (15/15)** |
| Regression: Refs | `nvim -l tests/refs_spec.lua` | 0 | **PASS (18/18)** |
| Regression: Bible | `nvim -l tests/bible_spec.lua` | 0 | **PASS (19/19)** |
| Manual Test | `nvim -l tests/manual_t07a_test.lua` | 0 | All acceptance criteria met |

## Known Issues (T00)

### BLOCKING for T01 (Must Fix)
1. **Type validation missing** - Optional config accepts any type, will crash on keymap/comparison
   - Fix: Add type checks after merge (3 lines)
2. **Empty string validation** - vault_root accepts empty/whitespace, cryptic file errors
   - Fix: Add whitespace check (1 line)
3. **Boundary validation** - max_depth accepts 0, negative, huge values (stack overflow risk)
   - Fix: Enforce bounds 1-100 (1 line)

### Non-Blocking (Defer/Document)
4. Config merge resets values on multiple setup() calls (document behavior)
5. No path normalization (defer to T01+)
6. Code reviewer suggestions (defer to T02+)

## Evolution of Decisions
- Changed from plenary.nvim to custom test runner (plenary not installed)

## Implementation Results

### T00
| Planned | Actual | Deviation Reason |
|---------|--------|------------------|
| plenary.nvim for tests | Custom minimal test runner | plenary not available, needed working tests |
| All T00 requirements | All implemented + tests | No deviation |

### T01
| Planned | Actual | Deviation Reason |
|---------|--------|------------------|
| Buffer name `[LifeMode]` | `[LifeMode]` or `[LifeMode:N]` | Handle collision when multiple buffers created in tests |
| All T01 requirements | All implemented + tests | No deviation |

### T02
| Planned | Actual | Deviation Reason |
|---------|--------|------------------|
| Store metadata in extmark | Store in separate table | Neovim extmarks don't allow arbitrary keys |
| All T02 requirements | All implemented + tests + example spans | No deviation |

### T03
| Planned | Actual | Deviation Reason |
|---------|--------|------------------|
| Parse headings + list items | Implemented with task detection | Added task type per SPEC.md requirements |
| Extract task state + IDs | Implemented with pattern matching | No deviation |
| All T03 requirements | All implemented + 22 tests + manual test | No deviation |

### T04
| Planned | Actual | Deviation Reason |
|---------|--------|------------------|
| UUID generation | vim.fn.system('uuidgen') | Simplest approach for macOS/Linux |
| ensure_id for tasks | Implemented in blocks.lua module | Separate module for block operations |
| All T04 requirements | All implemented + 17 tests + manual test + command | No deviation |

### T05
| Planned | Actual | Deviation Reason |
|---------|--------|------------------|
| Node model structure | { id, type, body_md, children, props } | Per SPEC.md - refs deferred to T06/T07 |
| Hierarchy detection | Stack-based for both headings and lists | Clean approach for nested structures |
| Parser enhancement | Added `%s*` prefix to list patterns | Needed to support indented lists |
| All T05 requirements | All implemented + 15 tests + manual test + command | No deviation |

### T06
| Planned | Actual | Deviation Reason |
|---------|--------|------------------|
| Wikilink extraction | Pattern `%[%[([^%]]+)%]%]` | Matches all three formats: [[Page]], [[Page#Heading]], [[Page^id]] |
| Node refs field | Array of { target, type = "wikilink" } | Simple structure for MVP |
| Backlinks index | Map from target → array of source IDs | Built during node creation for efficiency |
| :LifeModeRefs command | Shows outbound + backlinks | Simplified cursor-to-node mapping for MVP |
| All T06 requirements | All implemented + 18 tests + manual test + command | No deviation |

### T07a
| Planned | Actual | Deviation Reason |
|---------|--------|------------------|
| Extract target at cursor | Implemented with bounds checking | Detects both wikilinks and Bible refs |
| Find references | Pattern-based search through buffer | Multiple refs per line supported with while loop |
| Quickfix population | Two-call API (items + title) | vim.fn.setqflist doesn't support both in one call |
| gr keymap | Added to view buffers in create_buffer() | Buffer-local keymap survives window switches |
| All T07a requirements | All implemented + 18 tests + manual test | No deviation |
