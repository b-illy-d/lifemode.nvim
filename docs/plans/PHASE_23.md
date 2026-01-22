# Phase 23: Incremental Index Updates - Implementation Plan

## Overview
Update SQLite index automatically when markdown files are saved. Parse buffer for nodes and upsert (insert or update) into index. Async execution with debouncing to avoid blocking UI or thrashing on rapid saves.

## Module: `lua/lifemode/app/index.lua`

### Function Signatures

#### 1. `update_index_for_buffer(bufnr)`
**Purpose:** Update index with nodes from buffer

**Parameters:**
- `bufnr` (number): Buffer number

**Returns:** `Result<{inserted, updated, errors}>`
- `inserted` (number): Count of new nodes inserted
- `updated` (number): Count of existing nodes updated
- `errors` (table): Array of error messages

**Behavior:**
1. Validate bufnr
2. Get file path from buffer
3. Parse buffer for nodes (reuse parse_buffer logic)
4. For each parsed node:
   - Try insert_node()
   - If "already exists" error: call update_node()
   - If other error: collect in errors array
5. Return statistics

**Error cases:**
- Invalid bufnr → Err("Invalid buffer")
- Buffer not associated with file → Err("Buffer has no file path")
- Parse errors → Collect in errors array, continue
- Index errors → Collect in errors array, continue

#### 2. `update_index_for_buffer_async(bufnr)`
**Purpose:** Async wrapper around update_index_for_buffer

**Parameters:**
- `bufnr` (number): Buffer number

**Returns:** `nil` (async, notifications only)

**Behavior:**
1. Run update_index_for_buffer() in vim.schedule()
2. On success: notify if errors exist
3. On failure: notify error
4. Non-blocking, silent on success (no spam)

#### 3. `setup_autocommand()`
**Purpose:** Register BufWritePost autocommand

**Parameters:** None

**Returns:** `Result<()>`

**Behavior:**
1. Create augroup "LifeModeIndexing"
2. Register BufWritePost *.md autocmd
3. Debounce: store last update time per buffer, skip if < 500ms
4. Call update_index_for_buffer_async()

**Error cases:**
- Autocommand creation fails → Err("Failed to create autocommand")

### Helper Functions

#### `get_buffer_file_path(bufnr)`
**Purpose:** Get absolute file path for buffer

**Parameters:**
- `bufnr` (number): Buffer number

**Returns:** `Result<string>` (absolute path)

**Behavior:**
1. Get buffer name via vim.api.nvim_buf_get_name()
2. If empty → Err("Buffer has no file path")
3. Return absolute path

#### `debounce_update(bufnr)`
**Purpose:** Check if update should be skipped due to recent update

**Parameters:**
- `bufnr` (number): Buffer number

**Returns:** `boolean` (true = skip, false = proceed)

**Behavior:**
1. Check _last_update[bufnr] timestamp
2. If current_time - last_update < 500ms: return true (skip)
3. Update _last_update[bufnr] = current_time
4. Return false (proceed)

### Data Flow

```
BufWritePost *.md
    ↓
debounce_update(bufnr) → skip if recent
    ↓
update_index_for_buffer_async(bufnr)
    ↓ (vim.schedule)
update_index_for_buffer(bufnr)
    ↓
parse buffer → nodes[]
    ↓ for each node
Try index.insert_node()
    ↓ if "already exists"
index.update_node()
    ↓
Return stats
```

### Integration with Existing Modules

**Parse logic:**
```lua
local parse_buffer = require("lifemode.app.parse_buffer")
local node = require("lifemode.domain.node")

-- Reuse node parsing logic
local parse_result = node.parse(node_text)
```

**Index operations:**
```lua
local index = require("lifemode.infra.index")

-- Try insert first
local insert_result = index.insert_node(node, file_path)
if not insert_result.ok then
  if insert_result.error:match("already exists") then
    -- Node exists, update it
    local update_result = index.update_node(node, file_path)
    -- handle update result
  end
end
```

**Buffer operations:**
```lua
local buf = require("lifemode.infra.nvim.buf")

-- Get buffer lines
local lines = buf.get_lines(bufnr, 0, -1)

-- Get file path
local file_path = vim.api.nvim_buf_get_name(bufnr)
```

### Debouncing Strategy

**Implementation:**
```lua
local M = {}

local _last_update = {}  -- bufnr -> timestamp

local function debounce_update(bufnr)
  local now = vim.loop.now()
  local last = _last_update[bufnr] or 0

  if now - last < 500 then
    return true  -- skip
  end

  _last_update[bufnr] = now
  return false  -- proceed
end
```

**Why 500ms:**
- Balance between responsiveness and avoiding thrashing
- User might save multiple times rapidly (e.g., auto-save plugins)
- 500ms is imperceptible to user but prevents redundant updates

### Async Execution Strategy

**Approach: vim.schedule()**
- Simpler than vim.loop coroutines
- Sufficient for this use case (not long-running operation)
- Index operations are fast (<10ms per node typically)

**Alternative considered: vim.loop**
- More complex, requires coroutine management
- Overkill for quick DB operations
- Reserve for future FTS5 indexing (more expensive)

### Error Handling

**Philosophy:**
- Silent on success (no notification spam)
- Collect errors, notify only if errors exist
- Continue processing other nodes if one fails
- Non-blocking: errors don't prevent file save

**Error message format:**
```
[LifeMode] Index update completed with 2 errors:
  - Node abc123: failed to parse
  - Node def456: database error
```

### Test Plan

#### Test 1: Insert new node on save
```lua
-- 1. Open new markdown file
-- 2. Write node with frontmatter
-- 3. Save file
-- 4. Query index, verify node exists
```

#### Test 2: Update existing node on save
```lua
-- 1. Open file with existing node (from rebuild)
-- 2. Modify node content
-- 3. Save file
-- 4. Query index, verify content updated
```

#### Test 3: Debouncing works
```lua
-- 1. Open file
-- 2. Save file twice rapidly (<500ms apart)
-- 3. Verify only one index update occurred
```

#### Test 4: Multiple nodes in one file
```lua
-- 1. Open file with 3 nodes
-- 2. Modify one node
-- 3. Save
-- 4. Verify all 3 nodes indexed correctly
```

#### Test 5: Error handling
```lua
-- 1. Open file with invalid frontmatter
-- 2. Save
-- 3. Verify notification shows error for invalid node
-- 4. Verify other valid nodes still indexed
```

#### Test 6: No file path buffer
```lua
-- 1. Create unsaved buffer (:new)
-- 2. Save attempt
-- 3. Verify graceful error (no crash)
```

## Dependencies
- `lifemode.util` (Result type)
- `lifemode.infra.index` (insert_node, update_node)
- `lifemode.domain.node` (parse, validate)
- `lifemode.infra.nvim.buf` (get_lines)
- Neovim APIs (vim.api, vim.schedule, vim.loop, vim.notify)

## Acceptance Criteria
- [ ] update_index_for_buffer() parses and upserts nodes
- [ ] Autocommand fires on BufWritePost *.md
- [ ] Debouncing prevents thrashing (<500ms)
- [ ] Async execution doesn't block UI
- [ ] Error collection and reporting works
- [ ] Tests pass

## Design Decisions

### Decision: Upsert pattern (try insert, fall back to update)
**Rationale:** Simpler than checking existence first. Insert is optimistic path (most common for incremental updates). If node exists, database returns UNIQUE constraint error, we handle by calling update. One less database query in common case.

### Decision: vim.schedule() not vim.loop
**Rationale:** Index operations are fast (<10ms per node). vim.schedule() is simpler and sufficient. Don't need true async coroutines for this. Reserve vim.loop for future expensive operations like FTS5 indexing.

### Decision: 500ms debounce
**Rationale:** Balance between responsiveness and avoiding redundant work. User might have auto-save plugins or save multiple times rapidly. 500ms is imperceptible but prevents thrashing. Can tune later if needed.

### Decision: Silent on success, notify on errors
**Rationale:** Avoid notification spam. User doesn't need confirmation every save. Only notify if something goes wrong. Collect errors and show summary, not one notification per error.

### Decision: Continue on errors
**Rationale:** One bad node shouldn't prevent indexing other nodes. Collect errors for reporting but process all nodes. Resilient operation.

### Decision: Store debounce state in module-local table
**Rationale:** Simple, effective. Clear on plugin reload. Could use buffer-local variable but module-local is cleaner and sufficient.

### Decision: Parse buffer inline, don't call parse_and_mark_buffer
**Rationale:** parse_and_mark_buffer creates extmarks which we don't need here. Reuse the parsing logic but not the full function. Avoids unnecessary extmark operations on every save.

### Decision: No retry logic
**Rationale:** Database errors are rare and usually unrecoverable (schema mismatch, disk full). Retrying won't help. Log error and move on. User can rebuild index if needed.
