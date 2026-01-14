# Progress Tracking

## Current Workflow
T00 COMPLETE - Awaiting hotfix decision

## Completed
- [x] Memory files initialized
- [x] T00 - Repo skeleton + plugin bootstrap - commit 0dd2003
  - Status: CONDITIONAL PASS (needs hotfix for 3 critical bugs)
  - Code Review: Grade A- (approved)
  - Tests: 7/7 happy path, 16/21 edge cases (5 failures expected)
  - Silent Failures: 5 found (3 blocking for T01)

## In Progress
- [ ] T00 Hotfix decision - awaiting user choice:
  - Option A: Fix now (5 lines, 5 min) - RECOMMENDED
  - Option B: Proceed with documented risk
  - Option C: Fix as part of T01

## Blocked
- [ ] T01: View buffer creation utility - BLOCKED on T00 hotfix decision

## Remaining
- [ ] T01: View buffer creation utility
- [ ] T02: Extmark-based span mapping
- [ ] T03: Minimal Markdown block parser
- [ ] T04: Ensure IDs for indexable blocks
- [ ] T05: Build in-memory Node model
- [ ] T06: Basic wikilink extraction
- [ ] T07: Bible reference extraction and parsing
- [ ] T07a: Quickfix "references" view
- [ ] T08: "Definition" jump for wikilinks and Bible refs
- [ ] T09-T30: (remaining per SPEC.md)

## Verification Evidence
| Check | Command | Exit Code | Result |
|-------|---------|-----------|--------|
| Happy Path Tests | `nvim -l tests/run_tests.lua` | 0 | **PASS (7/7)** |
| Edge Case Tests | `nvim -l tests/edge_cases_spec.lua` | 1 | FAIL (16/21, 5 bugs found) |
| Runtime Tests | `nvim -l tests/runtime_edge_cases_spec.lua` | 0 | **PASS (15/15)** |
| Git Commit | `git log --oneline -1` | 0 | 0dd2003 (feat: T00) |
| Git Status | `git status` | 0 | Clean (audit files untracked) |

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
| Planned | Actual | Deviation Reason |
|---------|--------|------------------|
| plenary.nvim for tests | Custom minimal test runner | plenary not available, needed working tests |
| All T00 requirements | All implemented + tests | No deviation |
