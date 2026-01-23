# Phase 36: Parse Basic Citations

## Overview
Parse BibTeX-style citations from content. Extract `@key` patterns and create Citation value objects.

## Function Signature

### `M.parse_citations(content) → Citation[]`
Parse citations from text content.

**Parameters:**
- `content: string` - text to parse for citations

**Returns:**
- `Citation[]` - array of Citation value objects

**Pattern:**
- Regex: `@([a-zA-Z0-9_-]+)`
- Extract key after `@` symbol
- Scheme: always "bibtex" for now
- Raw: full match including `@`

**Logic:**
```lua
function M.parse_citations(content)
  if type(content) ~= "string" then
    return {}
  end

  local citations = {}
  local pattern = "@([a-zA-Z0-9_%-]+)"

  local search_start = 1
  while true do
    local match_start, match_end, key = content:find(pattern, search_start)

    if not match_start then
      break
    end

    if key and key ~= "" then
      local raw = content:sub(match_start, match_end)

      local citation_result = types.Citation_new(
        "bibtex",
        key,
        raw,
        nil  -- no location for simple parsing
      )

      if citation_result.ok then
        table.insert(citations, citation_result.value)
      end
    end

    search_start = match_end + 1
  end

  return citations
end
```

## Data Structure

Citations returned as array:
```lua
{
  {
    scheme = "bibtex",
    key = "smith2020",
    raw = "@smith2020",
    location = nil
  },
  {
    scheme = "bibtex",
    key = "jones2021",
    raw = "@jones2021",
    location = nil
  }
}
```

## Integration Tests

### Test 1: Parse single citation
```lua
local result = parse_citations("See @smith2020 for details.")
assert.equals(1, #result)
assert.equals("bibtex", result[1].scheme)
assert.equals("smith2020", result[1].key)
assert.equals("@smith2020", result[1].raw)
```

### Test 2: Parse multiple citations
```lua
local result = parse_citations("@smith2020 and @jones2021")
assert.equals(2, #result)
assert.equals("smith2020", result[1].key)
assert.equals("jones2021", result[2].key)
```

### Test 3: Parse with underscores and hyphens
```lua
local result = parse_citations("@smith_jones-2020")
assert.equals(1, #result)
assert.equals("smith_jones-2020", result[1].key)
```

### Test 4: Empty content returns empty array
```lua
local result = parse_citations("")
assert.equals(0, #result)
```

### Test 5: No citations returns empty array
```lua
local result = parse_citations("No citations here.")
assert.equals(0, #result)
```

### Test 6: Invalid content type returns empty array
```lua
local result = parse_citations(nil)
assert.equals(0, #result)
```

### Test 7: Citation at start of string
```lua
local result = parse_citations("@first is the beginning")
assert.equals(1, #result)
assert.equals("first", result[1].key)
```

### Test 8: Citation at end of string
```lua
local result = parse_citations("The end is @last")
assert.equals(1, #result)
assert.equals("last", result[1].key)
```

## Dependencies

**Existing:**
- types.Citation_new() - creates Citation value objects (Phase 35)
- util.Ok(), util.Err() - error handling (not needed here, returns arrays)

**Pattern:**
- Follow same parsing pattern as transclude.parse() and link.parse_wikilinks()
- Iterate with string.find() to find all matches
- Track position and extract matches
- Return empty array for invalid input (defensive)

## Notes

- Pattern matches `@` followed by alphanumeric, underscore, or hyphen
- Scheme hardcoded to "bibtex" for MVP (Phase 39 will add multi-scheme support)
- No location tracking in simple parse (can be added later when parsing from buffer)
- Invalid citations (failed validation) are skipped silently
- BibTeX keys typically: author+year or custom identifiers
- Common patterns: `@smith2020`, `@jones_2021`, `@acm-survey-2019`
