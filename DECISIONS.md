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
