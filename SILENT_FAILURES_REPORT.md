# Silent Failure Hunt Report: T00 Implementation

**Date:** 2026-01-16
**Component:** lifemode.nvim T00 (Repo skeleton + plugin bootstrap)
**Confidence Score:** 85/100

## Executive Summary

Found **6 critical silent failures** and **2 high-priority issues** in the T00 implementation. The code passes current tests but silently accepts invalid configuration values that will cause runtime failures in later components.

---

## Critical Silent Failures (Must Fix)

### 1. Type Validation Missing for vault_root [CRITICAL - 95]
**File:** `lua/lifemode/init.lua:21`
**Issue:** Only checks for `nil` or empty string, not type validity
**Silent Failure:** Accepts number, table, boolean, function as vault_root

**Evidence:**
```lua
lifemode.setup({ vault_root = 0 })
lifemode.setup({ vault_root = { '/tmp/test' } })
```
Both succeed silently. Later file operations will crash.

**Impact:** Runtime errors when file operations attempt to use non-string vault_root
**Fix:** Add `type(opts.vault_root) ~= 'string'` check

---

### 2. Whitespace-Only vault_root Accepted [CRITICAL - 90]
**File:** `lua/lifemode/init.lua:21`
**Issue:** Checks `== ''` but not trimmed string
**Silent Failure:** `vault_root = '   '` passes validation

**Evidence:**
```lua
lifemode.setup({ vault_root = '   ' })
```
Config set to `vault_root = "   "`, will fail on actual vault access.

**Impact:** File operations will fail when attempting to access "   " as directory
**Fix:** Use `vim.trim()` or regex to validate non-whitespace content

---

### 3. Type Validation Missing for All Optional Configs [CRITICAL - 85]
**File:** `lua/lifemode/init.lua:18-34`
**Issue:** No type checking on any optional config values
**Silent Failure:** Accepts wrong types for max_depth, bible_version, etc.

**Evidence:**
```lua
lifemode.setup({
  vault_root = '/tmp/test',
  max_depth = 'not a number',
  bible_version = 42,
  auto_index_on_startup = 'yes'
})
```
All succeed silently. Runtime behavior unpredictable.

**Impact:** Type errors when using config values in later components
**Fix:** Validate types for all config fields after merge

---

### 4. Negative/Zero max_depth Accepted [HIGH - 80]
**File:** `lua/lifemode/init.lua:5`
**Issue:** No range validation on numeric configs
**Silent Failure:** `max_depth = -5` or `max_depth = 0` accepted

**Evidence:**
```lua
lifemode.setup({ vault_root = '/tmp/test', max_depth = -5 })
lifemode.setup({ vault_root = '/tmp/test', max_depth = 0 })
```
Both succeed. Will cause infinite loops or no recursion in traversal.

**Impact:** Broken recursion logic in file traversal (future components)
**Fix:** Validate `max_depth > 0` after merge

---

### 5. Duplicate setup() Calls Register Commands Twice [HIGH - 75]
**File:** `lua/lifemode/init.lua:27-33`
**Issue:** nvim_create_user_command allows re-registration without error
**Silent Failure:** Calling setup() twice creates duplicate command handlers

**Evidence:**
```lua
lifemode.setup({ vault_root = '/tmp/test1' })
lifemode.setup({ vault_root = '/tmp/test2' })
```
No error, but commands re-registered. Possible memory leak.

**Impact:** Memory leak from duplicate handlers, unexpected behavior
**Fix:** Check if commands already exist before registration, or use `force = true` option

---

### 6. Buffer Creation Failure Not Checked [MEDIUM - 70]
**File:** `lua/lifemode/init.lua:68-81`
**Issue:** No error handling for nvim API calls that can fail
**Silent Failure:** If nvim_buf_set_option fails, function continues silently

**Evidence:**
```lua
vim.api.nvim_buf_set_option(999999, 'buftype', 'nofile')
```
Throws error: "Invalid buffer id: 999999"

**Current Code:**
```lua
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
```
No pcall wrapper. If any API call fails, error bubbles up unhandled.

**Impact:** User gets raw Vim error instead of friendly message
**Fix:** Wrap buffer creation in pcall, notify user on failure

---

## Edge Cases Verified Good

### 1. Commands Before setup() [GOOD]
**File:** `lua/lifemode/init.lua:44-48, 62-66`
Commands check `state.config` and show error message if not configured.

**Evidence:**
```
hello() without setup: ok=true
LifeMode not configured. Run require("lifemode").setup()
```
Graceful degradation working correctly.

---

### 2. Buffer API Success Cases [GOOD]
**File:** `lua/lifemode/init.lua:68-81`
Normal buffer creation works without issues.

**Evidence:**
```
nvim_create_buf result: ok=true, bufnr=2
open_view() result: ok=true
Current buffer type: nofile
```

---

## Test Coverage Gaps

### Current Tests
- `test_manual.lua`: Config validation (nil, empty string, defaults, overrides)
- `test_commands.lua`: Command existence and basic functionality
- `test_acceptance.lua`: Acceptance criteria from spec

### Missing Coverage
1. Type validation for all config fields
2. Whitespace-only string validation
3. Negative/zero numeric config validation
4. Duplicate setup() call behavior
5. Buffer creation error handling
6. Command registration error handling
7. Edge case: config with extra unknown fields
8. Edge case: config values with special characters in strings

---

## Test Files Created for Investigation

- `test_silent_failures.lua`: Config type and edge case validation
- `test_buffer_failures.lua`: Buffer API error scenarios
- `test_command_edge_cases.lua`: Command registration edge cases

These files are **not** in the test suite but provide evidence for this report.

---

## Confidence Score Breakdown

**85/100 Total Confidence**

- **Code Review Coverage:** 95/100 (reviewed all code paths)
- **Test Execution:** 90/100 (ran comprehensive edge case tests)
- **Edge Case Coverage:** 80/100 (likely missed some obscure cases)
- **Impact Assessment:** 85/100 (high confidence in severity ratings)

**Reduced confidence due to:**
- Not exhaustively testing all Neovim API failure modes
- Possible edge cases in vim.tbl_deep_extend behavior
- Unknown interactions with other plugins (not tested)

---

## Recommendations

### Immediate (Before T01)
1. Add type validation for vault_root (string check)
2. Add whitespace validation for vault_root
3. Add type validation for all optional configs
4. Add range validation for numeric configs

### High Priority (Before T03)
5. Add pcall wrappers for buffer API calls
6. Prevent duplicate command registration

### Medium Priority (Before Release)
7. Comprehensive error handling strategy
8. User-friendly error messages for all failure modes
9. Add regression tests for all silent failures found

---

## Verification Commands Used

```bash
make test
nvim --headless --noplugin -u NONE -l test_silent_failures.lua
nvim --headless --noplugin -u NONE -l test_buffer_failures.lua
nvim --headless --noplugin -u NONE -l test_command_edge_cases.lua
```

All tests executed successfully with fresh evidence captured.

---

## Summary

The T00 implementation is **functionally complete** but **lacks defensive validation**. Current tests pass because they only check happy paths. Real-world usage will expose these silent failures when users provide invalid configurations.

**Status:** INCOMPLETE - Silent failures discovered, validation layer needed before proceeding to T01.
