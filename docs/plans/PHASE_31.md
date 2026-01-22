# Phase 31: Parse Transclusion Tokens - Implementation Plan

## Overview
Parse transclusion tokens from markdown content. Tokens have format `{{uuid}}` or `{{uuid:depth}}`. Pure domain logic - no I/O, just string parsing.

## Module: `lua/lifemode/domain/transclude.lua` (new module)

### Data Structure

```lua
Token = {
  uuid: string,        -- UUID of node to transclude
  depth: number?,      -- Optional depth limit for recursive expansion
  start_pos: number,   -- Character offset where token starts (1-indexed)
  end_pos: number      -- Character offset where token ends (1-indexed)
}
```

### Function Signature

#### `M.parse(content)`
**Purpose:** Extract all transclusion tokens from content

**Parameters:**
- `content` (string): Text to parse for tokens

**Returns:** `Token[]` (array of Token objects)

**Behavior:**
1. Return empty array if content is not a string or is empty
2. Find all `{{...}}` patterns using Lua pattern matching
3. For each match:
   - Extract UUID (alphanumeric + hyphens)
   - Check for optional `:depth` suffix
   - Validate UUID format (basic check, not strict v4 validation)
   - Record start_pos and end_pos
   - Create Token object
4. Return array of all tokens found

**Regex pattern (Lua):**
```lua
{{([a-zA-Z0-9-]+)(:(%d+))?}}
```

Breakdown:
- `{{` - literal opening braces
- `([a-zA-Z0-9-]+)` - capture group 1: UUID (one or more alphanumeric/hyphen)
- `(:(%d+))?` - optional capture group: colon + digits for depth
- `}}` - literal closing braces

**Token formats:**
- `{{aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa}}` → uuid=UUID, depth=nil
- `{{aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa:2}}` → uuid=UUID, depth=2
- `{{simple-id}}` → uuid="simple-id", depth=nil (allows non-UUID IDs)

**Edge cases:**
- Escaped braces: Not handled in MVP (no escape mechanism defined)
- Nested tokens: `{{outer{{inner}}}}` → only match outermost
- Empty token: `{{}}` → skip (no UUID)
- Whitespace: `{{ uuid }}` → no match (requires exact format)
- Invalid depth: `{{uuid:abc}}` → skip (depth must be numeric)

### Test Plan

#### Test 1: Simple token
```lua
local transclude = require('lifemode.domain.transclude')

local content = "Text before {{aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa}} text after"
local tokens = transclude.parse(content)

assert(#tokens == 1)
assert(tokens[1].uuid == "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa")
assert(tokens[1].depth == nil)
assert(tokens[1].start_pos == 13)  -- Position of first {
assert(tokens[1].end_pos == 56)    -- Position after last }
```

#### Test 2: Token with depth
```lua
local content = "Transclude {{bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb:3}} here"
local tokens = transclude.parse(content)

assert(#tokens == 1)
assert(tokens[1].uuid == "bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb")
assert(tokens[1].depth == 3)
```

#### Test 3: Multiple tokens
```lua
local content = "{{uuid1}} and {{uuid2:2}} and {{uuid3}}"
local tokens = transclude.parse(content)

assert(#tokens == 3)
assert(tokens[1].uuid == "uuid1")
assert(tokens[1].depth == nil)
assert(tokens[2].uuid == "uuid2")
assert(tokens[2].depth == 2)
assert(tokens[3].uuid == "uuid3")
assert(tokens[3].depth == nil)
```

#### Test 4: No tokens
```lua
local content = "Plain text with no transclusions"
local tokens = transclude.parse(content)

assert(#tokens == 0)
```

#### Test 5: Empty content
```lua
local tokens = transclude.parse("")
assert(#tokens == 0)

local tokens2 = transclude.parse(nil)
assert(#tokens2 == 0)
```

#### Test 6: Invalid tokens (should skip)
```lua
local content = "{{}} {{uuid:notanumber}} {{ uuid }}"
local tokens = transclude.parse(content)

assert(#tokens == 0)  -- All invalid, none captured
```

#### Test 7: Position tracking
```lua
local content = "Start {{test}} end"
local tokens = transclude.parse(content)

assert(tokens[1].start_pos == 7)   -- "Start " = 6 chars, token at 7
assert(tokens[1].end_pos == 14)    -- {{test}} = 8 chars, ends at 14
```

#### Test 8: Depth variants
```lua
local content = "{{a:0}} {{b:1}} {{c:99}}"
local tokens = transclude.parse(content)

assert(tokens[1].depth == 0)
assert(tokens[2].depth == 1)
assert(tokens[3].depth == 99)
```

## Dependencies
- None (pure Lua string parsing)

## Acceptance Criteria
- [ ] parse() extracts all `{{uuid}}` patterns
- [ ] Handles depth suffix `{{uuid:n}}`
- [ ] Position tracking works (start_pos, end_pos)
- [ ] Empty content returns empty array
- [ ] Invalid tokens skipped
- [ ] Multiple tokens in one string work
- [ ] Tests pass

## Design Decisions

### Decision: Allow non-UUID identifiers
**Rationale:** Regex allows `[a-zA-Z0-9-]+` which is more permissive than strict UUID v4. This gives flexibility - users could use simpler IDs like "intro" or "conclusion". Strict UUID validation can happen at expansion time (Phase 32) when looking up nodes. Parser just extracts the identifier text.

### Decision: No escape mechanism for literal braces
**Rationale:** MVP doesn't define how to write literal `{{` in content. If user wants literal double braces, they're out of luck. This can be added later (e.g., `\{{` for escaping). For now, assume all `{{...}}` are transclusion tokens. Simpler parsing, covers 99% of use cases.

### Decision: Depth is optional, defaults to nil
**Rationale:** Not all transclusions need depth limits. `{{uuid}}` expands fully (infinite depth, with cycle detection). `{{uuid:2}}` limits to 2 levels deep. nil depth = unlimited (up to cycle detection or max depth in expander).

### Decision: 1-indexed positions
**Rationale:** Lua uses 1-indexed strings (string.find returns 1-based positions). Keep positions consistent with Lua conventions. When used with Neovim (0-indexed), caller converts.

### Decision: Return empty array for invalid input
**Rationale:** If content is nil, not a string, or empty, return `{}` not error. This makes parser more forgiving - caller doesn't need to check type first. Simpler API. Only runtime error if Lua pattern fails (which shouldn't happen with our pattern).

### Decision: Skip invalid tokens silently
**Rationale:** If token has invalid format (e.g., `{{uuid:abc}}`), don't include it in results. Don't error - just skip. User can see their token didn't work when it doesn't expand. Strict validation would complicate parsing and error handling for marginal benefit.

### Decision: Outer match only for nested braces
**Rationale:** If user writes `{{outer{{inner}}}}`, Lua pattern will match `{{outer{{inner}}` (greedy until first closing `}}`). This is undefined behavior - don't try to handle it cleverly. ROADMAP spec doesn't mention nesting, so assume it won't happen. If it does, behavior is undefined (may or may not parse correctly).
