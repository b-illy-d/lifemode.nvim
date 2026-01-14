# Silent Failure Audit: T00 Implementation

**Date:** 2026-01-14
**Scope:** T00 repo skeleton + plugin bootstrap
**Files Audited:**
- lua/lifemode/init.lua
- tests/run_tests.lua
- tests/lifemode/init_spec.lua

## Executive Summary

Found **5 CRITICAL** and **2 HIGH** severity silent failures through systematic edge case testing.

**Impact:** These issues would pass all existing tests but fail silently in production when users provide incorrect config types or edge case values.

---

## Critical Issues (Must Fix)

### 1. Type Validation Missing for Optional Config

**Severity:** CRITICAL
**File:** lua/lifemode/init.lua:23-26
**Test Evidence:** tests/edge_cases_spec.lua:116-154 (3 failures)

**Problem:**
```lua
-- Current code accepts ANY type for leader, max_depth, bible_version
config = vim.tbl_extend('force', defaults, user_config)
-- No validation after merge
```

**Silent Failure Scenarios:**
```lua
-- User provides wrong types - silently accepted
lifemode.setup({
  vault_root = '/test',
  leader = 123,           -- should be string, stored as number
  max_depth = '5',        -- should be number, stored as string
  bible_version = false   -- should be string, stored as boolean
})

-- Later code may crash when trying to:
-- - Use leader in keymaps (expects string)
-- - Compare max_depth (expects number)
-- - Concatenate bible_version (expects string)
```

**Test Results:**
```
[9] accepts wrong type for leader - FAIL
    leader not validated: stored as number
[10] accepts wrong type for max_depth - FAIL
    max_depth not validated: stored as string
[11] accepts wrong type for bible_version - FAIL
    bible_version not validated: stored as number
```

**Fix:**
```lua
function M.setup(user_config)
  user_config = user_config or {}

  -- Validate required config
  if not user_config.vault_root then
    error('vault_root is required')
  end
  if type(user_config.vault_root) ~= 'string' then
    error('vault_root must be a string')
  end
  if user_config.vault_root:match('^%s*$') then
    error('vault_root cannot be empty or whitespace')
  end

  -- Merge with defaults
  config = vim.tbl_extend('force', defaults, user_config)

  -- Validate optional config types AFTER merge
  if type(config.leader) ~= 'string' then
    error('leader must be a string')
  end
  if type(config.max_depth) ~= 'number' then
    error('max_depth must be a number')
  end
  if type(config.bible_version) ~= 'string' then
    error('bible_version must be a string')
  end

  -- Rest of setup...
end
```

---

### 2. Empty String Validation Missing

**Severity:** CRITICAL
**File:** lua/lifemode/init.lua:15-21
**Test Evidence:** tests/edge_cases_spec.lua:64-75 (2 failures)

**Problem:**
```lua
-- Current code only checks for nil, not empty strings
if not user_config.vault_root then
  error('vault_root is required')
end
-- Empty string passes: "" or "   " are truthy in Lua
```

**Silent Failure Scenarios:**
```lua
-- Both of these silently succeed
lifemode.setup({ vault_root = '' })
lifemode.setup({ vault_root = '   ' })

-- Later file operations will fail with cryptic errors:
-- E: cannot read file ""
-- E: path not found "   "
```

**Test Results:**
```
[1] rejects empty string for vault_root - FAIL
    Expected error but function succeeded
[2] rejects whitespace-only vault_root - FAIL
    Expected error but function succeeded
```

**Fix:** (included in fix #1 above)
```lua
if user_config.vault_root:match('^%s*$') then
  error('vault_root cannot be empty or whitespace')
end
```

---

## High Severity Issues (Should Fix)

### 3. No Boundary Validation for max_depth

**Severity:** HIGH
**File:** lua/lifemode/init.lua (config validation)
**Test Evidence:** tests/edge_cases_spec.lua:210-226 (passes but risky)

**Problem:**
```lua
-- Accepts any number, including negative and zero
max_depth = 0   -- Would never recurse
max_depth = -1  -- Would cause infinite loop or crash
max_depth = 999999  -- Would cause stack overflow
```

**Risk:**
- max_depth = 0: No directory traversal would occur
- max_depth < 0: Undefined behavior, likely infinite loop
- max_depth > 1000: Stack overflow or performance death

**Fix:**
```lua
if type(config.max_depth) ~= 'number' or config.max_depth < 1 or config.max_depth > 100 then
  error('max_depth must be a number between 1 and 100')
end
```

---

### 4. Config Merging Resets Previous Values

**Severity:** HIGH
**File:** lua/lifemode/init.lua:26
**Test Evidence:** tests/runtime_edge_cases_spec.lua:134-150

**Problem:**
```lua
-- Multiple setup() calls don't accumulate, they RESET
lifemode.setup({ vault_root = '/first', leader = '<leader>x' })
lifemode.setup({ vault_root = '/second' })  -- leader resets to '<Space>'
```

**Expected Behavior (Ambiguous):**
- Option A: Second setup() completely replaces config (current behavior)
- Option B: Second setup() only updates specified keys

**Current behavior is RESET, which may surprise users.**

**Decision Needed:**
Is this the intended behavior? If so, document it clearly in setup() docstring.

**Recommended Fix:**
Document the behavior explicitly:
```lua
--- Setup LifeMode plugin
--- Multiple calls to setup() will REPLACE the entire configuration,
--- not merge with previous calls. To update config, provide all values.
function M.setup(user_config)
```

---

## Medium Severity Issues (Consider Fixing)

### 5. Path Validation Deferred (Not Validated at Setup)

**Severity:** MEDIUM
**File:** lua/lifemode/init.lua
**Test Evidence:** tests/runtime_edge_cases_spec.lua:60-78

**Current Behavior:**
```lua
-- These all silently succeed
lifemode.setup({ vault_root = '/nonexistent/path' })
lifemode.setup({ vault_root = './relative/path' })
lifemode.setup({ vault_root = '~/vault' })  -- Not expanded
```

**Risk:**
- User typos path, doesn't discover until first file operation
- Relative paths may resolve incorrectly depending on cwd
- Home directory expansion (~) is not performed

**Tradeoffs:**
- PRO (current): Lazy validation allows setup before vault exists
- CON: Error appears later, harder to debug

**Recommendation:**
Document that path validation is lazy:
```lua
--- @param user_config table Configuration options
---   vault_root (string, required): Path to vault directory
---     Note: Path existence is not validated at setup time
```

---

### 6. No Path Normalization

**Severity:** MEDIUM
**File:** lua/lifemode/init.lua
**Test Evidence:** tests/runtime_edge_cases_spec.lua:80-107

**Current Behavior:**
```lua
-- Paths stored exactly as provided
vault_root = '/path/to/vault/'    -- trailing slash preserved
vault_root = '/path//with///slashes'  -- multiple slashes preserved
vault_root = '~/vault'  -- tilde not expanded
```

**Risk:**
- Inconsistent path comparisons (with vs without trailing slash)
- Multiple slashes may confuse some file APIs
- Tilde expansion must be done manually later

**Recommendation:**
Add path normalization helper:
```lua
local function normalize_path(path)
  -- Expand home directory
  path = vim.fn.expand(path)
  -- Remove trailing slash (unless root /)
  path = path:gsub('(.-)/$', '%1')
  return path
end

function M.setup(user_config)
  -- ...
  config.vault_root = normalize_path(user_config.vault_root)
  -- ...
end
```

---

### 7. Command Output May Display Wrong Types

**Severity:** MEDIUM
**File:** lua/lifemode/init.lua:29-38
**Test Evidence:** tests/runtime_edge_cases_spec.lua:205-228

**Current Behavior:**
```lua
-- If user provides wrong types, command displays them as-is:
LifeMode Configuration:
  vault_root: /test
  leader: 123              -- should be string
  max_depth: not a number  -- should be number
  bible_version: ESV
```

**Risk:**
- Confusing output for users
- Doesn't fail, so user may not notice the error
- Later operations will fail with cryptic messages

**Fix:**
Covered by fixing issue #1 (type validation).

---

## Low Severity Issues (Nice to Have)

### 8. No Validation for Bible Version Values

**Severity:** LOW
**Current:** Accepts any string for bible_version

**Problem:**
```lua
lifemode.setup({ vault_root = '/test', bible_version = 'INVALID' })
-- Later API calls to bible service will fail
```

**Recommendation:**
Validate against known bible versions:
```lua
local valid_bible_versions = { 'ESV', 'NIV', 'NKJV', 'KJV', 'NASB' }

if not vim.tbl_contains(valid_bible_versions, config.bible_version) then
  error('bible_version must be one of: ' .. table.concat(valid_bible_versions, ', '))
end
```

Or document that validation is lazy (preferred for MVP).

---

## Test Coverage Gaps

The following edge cases are **NOT** covered by existing tests:

### Not Tested: Error Messages Are User-Friendly
```lua
-- Current: error('vault_root is required')
-- Better: error('[LifeMode] Configuration error: vault_root is required. Please provide a path to your vault directory.')
```

### Not Tested: Config Persists Across Reloads
If user does `:luafile %` to reload plugin, is config preserved or lost?

### Not Tested: Setup() Called in Different Neovim States
- Called before VimEnter
- Called after plugin already used
- Called in headless mode

### Not Tested: Concurrent Setup() Calls
If user has multiple init.lua files that all call setup(), what happens?

---

## Verification Evidence

### Test Execution Results

**Edge Cases Test:**
```bash
$ nvim -l tests/edge_cases_spec.lua
Tests: 21 | Pass: 16 | Fail: 5
==================================================
FAILURES:
[1] rejects empty string for vault_root
[2] rejects whitespace-only vault_root
[9] accepts wrong type for leader
[10] accepts wrong type for max_depth
[11] accepts wrong type for bible_version
```

**Runtime Edge Cases Test:**
```bash
$ nvim -l tests/runtime_edge_cases_spec.lua
Tests: 15 | Pass: 15 | Fail: 0
==================================================
(All runtime tests pass, but exposed risky behaviors)
```

**Original Tests Still Pass:**
```bash
$ nvim -l tests/run_tests.lua
Tests: 7 | Pass: 7 | Fail: 0
==================================================
```

---

## Recommendations

### Immediate Actions (Before T01)

1. **Fix type validation (Issue #1)** - Add validation for leader, max_depth, bible_version types
2. **Fix empty string validation (Issue #2)** - Reject empty/whitespace vault_root
3. **Add boundary validation for max_depth (Issue #3)** - Enforce reasonable limits (1-100)

### Before Production

4. **Document config behavior (Issue #4)** - Clarify that setup() replaces config
5. **Add path normalization (Issue #6)** - Expand ~, remove trailing slashes, handle multiple slashes
6. **Add bible version validation (Issue #8)** - Or document that it's lazy

### Future Improvements

7. **Improve error messages** - Add [LifeMode] prefix and helpful context
8. **Test edge cases in CI** - Add edge_cases_spec.lua to test suite
9. **Add config schema validation** - Consider using a schema validator library

---

## Files Created for This Audit

1. **tests/edge_cases_spec.lua** - 21 edge case tests (5 failures = 5 bugs found)
2. **tests/runtime_edge_cases_spec.lua** - 15 runtime tests (all pass but expose risks)
3. **SILENT_FAILURE_AUDIT.md** - This report

---

## Summary Table

| Issue | Severity | Impact | Fix Priority | Validated By |
|-------|----------|--------|--------------|--------------|
| Type validation missing | CRITICAL | Wrong types crash later | IMMEDIATE | edge_cases_spec.lua:116-154 |
| Empty string accepted | CRITICAL | File ops fail cryptically | IMMEDIATE | edge_cases_spec.lua:64-75 |
| No max_depth bounds | HIGH | Stack overflow / no-op | HIGH | edge_cases_spec.lua:210-226 |
| Config merge resets values | HIGH | Surprising behavior | DOCUMENT | runtime_edge_cases_spec.lua:134-150 |
| No path validation | MEDIUM | Late error discovery | DOCUMENT | runtime_edge_cases_spec.lua:60-78 |
| No path normalization | MEDIUM | Inconsistent comparisons | MEDIUM | runtime_edge_cases_spec.lua:80-107 |
| Wrong types in output | MEDIUM | Confusing UX | FIXED by #1 | runtime_edge_cases_spec.lua:205-228 |
| No bible version validation | LOW | API errors later | FUTURE | (not tested yet) |

---

## Conclusion

T00 implementation is **functionally correct** for the happy path (all original tests pass), but has **5 critical edge cases** that would fail silently in production.

The good news: All issues are fixable with straightforward validation additions. The bad news: These bugs would have shipped undetected without systematic edge case hunting.

**Next Step:** Apply fixes for issues #1, #2, #3 before proceeding to T01.
