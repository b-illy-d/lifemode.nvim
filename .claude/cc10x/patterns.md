# Project Patterns

## Architecture Patterns
- Neovim plugin with Lua
- Engine boundary: keep parsing/indexing separate from UI
- Start with pure Lua, prepare for external process later

## Code Conventions
- Use plenary.nvim for utilities and testing
- Keep dependencies minimal
- Follow Neovim plugin structure: lua/lifemode/

## File Structure
- `lua/lifemode/init.lua` - main entry point with setup()
- `lua/lifemode/config.lua` - configuration management
- `lua/lifemode/engine/` - parsing, indexing, query logic
- `tests/lifemode/` - test files using plenary

## Testing Patterns
- Use plenary.nvim test harness
- File naming: `*_spec.lua`
- TDD cycle: RED → GREEN → REFACTOR

## Common Gotchas
- vault_root must be provided by user (required config)
- Leader key is configurable, default is `<Space>`
- Bible references are first-class features

## Dependencies
- plenary.nvim (async, utilities, testing)
- telescope.nvim (fuzzy finder, pickers)
- nvim-treesitter (optional, for enhanced Markdown parsing)

## Error Handling
- Validate required config (vault_root)
- Provide clear error messages for missing config
