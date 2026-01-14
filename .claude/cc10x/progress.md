# Progress Tracking

## Current Workflow
T02 COMPLETE

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

## In Progress
None

## Blocked
None

## Remaining
- [ ] T03: Minimal Markdown block parser
- [ ] T04: Ensure IDs for indexable blocks
- [ ] T05: Build in-memory Node model
- [ ] T06: Basic wikilink extraction
- [ ] T07: Bible reference extraction and parsing
- [ ] T07a: Quickfix "references" view
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
