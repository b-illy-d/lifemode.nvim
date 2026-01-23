# Phase 35: Citation Value Object

## Overview
Create Citation value object in domain layer. Citations represent references to external sources (papers, books, etc.) within notes.

## Function Signature

### `M.Citation_new(scheme, key, raw, location) → Result<Citation>`
Constructor for Citation value object.

**Parameters:**
- `scheme: string` - citation scheme identifier (e.g., "bibtex")
- `key: string` - unique key within scheme (e.g., "smith2020")
- `raw: string` - original citation text (e.g., "@smith2020")
- `location: table?` - optional location metadata `{node_id, line, col}`

**Returns:**
- `Result<Citation>` - Ok with citation object or Err with validation message

**Validation:**
- scheme: required, non-empty string
- key: required, non-empty string
- raw: required, non-empty string
- location: optional, if provided must be table with:
  - node_id: required string (UUID format)
  - line: required number
  - col: required number

**Logic:**
```lua
function M.Citation_new(scheme, key, raw, location)
  -- Validate scheme
  if type(scheme) ~= "string" or scheme == "" then
    return Err("Citation scheme must be non-empty string")
  end

  -- Validate key
  if type(key) ~= "string" or key == "" then
    return Err("Citation key must be non-empty string")
  end

  -- Validate raw
  if type(raw) ~= "string" or raw == "" then
    return Err("Citation raw must be non-empty string")
  end

  -- Validate location (optional)
  if location ~= nil then
    if type(location) ~= "table" then
      return Err("Citation location must be table or nil")
    end
    if type(location.node_id) ~= "string" or not is_valid_uuid(location.node_id) then
      return Err("Citation location.node_id must be valid UUID")
    end
    if type(location.line) ~= "number" then
      return Err("Citation location.line must be number")
    end
    if type(location.col) ~= "number" then
      return Err("Citation location.col must be number")
    end
  end

  -- Construct citation
  local citation = {
    scheme = scheme,
    key = key,
    raw = raw,
    location = location and deep_copy(location) or nil
  }

  return Ok(citation)
end
```

## Data Structure

```lua
Citation = {
  scheme: string,      -- "bibtex", "bible", etc.
  key: string,         -- "smith2020", "Genesis.1.1", etc.
  raw: string,         -- "@smith2020", "@Bible:Genesis.1.1", etc.
  location: {          -- optional
    node_id: UUID,
    line: number,
    col: number
  }?
}
```

## Integration Tests

### Test 1: Valid citation with location
```lua
local result = Citation_new("bibtex", "smith2020", "@smith2020", {
  node_id = "12345678-1234-4abc-1234-123456789abc",
  line = 10,
  col = 5
})
assert(result.ok)
assert.equals("bibtex", result.value.scheme)
assert.equals("smith2020", result.value.key)
assert.equals("@smith2020", result.value.raw)
assert.is_not_nil(result.value.location)
```

### Test 2: Valid citation without location
```lua
local result = Citation_new("bibtex", "smith2020", "@smith2020", nil)
assert(result.ok)
assert.is_nil(result.value.location)
```

### Test 3: Invalid scheme (empty)
```lua
local result = Citation_new("", "smith2020", "@smith2020", nil)
assert.is_false(result.ok)
assert.matches("scheme", result.error)
```

### Test 4: Invalid key (non-string)
```lua
local result = Citation_new("bibtex", 123, "@smith2020", nil)
assert.is_false(result.ok)
assert.matches("key", result.error)
```

### Test 5: Invalid location (missing node_id)
```lua
local result = Citation_new("bibtex", "smith2020", "@smith2020", {
  line = 10,
  col = 5
})
assert.is_false(result.ok)
assert.matches("node_id", result.error)
```

### Test 6: Invalid location (bad UUID)
```lua
local result = Citation_new("bibtex", "smith2020", "@smith2020", {
  node_id = "not-a-uuid",
  line = 10,
  col = 5
})
assert.is_false(result.ok)
assert.matches("UUID", result.error)
```

## Dependencies

**Existing:**
- util.Ok(), util.Err() - error handling
- types.is_valid_uuid() - UUID validation (already in types.lua)
- types.deep_copy() - deep copy for location

**Pattern:**
- Follow same pattern as Node_new() and Edge_new()
- Consistent validation error messages
- Immutable value object (deep copy location)

## Notes

- Location is optional - citations can exist without position tracking
- Deep copy location to ensure immutability
- Scheme is free-form string (not enum) - extensible for future schemes
- Key format not validated here - that's parser's job (Phase 36)
- Raw text preserved for debugging/display
