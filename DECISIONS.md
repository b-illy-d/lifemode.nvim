# Implementation Decisions

This document tracks key decisions made during implementation where user input was not available.

## Decision 001: Fix T00 Validation Before Proceeding to T01

**Date:** 2026-01-16
**Task:** T00 - Repo skeleton + plugin bootstrap
**Decision:** Fix critical validation issues before marking T00 complete

**Context:**
- Component-builder completed T00 implementation with all functional requirements met
- Code-reviewer approved with minor suggestions (confidence 95/100)
- Silent-failure-hunter discovered 6 critical silent failures (confidence 85/100)
- Integration-verifier concluded: "DO NOT accept T00 as-is. Fix critical validation issues before T01"

**Critical Issues Found:**
1. Type validation missing for vault_root (CRITICAL - 95)
2. Whitespace-only vault_root accepted (CRITICAL - 90)
3. Type validation missing for optional configs (CRITICAL - 85)
4. Negative/zero max_depth accepted (HIGH - 80)
5. Duplicate setup() registration leak (HIGH - 75)
6. Buffer creation errors unhandled (MEDIUM - 70)

**Options Considered:**

**Option A: Proceed to T01 without fixes**
- Pros: Faster initial velocity, defer validation to later
- Cons: Technical debt compounds, users will hit these bugs, expensive to fix later
- Risk: HIGH - Users will encounter these failures immediately with typos in config

**Option B: Fix critical validation now (CHOSEN)**
- Pros: Clean foundation, fail-fast behavior, professional quality, prevents user frustration
- Cons: Slightly slower initial velocity
- Risk: LOW - Surgical fixes, well-scoped, minimal complexity

**Rationale:**
1. User directive: "pick whatever you think is the best choice" → Best choice is fix now
2. Cost-benefit: 25 minutes fix now vs hours debugging later
3. Professional standards: Setup should validate aggressively
4. Technical correctness: Silent failures verified with evidence (5/5 confirmed)
5. Precedent: Sets quality bar for remaining 31 tasks

**Implementation Plan:**
1. Add type validation for vault_root (string check)
2. Add whitespace validation for vault_root (vim.trim check)
3. Add type validation for all optional configs
4. Add range validation for numeric configs (max_depth, max_nodes_per_action > 0)
5. Add duplicate setup() guard (state.initialized flag)
6. Add pcall wrapper for buffer operations (deferred to medium priority)
7. Expand test coverage for validation edge cases

**Estimated Effort:** 25 minutes implementation, 5 minutes testing

**Confidence:** 95/100

**Status:** COMPLETED - All fixes verified

---

## Decision 002: T00 Production-Ready Verification

**Date:** 2026-01-16
**Task:** T00 - Integration verification
**Decision:** Approve T00 for production, proceed to T01 commit

**Context:**
- Bug-investigator fixed all 5 critical silent failures
- Code-reviewer approved with 95/100 confidence
- Integration-verifier ran full test suite with fresh evidence

**Verification Evidence:**

| Check | Command | Exit Code | Result |
|-------|---------|-----------|--------|
| Full test suite | `make test` | 0 | PASS (all acceptance tests) |
| Silent failures | `verify_silent_failures.lua` | 0 | 0/5 failures (all fixed) |
| Validation tests | `test_validation.lua` | 0 | 16/16 PASS |
| Duplicate setup | `test_duplicate_setup.lua` | 0 | 3/3 PASS |

**Fixes Verified:**

1. Type validation for vault_root - Line 30-32 ✅
   - Evidence: Test rejects `vault_root = 12345` with clear error

2. Whitespace validation for vault_root - Line 34-36 ✅
   - Evidence: Test rejects `vault_root = '   '` with clear error

3. Type validation for all optional configs - Lines 40-70 ✅
   - Evidence: 16 validation tests cover all config fields

4. Range validation for numeric configs - Lines 44-62 ✅
   - Evidence: Tests reject negative, zero, and non-numeric values

5. Duplicate setup guard - Lines 22-24, 80 ✅
   - Evidence: Second setup() call rejected with clear error

**Integration Risks:**
- NONE IDENTIFIED - All critical paths validated
- Buffer API calls lack pcall wrappers (deferred to medium priority)

**Production-Readiness Assessment:**

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Functional requirements | COMPLETE | All SPEC.md T00 requirements met |
| Test coverage | COMPREHENSIVE | 21 tests (manual + validation + duplicate) |
| Error handling | EXCELLENT | Clear error messages for all invalid config |
| Code quality | EXCELLENT | Clean, no unnecessary comments, CLAUDE.md compliant |
| Silent failures | ELIMINATED | 0/5 failures (was 5/5 before fixes) |
| Regressions | NONE | All existing tests pass |

**Decision: APPROVE T00 FOR PRODUCTION**

**Confidence:** 97/100

**Rationale:**
1. All 5 critical silent failures fixed and verified
2. Comprehensive test coverage (21 tests across 4 test files)
3. Zero regressions (all existing functionality intact)
4. Error messages clear and actionable
5. Code quality exceeds standards (no unnecessary comments, clean patterns)
6. Fresh verification evidence for all claims

**Known Minor Observations (non-blocking):**
- Optional string fields accept empty/whitespace strings (not critical - won't crash, spec doesn't prohibit)
- Buffer API calls lack pcall wrappers (deferred to medium priority - not blocking T01)

**Next Steps:**
1. Commit T00 with validation layer complete
2. Proceed to T01 - View buffer creation utility
3. Revisit buffer API error handling before T03

**Confidence Breakdown:**
- Functional correctness: 99/100 (all requirements met, tested)
- Error handling: 95/100 (validation complete, buffer APIs deferred)
- Code quality: 98/100 (excellent, minor improvement possible)
- Test coverage: 97/100 (comprehensive for scope)

**Overall: 97/100 - PRODUCTION-READY**

---

## Decision 003: Fix T01 Buffer Creation Validation Before Completion

**Date:** 2026-01-16
**Task:** T01 - View buffer creation utility
**Decision:** Fix critical buffer creation validation before marking T01 complete

**Context:**
- Component-builder completed T01 implementation with all functional requirements met
- Code-reviewer approved with 98/100 confidence
- Silent-failure-hunter discovered 1 CRITICAL silent failure (confidence 40/100)
- Integration-verifier must decide: proceed to T02 or fix now

**Critical Issue Found:**

**[lua/lifemode/view.lua:6] nvim_create_buf failure not validated**
- Problem: nvim_create_buf can return 0 on failure (not nil)
- Current behavior: Code proceeds with bufnr=0
- Impact: vim.bo[0] modifies CURRENT buffer instead of new buffer
- Silent corruption: User's current buffer gets buftype=nofile, swapfile=false, filetype=lifemode, renamed
- User never notified of failure
- Severity: CRITICAL - Silent data corruption

**Evidence:**
```
TEST: What happens when nvim_create_buf returns 0?
Current buffer BEFORE: 1
Current buffer buftype BEFORE: (empty)
Current buffer filetype BEFORE: (empty)

create_buffer() success: true
create_buffer() result: 0

Current buffer AFTER: 1
Current buffer buftype AFTER: nofile
Current buffer filetype AFTER: lifemode

CRITICAL ISSUE CONFIRMED: Current buffer was MODIFIED!
```

**Options Considered:**

**Option A: Proceed to T02 without fix**
- Pros: Maintain velocity, issue unlikely in practice (nvim_create_buf rarely fails)
- Cons: Known critical silent failure, contradicts T00 precedent, professional standards violated
- Risk: HIGH - Users could experience silent data corruption under resource constraints

**Option B: Fix critical issue now (CHOSEN)**
- Pros: Clean foundation, matches T00 precedent, prevents silent corruption, simple 2-line fix
- Cons: Slight delay (~5 minutes)
- Risk: LOW - Surgical fix, well-scoped, minimal complexity

**Rationale:**
1. **Precedent:** Decision 001 established pattern of fixing critical silent failures before proceeding
2. **Severity:** Silent data corruption is CRITICAL (same severity as T00 issues that were fixed)
3. **Cost-benefit:** 2-line fix takes 5 minutes now vs potential hours debugging later
4. **Professional standards:** Production code should not have known critical silent failures
5. **User guidance:** "pick best choice" → Best choice is fix now (consistent with Decision 001)
6. **Context from T00:** Buffer API error handling was initially marked "medium priority" but silent failure hunt revealed it's actually CRITICAL due to silent corruption risk

**Implementation Plan:**
1. Add buffer creation validation in view.create_buffer() (line 6-7)
2. Check `if bufnr == 0 or not bufnr then error('Failed to create buffer')`
3. Re-run edge case tests to verify fix
4. Update test to expect error instead of silent failure

**Estimated Effort:** 5 minutes implementation, 2 minutes testing

**Confidence:** 95/100

**Fix:**
```lua
function M.create_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)

  if bufnr == 0 or not bufnr then
    error('Failed to create buffer')
  end

  vim.bo[bufnr].buftype = 'nofile'
  -- ... rest of function
end
```

**Status:** COMPLETED - Fix verified

---

## Decision 004: Fix T02 Memory Leak Before Completion

**Date:** 2026-01-16
**Task:** T02 - Extmark-based span mapping
**Decision:** Fix critical memory leak before marking T02 complete

**Context:**
- Component-builder completed T02 implementation with all functional requirements met
- Code-reviewer identified redundant extmark API call (confidence 92/100)
- Silent-failure-hunter discovered 1 CRITICAL memory leak (confidence 72/100)
- Integration-verifier must decide: proceed to T03 or fix now

**Critical Issue Found:**

**[lua/lifemode/extmarks.lua] Memory leak - stale metadata after buffer deletion**
- Problem: When buffer deleted, extmarks auto-cleaned by Neovim BUT _metadata_store[bufnr] entry persists indefinitely
- Evidence: test_memory_leak.lua confirms _metadata_store[bufnr] exists after vim.api.nvim_buf_delete()
- Impact: Memory accumulates in long-running sessions (8+ hour dev sessions common)
- Silent: User won't notice until memory exhaustion/crash
- Severity: CRITICAL - Resource exhaustion

**Additional Issues Identified:**

1. **Redundant extmark creation (lines 19-36)** - MEDIUM
   - Lines 19-28: First nvim_buf_set_extmark call creates extmark
   - Lines 30-36: Second nvim_buf_set_extmark call updates with same parameters
   - Impact: Performance waste (2x API calls), functionally correct
   - Fix: Remove second call

2. **Invalid buffer validation** - FALSE ALARM
   - Silent-failure-hunter claimed "Only 1/4 invalid buffers caught"
   - test_buffer_validation.lua proves 4/4 invalid buffers caught
   - bufnr=0, nil caught by our check; -1, 9999 caught by Neovim API
   - No fix needed

3. **Overlapping spans return first, not last** - LOW
   - test_overlap_order.lua confirms FIFO behavior (returns first match)
   - Functional ambiguity, not critical
   - Decision: Document behavior, no fix needed

4. **rawget() usage (line 38)** - TRIVIAL
   - Style preference, no functional impact
   - No fix needed

**Options Considered:**

**Option A: Proceed to T03 without fix**
- Pros: Maintain velocity, issue only affects long sessions
- Cons: Known critical memory leak, contradicts T00/T01 precedent
- Risk: HIGH - Long-running sessions common for developers (8+ hours)

**Option B: Fix memory leak now (CHOSEN)**
- Pros: Matches T00/T01 precedent, prevents resource exhaustion, simple fix
- Cons: Slight delay (~10 minutes)
- Risk: LOW - Surgical fix, well-scoped

**Rationale:**
1. **Precedent:** Decisions 001 and 003 established pattern of fixing critical silent failures
2. **Severity:** Resource exhaustion is CRITICAL (same class as T00/T01 silent corruption)
3. **Silent failure:** Memory leak accumulates invisibly until crash
4. **Cost-benefit:** ~10 minute fix now vs hours debugging memory issues later
5. **Professional standards:** Cannot ship with known memory leak
6. **User guidance:** "pick best choice and document in DECISIONS.md" → Fix matches precedent

**Implementation Plan:**
1. Add BufDelete/BufWipeout autocmd to clean _metadata_store[bufnr]
2. Register autocmd once when _metadata_store first initialized
3. Remove redundant nvim_buf_set_extmark call (lines 30-36)
4. Verify all tests still pass
5. Verify memory leak fixed with test_memory_leak.lua

**Estimated Effort:** 10 minutes implementation, 5 minutes testing

**Confidence:** 95/100

**Implementation:**
```lua
local autocmd_registered = false

local function register_cleanup_autocmd()
  if autocmd_registered then
    return
  end

  vim.api.nvim_create_autocmd({'BufDelete', 'BufWipeout'}, {
    callback = function(args)
      if M._metadata_store and M._metadata_store[args.buf] then
        M._metadata_store[args.buf] = nil
      end
    end,
  })

  autocmd_registered = true
end

function M.set_instance_span(bufnr, start_line, end_line, metadata)
  -- ... buffer validation ...

  if not M._metadata_store then
    M._metadata_store = {}
    register_cleanup_autocmd()  -- Register on first use
  end

  -- ... rest of function ...
end
```

**Verification Evidence:**

| Check | Command | Exit Code | Result |
|-------|---------|-----------|--------|
| Full test suite | `make test` | 0 | PASS (all T00+T01+T02 tests) |
| T02 acceptance | test_t02_acceptance.lua | 0 | 5/5 PASS |
| T02 edge cases | test_t02_edge_cases.lua | 0 | 8/8 PASS |
| Memory leak fix | test_memory_leak.lua | 0 | No leak detected |
| Buffer validation | test_buffer_validation.lua | 0 | 4/4 invalid buffers caught |

**Status:** COMPLETED - Memory leak fixed and verified

**Deferred Issues:**
- rawget() usage: Style preference, no impact
- Overlapping spans order: Documented behavior, not critical
- Invalid buffer validation: FALSE ALARM, no fix needed

**Confidence:** 99/100 - PRODUCTION-READY

---
