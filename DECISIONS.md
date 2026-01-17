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
