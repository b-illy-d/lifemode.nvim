# Phase 27: Parse Wikilinks - Implementation Plan

## Overview
Extract wikilink syntax from markdown content. Parse `[[Title]]`, `[[Title|Display]]`, and `[[uuid]]` formats. Pure domain logic - no I/O, no resolution (resolution happens in application layer when storing edges).

## Module: `lua/lifemode/domain/link.lua` (new module)

### Data Structure

```lua
Link = {
  type: string,         -- "wikilink", "transclusion"
  target: string,       -- The referenced text (title or UUID)
  display: string?,     -- Optional display text (from [[Target|Display]])
  position: {           -- Location in content
    start: number,      -- Character offset start
    end: number         -- Character offset end
  }
}
```

### Function Signatures

#### `M.parse_wikilinks(content)`
**Purpose:** Extract all wikilinks from content

**Parameters:**
- `content` (string): Markdown text to parse

**Returns:** `Link[]` (array of Link objects)

**Behavior:**
1. Find all `[[...]]` patterns
2. For each match:
   - Extract target text
   - Check for pipe separator (display text)
   - Determine if target is UUID or title
   - Record position in content
3. Return array of Link objects

**Wikilink formats:**
- `[[Title]]` → target="Title", display=nil
- `[[Title|Display]]` → target="Title", display="Display"
- `[[aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa]]` → target=UUID, display=nil
- `[[!Title]]` → transclusion (type="transclusion")

**Edge cases:**
- Escaped brackets: `\[[Not a link]]` → skip
- Nested brackets: `[[Outer [[Inner]]]]` → only match outermost
- Empty link: `[[]]` → skip
- Whitespace: `[[ Title ]]` → trim to "Title"

#### `M.parse_transclusions(content)`
**Purpose:** Extract transclusion syntax

**Parameters:**
- `content` (string): Markdown text to parse

**Returns:** `Link[]` (array of Link objects with type="transclusion")

**Behavior:**
Same as wikilinks but for `![[...]]` syntax.

### Regex Patterns

**Wikilink pattern:**
```lua
%[%[([^%]]+)%]%]
```

**Transclusion pattern:**
```lua
!%[%[([^%]]+)%]%]
```

**Pipe separator:**
```lua
([^|]+)|(.+)
```

### Position Tracking

Track start/end positions for:
- Highlighting links in UI
- Jump-to-link navigation
- Link refactoring (rename, delete)

Position is 1-indexed character offset in content string.

### Test Plan

#### Test 1: Simple wikilink
```lua
local link = require("lifemode.domain.link")

local content = "This is a [[Test Link]] in text"
local links = link.parse_wikilinks(content)

assert(#links == 1)
assert(links[1].type == "wikilink")
assert(links[1].target == "Test Link")
assert(links[1].display == nil)
```

#### Test 2: Wikilink with display text
```lua
local content = "See [[Target Node|this link]] for more"
local links = link.parse_wikilinks(content)

assert(#links == 1)
assert(links[1].target == "Target Node")
assert(links[1].display == "this link")
```

#### Test 3: UUID link
```lua
local content = "Reference [[aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa]] node"
local links = link.parse_wikilinks(content)

assert(#links == 1)
assert(links[1].target == "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa")
```

#### Test 4: Multiple links
```lua
local content = "[[First]] and [[Second]] and [[Third]]"
local links = link.parse_wikilinks(content)

assert(#links == 3)
assert(links[1].target == "First")
assert(links[2].target == "Second")
assert(links[3].target == "Third")
```

#### Test 5: Transclusion
```lua
local content = "Embed content: ![[Note Title]]"
local links = link.parse_transclusions(content)

assert(#links == 1)
assert(links[1].type == "transclusion")
assert(links[1].target == "Note Title")
```

#### Test 6: No links
```lua
local content = "Just plain text with no links"
local links = link.parse_wikilinks(content)

assert(#links == 0)
```

#### Test 7: Empty link
```lua
local content = "Invalid [[]] link"
local links = link.parse_wikilinks(content)

assert(#links == 0)
```

#### Test 8: Whitespace handling
```lua
local content = "Link with spaces [[  Title  ]]"
local links = link.parse_wikilinks(content)

assert(#links == 1)
assert(links[1].target == "Title")
```

#### Test 9: Position tracking
```lua
local content = "Start [[Link]] end"
local links = link.parse_wikilinks(content)

assert(links[1].position.start == 7)  -- Index of first '['
assert(links[1].position.end_pos == 14)  -- Index after last ']'
```

## Dependencies
- None (pure domain logic)
- Lua string pattern matching

## Acceptance Criteria
- [ ] parse_wikilinks() extracts all [[...]] patterns
- [ ] Handles display text (pipe separator)
- [ ] Handles UUID links
- [ ] parse_transclusions() extracts ![[...]] patterns
- [ ] Position tracking works
- [ ] Whitespace trimmed
- [ ] Empty links skipped
- [ ] Tests pass

## Design Decisions

### Decision: Pure parsing, no resolution
**Rationale:** Keep domain layer pure - no index lookups. Resolution (matching title to UUID) is application layer concern. Parser just extracts raw link text. This makes link.lua testable without database.

### Decision: Return Link array, not Edge array
**Rationale:** Links ≠ Edges. A link in markdown is unresolved text. An edge is a validated relationship with UUIDs. Application layer converts Links → Edges after resolution.

### Decision: Position tracking
**Rationale:** Essential for UI features (hover, jump-to-link, refactoring). Small overhead (8 bytes per link) for significant functionality gain.

### Decision: Whitespace trimming
**Rationale:** User might write `[[ Title ]]` with spaces. Trim for consistency. Leading/trailing whitespace in link target is never intentional.

### Decision: Skip empty links
**Rationale:** `[[]]` is invalid - nothing to link to. Silently skip rather than error (user may be typing). Errors only for malformed syntax that could cause parser bugs.

### Decision: Simple regex, not full markdown parser
**Rationale:** Full markdown parsing is complex (code blocks, escapes, etc.). For MVP, simple regex is sufficient. Known limitation: won't handle escaped brackets or links in code blocks. Can improve later.

### Decision: Separate parse_wikilinks and parse_transclusions
**Rationale:** Different semantics - wikilinks create references, transclusions embed content. Caller may want only one type. Keep functions focused.
