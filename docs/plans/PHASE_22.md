# Phase 22: Index Builder (Full Scan) - Implementation Plan

## Overview
Build index from vault files. Recursively scan vault directory for markdown files, parse nodes from each file, and insert into SQLite index. Progress reporting and error collection for resilient operation.

## Module: `lua/lifemode/infra/index/builder.lua`

### Function Signatures

#### 1. `rebuild_index(vault_path)`
**Purpose:** Rebuild entire index from vault files

**Parameters:**
- `vault_path` (string, optional): Path to vault directory. If nil, uses config.get("vault_path")

**Returns:** `Result<{scanned, indexed, errors}>`
- `scanned` (number): Total files scanned
- `indexed` (number): Successfully indexed nodes
- `errors` (table): Array of error messages

**Behavior:**
1. Get vault_path from config if not provided
2. Clear existing index (DELETE FROM nodes, DELETE FROM edges)
3. Find all `.md` files recursively via vim.fn.glob()
4. For each file:
   - Read file content
   - Parse for nodes (frontmatter blocks)
   - For each node found:
     - Create Node object from domain layer
     - Insert into index via index.insert_node()
   - Report progress every 10 files (vim.notify)
5. Collect errors but continue processing
6. Return summary statistics

**Error cases:**
- Invalid vault_path → Err("Invalid vault path")
- File read error → Collect in errors array, continue
- Parse error → Collect in errors array, continue
- Index insert error → Collect in errors array, continue

#### 2. `find_markdown_files(vault_path)`
**Purpose:** Find all markdown files recursively

**Parameters:**
- `vault_path` (string): Directory to search

**Returns:** `Result<table>` (array of absolute file paths)

**Behavior:**
1. Use vim.fn.glob(vault_path .. "/**/*.md", false, true)
2. Filter out hidden directories (exclude paths with "/.") - EXCEPT .lifemode
3. Return array of file paths

**Error cases:**
- Directory doesn't exist → Err("Directory not found")
- No read permission → Err("Permission denied")

#### 3. `parse_file_for_nodes(file_path)`
**Purpose:** Parse markdown file and extract nodes

**Parameters:**
- `file_path` (string): Absolute path to markdown file

**Returns:** `Result<table>` (array of Node objects with file_path)

**Behavior:**
1. Read file content via fs.read()
2. Split into lines
3. Find node boundaries (same logic as parse_buffer)
4. For each node:
   - Extract frontmatter lines
   - Parse YAML frontmatter
   - Extract content (lines after closing ---)
   - Create Node object via domain.node functions
   - Attach file_path metadata
5. Return array of nodes

**Error cases:**
- File read error → Err("Failed to read file")
- Invalid frontmatter → Skip node, continue parsing
- Missing required fields → Skip node, continue parsing

#### 4. `clear_index()`
**Purpose:** Delete all data from index

**Parameters:** None

**Returns:** `Result<()>`

**Behavior:**
1. Open database connection
2. Execute: DELETE FROM edges
3. Execute: DELETE FROM nodes
4. Close connection
5. Return Ok(nil)

**Error cases:**
- Database error → Err("Failed to clear index")

### Helper Functions

#### `parse_frontmatter(lines)`
**Purpose:** Parse YAML frontmatter into table

**Parameters:**
- `lines` (table): Array of frontmatter lines (between --- markers)

**Returns:** `table` (parsed metadata)

**Behavior:**
1. Join lines into string
2. Parse YAML (simple key: value parsing)
3. Return metadata table with id, created, etc.

#### `report_progress(current, total, indexed)`
**Purpose:** Display progress notification

**Parameters:**
- `current` (number): Current file number
- `total` (number): Total files
- `indexed` (number): Nodes indexed so far

**Behavior:**
1. Every 10 files, show notification:
   "Rebuilding index: {current}/{total} files, {indexed} nodes"
2. Use vim.notify with INFO level

### Data Flow

```
Vault Directory
    ↓ find_markdown_files()
File Paths[]
    ↓ for each file
parse_file_for_nodes()
    ↓
Node objects[]
    ↓ for each node
index.insert_node()
    ↓
SQLite Database
```

### Integration with Existing Modules

**Domain layer:**
```lua
local node = require("lifemode.domain.node")
-- Use node.create() to construct Node objects
```

**Infrastructure layer:**
```lua
local index = require("lifemode.infra.index")
local fs_read = require("lifemode.infra.fs.read")

-- Insert node
local result = index.insert_node(node_obj, file_path)

-- Read file
local content_result = fs_read.read(file_path)
```

**Config:**
```lua
local config = require("lifemode.config")
local vault_path = config.get("vault_path")
```

### Command Integration

**Command:** `:LifeModeRebuildIndex`

**Implementation in `lua/lifemode/ui/commands.lua`:**
```lua
function M.rebuild_index()
  vim.notify("[LifeMode] Starting index rebuild...", vim.log.levels.INFO)

  local builder = require("lifemode.infra.index.builder")
  local result = builder.rebuild_index()

  if not result.ok then
    vim.notify("[LifeMode] ERROR: " .. result.error, vim.log.levels.ERROR)
    return
  end

  local stats = result.value
  local message = string.format(
    "[LifeMode] Index rebuilt: %d files scanned, %d nodes indexed",
    stats.scanned, stats.indexed
  )

  if #stats.errors > 0 then
    message = message .. string.format(", %d errors", #stats.errors)
    vim.notify(message, vim.log.levels.WARN)

    -- Show first few errors
    for i = 1, math.min(3, #stats.errors) do
      vim.notify("  " .. stats.errors[i], vim.log.levels.WARN)
    end
  else
    vim.notify(message, vim.log.levels.INFO)
  end
end
```

### Integration Tests

#### Test 1: Rebuild empty vault
```lua
local builder = require("lifemode.infra.index.builder")

local temp_vault = "/tmp/test_vault_empty"
vim.fn.mkdir(temp_vault, "p")

local result = builder.rebuild_index(temp_vault)
assert(result.ok, "rebuild should succeed")
assert(result.value.scanned == 0, "no files scanned")
assert(result.value.indexed == 0, "no nodes indexed")
```

#### Test 2: Rebuild vault with nodes
```lua
local temp_vault = "/tmp/test_vault_nodes"
vim.fn.mkdir(temp_vault, "p")

-- Create test file
local test_file = temp_vault .. "/test.md"
local f = io.open(test_file, "w")
f:write([[---
id: a1b2c3d4-e5f6-4789-a012-bcdef1234567
created: 1234567890
---
Test content
]])
f:close()

local result = builder.rebuild_index(temp_vault)
assert(result.ok, "rebuild should succeed")
assert(result.value.scanned == 1, "1 file scanned")
assert(result.value.indexed == 1, "1 node indexed")

-- Verify node in index
local index = require("lifemode.infra.index")
local find_result = index.find_by_id("a1b2c3d4-e5f6-4789-a012-bcdef1234567")
assert(find_result.ok)
assert(find_result.value ~= nil, "node should be in index")
assert(find_result.value.content == "Test content\n")
```

#### Test 3: Find markdown files
```lua
local temp_vault = "/tmp/test_vault_find"
vim.fn.mkdir(temp_vault .. "/subdir", "p")

local f1 = io.open(temp_vault .. "/file1.md", "w")
f1:write("content")
f1:close()

local f2 = io.open(temp_vault .. "/subdir/file2.md", "w")
f2:write("content")
f2:close()

local result = builder.find_markdown_files(temp_vault)
assert(result.ok, "find should succeed")
assert(#result.value == 2, "should find 2 files")
```

#### Test 4: Error collection
```lua
local temp_vault = "/tmp/test_vault_errors"
vim.fn.mkdir(temp_vault, "p")

-- Create file with invalid frontmatter
local bad_file = temp_vault .. "/bad.md"
local f = io.open(bad_file, "w")
f:write([[---
id: not-a-uuid
---
Content
]])
f:close()

local result = builder.rebuild_index(temp_vault)
assert(result.ok, "rebuild should succeed despite errors")
assert(result.value.scanned == 1, "file scanned")
assert(result.value.indexed == 0, "no nodes indexed due to error")
assert(#result.value.errors > 0, "should have errors")
```

#### Test 5: Progress reporting
```lua
local temp_vault = "/tmp/test_vault_progress"
vim.fn.mkdir(temp_vault, "p")

-- Create 25 files
for i = 1, 25 do
  local f = io.open(temp_vault .. "/file" .. i .. ".md", "w")
  f:write(string.format([[---
id: %08d-0000-4000-a000-000000000000
created: 1234567890
---
Content %d
]], i, i))
  f:close()
end

local result = builder.rebuild_index(temp_vault)
assert(result.ok)
assert(result.value.scanned == 25)
-- Progress notifications would have fired at 10, 20 files
```

#### Test 6: Clear index
```lua
-- After Test 2, index has data
local clear_result = builder.clear_index()
assert(clear_result.ok, "clear should succeed")

-- Verify empty
local find_result = index.find_by_id("a1b2c3d4-e5f6-4789-a012-bcdef1234567")
assert(find_result.ok)
assert(find_result.value == nil, "index should be empty")
```

## Dependencies
- `lifemode.util` (Result type)
- `lifemode.config` (vault_path)
- `lifemode.infra.index` (insert_node, clear operations)
- `lifemode.infra.fs.read` (read files)
- `lifemode.domain.node` (create Node objects)
- Neovim APIs (vim.fn.glob, vim.notify)

## Acceptance Criteria
- [ ] rebuild_index() scans all markdown files
- [ ] Parses nodes from files
- [ ] Inserts nodes into index
- [ ] Progress reporting every 10 files
- [ ] Error collection (continue on failures)
- [ ] Returns statistics (scanned, indexed, errors)
- [ ] :LifeModeRebuildIndex command works
- [ ] Tests pass

## Design Decisions

### Decision: Clear index before rebuild (not incremental)
**Rationale:** Rebuild is full refresh - delete everything, scan everything. Ensures index matches vault state exactly. Incremental updates are separate feature (Phase 23). Full rebuild is simpler, more reliable for initial implementation.

### Decision: Continue on errors, collect in array
**Rationale:** One bad file shouldn't block entire rebuild. Collect errors for user review but process all other files. Resilient operation is critical for large vaults with mixed quality markdown.

### Decision: Progress reporting every 10 files
**Rationale:** Provides feedback for long-running operation without spamming notifications. 10 files is reasonable granularity - not too frequent, not too sparse. User knows it's working.

### Decision: Use vim.fn.glob() not vim.loop.fs_scandir()
**Rationale:** vim.fn.glob() handles recursive patterns natively ("**/*.md"). Simpler than manually walking directory tree. Returns all matches at once. Acceptable for MVP - can optimize later if performance issue.

### Decision: Parse frontmatter inline (not separate YAML library)
**Rationale:** Our frontmatter is simple (id: value, created: value). Full YAML parser is overkill. Simple line-by-line parsing is sufficient. Avoids external dependency. Can upgrade later if needed.

### Decision: Skip nodes with invalid frontmatter
**Rationale:** Parsing errors shouldn't crash rebuild. Skip problematic nodes, log error, continue. User can fix and re-run rebuild. Graceful degradation.

### Decision: builder.lua in infra/index/
**Rationale:** Builder operates on infrastructure (filesystem, database). Not pure domain logic, not application orchestration. Fits infrastructure layer - adapts external systems (filesystem) to index operations.

### Decision: Command shows summary + first 3 errors
**Rationale:** User needs to know rebuild succeeded and statistics. If errors, show first few for context but don't spam with hundreds of lines. User can check logs for full details.
