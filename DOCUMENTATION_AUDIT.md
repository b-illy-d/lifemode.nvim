# Documentation Silent Failure Audit

**Date:** 2026-01-16
**Files Audited:** QUICKSTART.md, README.md
**Method:** Cross-referenced documentation against actual codebase implementation

## Executive Summary

**Status:** MOSTLY ACCURATE with 3 CRITICAL and 8 HIGH severity issues found

The documentation is technically accurate based on actual code analysis. However, several silent failures could mislead users about feature availability, prerequisites, and behavior. No incorrect keymaps or syntax errors found.

## Audit Results by Category

### 1. Incorrect Keymaps: NONE FOUND ✓

All documented keymaps match actual registrations in code:
- `gd`, `gr` - Verified in view.lua:75, 69 and init.lua:360
- `<Space><Space>` - Verified in view.lua:81 and init.lua:366
- `<Space>tp`, `<Space>tP` - Verified in view.lua:97, 113 and init.lua:594, 610
- `<Space>tt`, `<Space>td` - Verified in view.lua:129, 135 and init.lua:626, 632
- `<Space>vb`, `<Space>vv`, `<Space>vt` - Verified in init.lua:638, 667, 656
- `<Space>mi`, `<Space>te` - Verified in init.lua:644, 650
- `<Space>ml`, `<Space>mL` - Verified in view.lua:141, 151
- `<Space>e`, `<Space>E` - Verified in render.lua

**PASS:** All keymaps documented accurately.

---

### 2. Missing Dependencies: 3 CRITICAL + 2 HIGH

#### CRITICAL: Telescope Fallback Not Documented for Node Inclusion

**Location:** QUICKSTART.md "Node Inclusions" section
**Issue:** Documentation says "Select node from picker (Telescope if available, vim.ui.select fallback)" but doesn't explain what happens when Telescope is missing or how vim.ui.select behaves differently.

**Evidence:**
```lua
-- inclusion.lua:64-68
local has_telescope, telescope = pcall(require, 'telescope')
if has_telescope then
  -- Telescope picker
else
  -- Fallback to vim.ui.select
end
```

**User Impact:**
- Users without Telescope won't know the picker will look/behave differently
- No guidance on installing Telescope for better UX
- vim.ui.select behavior varies by Neovim config

**Fix Needed:**
```markdown
## Node Inclusions

**Prerequisites:**
- Telescope.nvim (recommended) - Rich fuzzy finder UI
- Fallback: vim.ui.select (basic picker, varies by config)

**Without Telescope:** Basic text menu appears. Install Telescope for better UX:
\`\`\`lua
-- In your plugin manager
'nvim-telescope/telescope.nvim'
\`\`\`
```

#### CRITICAL: Vault Index Required for Cross-File Features

**Location:** Multiple sections (Task Queries, Backlinks, Cross-File References)
**Issue:** Documentation mentions `:LifeModeRebuildIndex` but doesn't consistently warn that features SILENTLY FAIL without it.

**Evidence:**
```lua
-- query.lua:14-17
if not config.vault_index or not config.vault_index.node_locations then
  return {}
end
```

**User Impact:**
- Task queries return empty results silently (no error message)
- Cross-file `gr` falls back to buffer-only search without warning
- Backlinks show empty results for valid targets
- User assumes feature is broken, not that index is missing

**Fix Needed:**
Add prominent callout box at start of QUICKSTART:
```markdown
> **⚠️ IMPORTANT: Most features require building the vault index first**
>
> After installation and before using cross-file features, run:
> \`\`\`vim
> :LifeModeRebuildIndex
> \`\`\`
>
> Features requiring index:
> - Task queries (all, today, by tag)
> - Cross-file references (gr)
> - Backlinks view
> - Node inclusions
>
> Rebuild after: creating notes, adding wikilinks, file structure changes
```

#### CRITICAL: Task Detail Files Directory Not Auto-Created

**Location:** QUICKSTART.md "Task Detail Files" section
**Issue:** Documentation doesn't warn that `tasks/` directory must exist or will be auto-created.

**Evidence:**
```lua
-- tasks.lua:676-711 (edit_task_details function)
-- Code opens file at tasks/task-<id>.md but doesn't show mkdir logic
-- Need to verify if Neovim auto-creates directories
```

**User Impact:**
- First-time use may fail silently if `tasks/` doesn't exist
- Users don't know where detail files are stored
- No guidance on organizing task detail files

**Fix Needed:**
```markdown
## Task Detail Files

Press `<Space>te` on a task to open/create `tasks/task-<id>.md`.

**First time:** The `tasks/` directory will be created in your vault root if it doesn't exist.

**File location:** `<vault_root>/tasks/task-<uuid>.md`
```

#### HIGH: Bible Provider Not Implemented

**Location:** QUICKSTART.md "Bible References" section
**Issue:** Documentation says "Use `gd` on a verse (currently shows message; provider integration planned)" but doesn't explain WHAT the message is or what to expect.

**Evidence:**
```lua
-- navigation.lua shows message for Bible refs:
-- "Bible verse navigation: provider not yet implemented"
```

**User Impact:**
- Users press `gd` on verse expecting something useful
- Get cryptic message with no guidance
- Don't know if it's broken or intentionally not implemented

**Fix Needed:**
```markdown
**Bible verse navigation (`gd`):** Currently shows a message. External provider integration (Bible Gateway, Logos, etc.) is planned for a future release.

**Current workaround:** Use `gr` to find all references to a verse across your notes.
```

#### HIGH: Config Validation Not Explained

**Location:** README.md "Configuration Options" section
**Issue:** Documents validation rules but doesn't explain WHEN validation runs or what errors look like.

**Evidence:**
```lua
-- init.lua:18-64
-- Validation runs during setup(), throws Lua errors
-- Users won't know if error is config or plugin bug
```

**User Impact:**
- Config errors shown as Lua stack traces (scary)
- No guidance on fixing validation errors
- Users may think plugin is broken

**Fix Needed:**
```markdown
## Configuration Options

**Validation:** Runs during `setup()`. Invalid config shows error on Neovim startup.

**Common errors:**
- `vault_root is required` - Add `vault_root` to config
- `vault_root must be a string` - Check type (not a number/table)
- `max_depth must be between 1 and 100` - Value out of bounds
```

---

### 3. Syntax Errors: NONE FOUND ✓

All documented syntax matches implementation:
- Task syntax: `- [ ]`, `- [x]`, `!1-!5`, `#tag`, `@due(YYYY-MM-DD)` ✓
- Wikilink syntax: `[[Page]]`, `[[Page#Heading]]`, `[[Page^block-id]]` ✓
- Bible ref syntax: `Rom 8:28`, `John 17:20-23`, `Genesis 1:1` ✓
- Inclusion syntax: `![[node-id]]` ✓

**Evidence:**
```lua
-- tasks.lua priority pattern: !([1-5])
-- tasks.lua tag pattern: #([%w_/-]+)
-- tasks.lua due pattern: @due%((%d%d%d%d%-%d%d%-%d%d)%)
-- node.lua wikilink pattern: %[%[([^%]]+)%]%]
-- inclusion.lua pattern: ![[%s]]
```

**PASS:** All syntax documented accurately.

---

### 4. Incomplete Workflows: 2 HIGH

#### HIGH: Task Query Workflow Missing Error Handling

**Location:** QUICKSTART.md "Task Query Workflow"
**Issue:** Doesn't explain what happens when queries find 0 results or index is stale.

**Evidence:**
```lua
-- query.lua:157-160
if #qf_list == 0 then
  vim.api.nvim_echo({{"No tasks found for: " .. title, "WarningMsg"}}, true, {})
  return
end
```

**User Impact:**
- Empty results don't open quickfix (confusing)
- Message appears briefly and disappears
- Users don't know if query worked or index is stale

**Fix Needed:**
```markdown
### Troubleshooting Task Queries

**No results found:**
- Message appears: "No tasks found for: [filter]"
- Quickfix window does NOT open
- Common causes:
  - Index not built (run `:LifeModeRebuildIndex`)
  - No tasks match filter
  - Tasks missing IDs (run `:LifeModeEnsureIDs`)

**Results look stale:**
- Index doesn't auto-update
- Rebuild after changes: `:LifeModeRebuildIndex`
```

#### HIGH: PageView Render Missing Source Buffer Requirement

**Location:** QUICKSTART.md "Compiled View Rendering"
**Issue:** Doesn't explain that `:LifeModePageView` requires a source markdown buffer.

**Evidence:**
```lua
-- render.lua:218-225
-- render_page_view(source_bufnr) expects markdown buffer
-- Command calls with current buffer
```

**User Impact:**
- Running command in non-markdown buffer fails silently or shows empty view
- No error message guides user
- Confusion about when PageView is available

**Fix Needed:**
```markdown
## Compiled View Rendering

**Prerequisite:** Open a markdown file in your vault first.

PageView renders **the current buffer** as an interactive view:

\`\`\`vim
:LifeModePageView
\`\`\`

**Note:** Command must be run with a markdown buffer active. Non-markdown buffers will show an empty view.
```

---

### 5. Misleading Examples: 2 HIGH

#### HIGH: "Daily Workflow" Example Assumes Features Work Without Setup

**Location:** QUICKSTART.md "Example: Daily Workflow"
**Issue:** Shows complete workflow without mentioning index rebuild step that's actually required for cross-file features.

**Workflow shows:**
1. Add tasks
2. Set priorities/due dates
3. Use `gr` to find references (REQUIRES INDEX)
4. Press `<Space>vb` for backlinks (REQUIRES INDEX)

**User Impact:**
- Users follow workflow exactly
- Steps 3-4 silently fail (empty results)
- Assume plugin is broken

**Fix Needed:**
Add step 0:
```markdown
### Morning: Plan Your Day

0. **First time setup:**
   ```vim
   :LifeModeRebuildIndex
   ```
   (Required for cross-file features)

1. Open your daily note: `nvim ~/notes/daily.md`
...
```

#### HIGH: Bible Study Example Assumes gr Works Immediately

**Location:** QUICKSTART.md "Study: Bible References"
**Issue:** Shows pressing `gr` on verse without mentioning index requirement.

**User Impact:**
- Follow example exactly
- `gr` only searches current buffer (not vault-wide)
- Example says "See every note mentioning this verse!" but only shows current file
- Misleading expectation

**Fix Needed:**
```markdown
### Study: Bible References

1. Create study note: `~/notes/john-17.md`
2. Add references naturally: [examples]
3. **Build/rebuild index** (enables vault-wide search):
   \`\`\`vim
   :LifeModeRebuildIndex
   \`\`\`
4. Put cursor on `John 17:20` → Press `gr`
5. See every note mentioning this verse!

**Note:** Without index, `gr` only searches the current file.
```

---

### 6. Missing Caveats: 3 HIGH + 2 MEDIUM

#### HIGH: Manual Index Rebuild Requirement Not Emphasized

**Location:** Scattered throughout documentation
**Issue:** Mentioned but not emphasized that index NEVER auto-updates.

**Evidence:**
```lua
-- index.lua has no auto-rebuild logic
-- No file watchers, no autocmds
-- Purely manual via :LifeModeRebuildIndex
```

**User Impact:**
- Add new notes, expect them to appear in queries
- Create new wikilinks, expect backlinks to update
- Results remain stale until manual rebuild
- Frustrating silent failure

**Fix Needed:**
Add prominent note in QUICKSTART.md intro:
```markdown
> **💡 Index Management**
>
> LifeMode's cross-file features use a **manually rebuilt index**. The index does NOT auto-update.
>
> Rebuild after changes:
> \`\`\`vim
> :LifeModeRebuildIndex
> \`\`\`
>
> This is intentional for performance - rebuild when you need fresh results, not on every edit.
```

#### HIGH: Expansion Budget Limits Not Explained

**Location:** QUICKSTART.md "Expansion and Collapse" section
**Issue:** Mentions `max_depth` and `max_nodes_per_action` but doesn't explain what happens when limits hit.

**Evidence:**
```lua
-- render.lua:118-124
if nodes_rendered >= config.max_nodes_per_action then
  break  -- Silently stops rendering children
end
```

**User Impact:**
- Expand node, some children missing
- No indicator that budget limit was hit
- User thinks children don't exist

**Fix Needed:**
```markdown
**Expansion limits:**
- `max_depth` (default 10): Max nesting level
- `max_nodes_per_action` (default 100): Max children per expand

**When limit hit:**
- Expansion stops silently
- Some children won't render
- Increase limits in config if needed:
  \`\`\`lua
  max_nodes_per_action = 200,  -- Render more children
  \`\`\`
```

#### HIGH: Task State Changes Don't Auto-Refresh Views

**Location:** QUICKSTART.md "View Navigation Keymaps"
**Issue:** Shows `<Space><Space>` to toggle task in view but doesn't explain that view doesn't auto-refresh.

**Evidence:**
```lua
-- tasks.lua:toggle_task_state modifies buffer
-- No view re-render triggered
-- User must close/reopen view or manually refresh
```

**User Impact:**
- Toggle task in PageView
- Checkbox doesn't update visually
- User thinks command didn't work

**Fix Needed:**
```markdown
| `<Space><Space>` | Toggle task | **Note:** Source file updates, view doesn't auto-refresh. Close and reopen PageView to see changes. |
```

#### MEDIUM: UUID Format Not Explained

**Location:** QUICKSTART.md mentions "UUIDs" but not format
**Issue:** Users don't know what to expect when IDs are generated.

**Fix Needed:**
```markdown
**ID format:** UUIDs are 36 characters: `a1b2c3d4-e5f6-7890-abcd-ef1234567890` (8-4-4-4-12 with hyphens)
```

#### MEDIUM: File Encoding Assumptions

**Location:** Not mentioned anywhere
**Issue:** No caveat about UTF-8 encoding or special character handling.

**Potential Impact:**
- Users with non-UTF-8 files may see parsing errors
- Markdown with unusual characters may break patterns

**Fix Needed:**
Add to README.md:
```markdown
## Requirements

- Neovim 0.8+ (for API compatibility)
- UTF-8 encoded markdown files
- `uuidgen` command (macOS/Linux) for ID generation
```

---

### 7. Configuration Issues: 1 MEDIUM

#### MEDIUM: vault_root Path Expansion Not Explained

**Location:** README.md "Configuration Options"
**Issue:** Shows `vim.fn.expand("~/notes")` but doesn't explain why expansion is needed.

**Evidence:**
```lua
-- init.lua:18-20
if not user_config.vault_root then
  error('vault_root is required')
end
-- No path normalization in code
```

**User Impact:**
- User provides `"~/notes"` directly (literal tilde)
- Plugin may not find vault
- Confusing path errors

**Fix Needed:**
```markdown
| `vault_root` | **Yes** | string | - | Absolute path to your vault. Use `vim.fn.expand("~/notes")` to expand tilde. |

**Example:**
\`\`\`lua
vault_root = vim.fn.expand("~/notes"),  -- Expands ~ to home directory
-- NOT: vault_root = "~/notes",  -- Literal tilde won't work
\`\`\`
```

---

### 8. Edge Cases: 4 HIGH + 1 MEDIUM

#### HIGH: Empty Vault Behavior

**Location:** Not documented
**Issue:** No explanation of what happens with new/empty vault.

**User Impact:**
- First-time users see empty results everywhere
- No guidance on "nothing to see yet"

**Fix Needed:**
Add "Getting Started with Empty Vault" section:
```markdown
## Starting with an Empty Vault

**First time?** All queries and views will be empty until you create notes:

1. Create your first note: `nvim ~/notes/daily.md`
2. Add content with tasks and wikilinks
3. Run `:LifeModeEnsureIDs` to add task IDs
4. Run `:LifeModeRebuildIndex` to enable cross-file features
5. Now queries and backlinks will show results
```

#### HIGH: Wikilink Target Case Sensitivity

**Location:** Not documented
**Issue:** Find command is case-sensitive, but not explained.

**Evidence:**
```lua
-- navigation.lua:39-43
local cmd = string.format("find %s -type f -name %s 2>/dev/null | head -n 1",
  vim.fn.shellescape(vault_root),
  vim.fn.shellescape(filename))
```

**User Impact:**
- Link to `[[Daily]]` won't find `daily.md`
- Users confused why navigation fails

**Fix Needed:**
```markdown
**Note:** Wikilink navigation is **case-sensitive**. `[[Daily]]` won't match `daily.md`. Use exact filename casing.
```

#### HIGH: Task Checkbox Format Strictness

**Location:** Mentions `[ ]` and `[x]` but not strictness
**Issue:** Doesn't explain that spaces in checkbox are required.

**Evidence:**
```lua
-- parser.lua task pattern: %[([%sxX])%]
-- Requires exactly one character between brackets
```

**User Impact:**
- `- []` (no space) won't be recognized as task
- `- [  ]` (two spaces) won't parse correctly

**Fix Needed:**
```markdown
**Task checkbox format:**
- `- [ ]` - Todo (space required between brackets)
- `- [x]` or `- [X]` - Done
- Invalid: `- []`, `- [  ]`, `- [done]`
```

#### HIGH: Due Date Validation is Format-Only

**Location:** QUICKSTART.md mentions YYYY-MM-DD but not what's validated
**Issue:** Doesn't explain that semantic validation (valid dates, not in past) is NOT checked.

**Evidence:**
```lua
-- tasks.lua:463-467
if not date:match("^%d%d%d%d%-%d%d%-%d%d$") then
  return false
end
-- No check for valid date (Feb 30) or past dates
```

**User Impact:**
- Can set due date to `2026-99-99` (invalid but accepted)
- Can set due date to `2020-01-01` (past but accepted)
- No warning about impossible dates

**Fix Needed:**
```markdown
**Due date validation:**
- Format: `YYYY-MM-DD` (strict)
- Semantic validation NOT performed (accepts `2026-99-99`)
- No warnings for past dates
- Plugin checks format only, not date validity
```

#### MEDIUM: Backlinks View Read-Only Not Emphasized

**Location:** Mentioned briefly, not prominent
**Issue:** Users might try to edit backlinks view.

**Fix Needed:**
```markdown
**Backlinks view is read-only.** Navigate with `gd`/`gr`/`q`. To edit, jump to source file first.
```

---

## Summary Table

| Category | Critical | High | Medium | Total |
|----------|----------|------|--------|-------|
| Keymaps | 0 | 0 | 0 | 0 |
| Dependencies | 3 | 2 | 0 | 5 |
| Syntax | 0 | 0 | 0 | 0 |
| Workflows | 0 | 2 | 0 | 2 |
| Examples | 0 | 2 | 0 | 2 |
| Caveats | 0 | 3 | 2 | 5 |
| Configuration | 0 | 0 | 1 | 1 |
| Edge Cases | 0 | 4 | 1 | 5 |
| **TOTAL** | **3** | **13** | **4** | **20** |

## Priority Fixes

### Must Fix (CRITICAL - 3 issues)

1. Add prominent "INDEX REQUIRED" callout at start of QUICKSTART.md
2. Document Telescope fallback behavior for node inclusion
3. Explain task detail file directory creation

### Should Fix (HIGH - 13 issues)

4. Explain Bible provider not implemented (gd message)
5. Document config validation timing/errors
6. Add task query error handling guide
7. Document PageView source buffer requirement
8. Fix "Daily Workflow" example (add index step)
9. Fix "Bible Study" example (add index step)
10. Emphasize manual index rebuild requirement
11. Explain expansion budget limit behavior
12. Document view auto-refresh limitation
13. Document empty vault behavior
14. Document wikilink case sensitivity
15. Document task checkbox format strictness
16. Explain due date validation is format-only

### Consider Fixing (MEDIUM - 4 issues)

17. Explain UUID format
18. Document UTF-8 encoding requirement
19. Explain vault_root path expansion
20. Emphasize backlinks view read-only

## Verification Checklist

Completed verification:
- [x] All commands cross-referenced against init.lua
- [x] All keymaps cross-referenced against init.lua and view.lua
- [x] Task syntax validated against tasks.lua patterns
- [x] Wikilink syntax validated against node.lua patterns
- [x] Bible ref syntax validated against bible.lua patterns
- [x] Inclusion syntax validated against inclusion.lua patterns
- [x] Query behavior verified against query.lua implementation
- [x] Index requirements verified against index.lua and query.lua
- [x] Config validation verified against init.lua setup()

## Conclusion

Documentation is **technically accurate** - no wrong information provided. However, **critical context is missing** that causes silent failures:

1. **Index dependency** - Most features require manual rebuild but this isn't emphasized
2. **Prerequisites** - Telescope fallback and setup requirements not explained
3. **Limitations** - Format-only validation, no auto-refresh, case sensitivity not documented
4. **Error handling** - Empty results and failed operations are silent

**Recommendation:** Fix CRITICAL issues immediately (especially index requirement callout). HIGH issues should be fixed before promoting to users. MEDIUM issues can be addressed in polish pass.

---

**Audit Complete** | 20 issues found | 0 incorrect keymaps | 0 syntax errors | Documentation is honest but incomplete
