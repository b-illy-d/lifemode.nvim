# Phase 10: Capture Node Use Case

## Overview

First complete workflow that ties together all previous phases.
Creates a new node and saves it to disk in the date-based directory structure.

## Function Signatures

### `capture_node(initial_content?) → Result<{node, file_path}>`

Main entry point for the capture workflow.

**Parameters:**
- `initial_content` (string, optional): Initial content for the node. Defaults to empty string.

**Returns:**
- `Ok({node = <Node>, file_path = <string>})` on success
- `Err(<error_message>)` on failure at any step

**Process:**
1. Get vault path from config
2. Compute date path for today using `infra.fs.path.date_path()`
3. Create node using `domain.node.create(content, meta)`
4. Serialize node to markdown using `domain.node.to_markdown()`
5. Generate file path: `{date_path}/{node.id}.md`
6. Write to disk using `infra.fs.write.write()`
7. Return node and file_path

**Error handling:**
- Vault path not configured: return Err
- Invalid vault path: return Err
- Directory creation failure: propagate from fs.write
- File write failure: propagate from fs.write
- Node creation failure: propagate from domain.node.create

## Data Structures

### Result shape for success
```lua
{
  node = {
    id = "uuid-string",
    content = "...",
    meta = {
      id = "uuid-string",
      created = 1234567890,
      modified = 1234567890
    }
  },
  file_path = "/absolute/path/to/vault/YYYY/MM-Mmm/DD/uuid.md"
}
```

## Integration Tests

### Test 1: Successful capture
```lua
-- Given: valid config with vault_path set
-- When: capture_node("test content") called
-- Then:
--   - Returns Ok result
--   - node.content == "test content"
--   - node.meta.created is timestamp
--   - node.meta.id is valid UUID
--   - file exists at returned file_path
--   - file content matches node.to_markdown(node)
```

### Test 2: Empty content capture
```lua
-- Given: valid config
-- When: capture_node() called with no args
-- Then:
--   - Returns Ok result
--   - node.content == ""
--   - File created successfully
```

### Test 3: Vault not configured
```lua
-- Given: config.get("vault_path") returns nil
-- When: capture_node() called
-- Then:
--   - Returns Err("vault_path not configured")
--   - No file created
```

### Test 4: Invalid vault path
```lua
-- Given: config.get("vault_path") returns invalid/inaccessible path
-- When: capture_node() called
-- Then:
--   - Returns Err with meaningful message
--   - No partial files/directories created
```

### Test 5: Date path computation
```lua
-- Given: valid config
-- When: capture_node() called
-- Then:
--   - File created in correct YYYY/MM-Mmm/DD/ structure
--   - Month abbreviation correct (e.g., "01-Jan")
```

## Dependencies

- `lifemode.config` (get vault_path)
- `lifemode.domain.node` (create, to_markdown)
- `lifemode.infra.fs.path` (date_path)
- `lifemode.infra.fs.write` (write, mkdir)
- `lifemode.util` (Ok, Err)

## Notes

- This is APPLICATION layer orchestration
- No direct Neovim API calls (that's Phase 11)
- Pure coordination of domain and infrastructure
- Every step can fail; propagate errors using Result pattern
