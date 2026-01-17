# Decisions Log

Quick notes on decisions made during development.

## Phase 5: Navigation

### bufhidden changed from 'wipe' to 'hide'
**Why**: View buffers were being wiped when jumping to source files, making return impossible.
**Trade-off**: Buffers persist until explicitly deleted. Using buffer ID in name ensures uniqueness.

### ID pattern now includes underscores
**Why**: Tests expected `^my_id` style IDs but parser only supported `[%w%-:]`.
**Fix**: Updated parser pattern to `[%w%-_:]` to support underscores alongside hyphens and colons.

### Tests updated for :LifeMode (not :LifeModeOpen)
**Why**: Old tests expected a command that didn't exist.
**Note**: The actual command is `:LifeMode`, not `:LifeModeOpen`.

## Phase 6: Task Management

### Date/tag picker keymaps deferred
**Why**: `<Space>td` (date) and `<Space>tt` (tag) need UI pickers/prompts.
**Decision**: Core patch operations implemented; keymaps deferred to future phase.

### Priority bounds: !1 (highest) to !5 (lowest)
**Why**: Matches org-mode convention where lower number = higher priority.
**Behavior**:
- inc_priority at !1 stays at !1
- dec_priority at !5 removes priority entirely
- inc_priority on no-priority adds !3 (middle)

### Patch module architecture
**Why**: Clean separation between view logic and file modification.
**Pattern**: All patch ops take `(node_id, idx)` and return result + modify file.

## Phase 7: All Tasks View

### Grouping cycle order: due_date → priority → tag
**Why**: Most common workflow is checking what's due, then by urgency, then by project.

### Filter toggle deferred
**Why**: `<Space>f` for done tasks filter needs done task support in grouping.
**Decision**: Implemented grouping cycling, filter toggle can be added later.

### Task sorting by priority within groups
**Why**: Even in due-date or tag grouping, highest priority tasks should appear first.
**Implementation**: `sort_by_priority()` applied before any grouping.

## Phase 8: Wikilinks and References

### Backlinks use file:line as source_id for nodes without ID
**Why**: Not all nodes have IDs, but we still need to track where references come from.
**Pattern**: `source_id = node.id or (file_path .. ':' .. node.line)`

### Wikilink module separate from parser
**Why**: Cursor-based wikilink detection is runtime behavior, not parsing.
**Trade-off**: Could share parsing logic, but separation keeps concerns clear.

### Heading lookup strips block IDs
**Why**: `## Section ^block-id` should match `[[Page#Section]]`.
**Fix**: Strip `%^[%w%-_:]+%s*$` pattern before comparing heading text.

## Phase 9: Bible References

### Bible verse ID format: `bible:book:chapter:verse`
**Why**: Deterministic, human-readable, easy to parse.
**Pattern**: `bible:john:17:20` - book lowercased, spaces become hyphens.

### Range refs expand to individual verse IDs in backlinks
**Why**: `John 17:18-23` should show up when querying for any verse in range.
**Implementation**: `expand_range()` creates IDs for each verse, all indexed as backlinks.

### Bible gd shows URL, not inline text
**Why**: Inline text requires Bible text provider (API, local database).
**MVP**: Generate Bible Gateway URL and notify user. Real provider deferred.

### Parser extracts both wikilinks and Bible refs
**Why**: Need unified refs system for backlinks.
**Pattern**: `_extract_all_refs()` combines `_extract_wikilinks()` and `_extract_bible_refs()`.
