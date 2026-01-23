# Phase 33: Render Transclusions in Buffer

## Overview
Display transcluded content inline within buffers. This is application layer orchestration combining domain expansion with infrastructure rendering (extmarks, virtual text, concealment).

## Function Signatures

### `M.render_transclusions(bufnr) → Result<()>`
Main entry point for rendering transclusions in a buffer.

**Parameters:**
- `bufnr: number` - buffer to render transclusions in

**Returns:**
- `Result<()>` - success or error

**Logic:**
1. Validate buffer
2. Get buffer content (all lines)
3. Parse transclusion tokens via `domain.transclude.parse()`
4. For each token:
   - Expand via `domain.transclude.expand()` with `index.find_by_id` as fetch_fn
   - Create extmarks for visual rendering
   - Set up concealment for original token
   - Add virtual text markers
5. Set buffer conceallevel=2

### `M.setup_autocommands()`
Register autocommands for automatic rendering.

**Logic:**
- `BufEnter *.md` → call `render_transclusions(bufnr)`
- Debounce or check if already rendered (avoid redundant work)

### Helper: `create_transclusion_extmark(bufnr, line, token, expanded_content)`
Create visual elements for a single transclusion.

**Parameters:**
- `bufnr: number`
- `line: number` - 0-indexed line where token appears
- `token: {uuid, depth?, start_pos, end_pos}`
- `expanded_content: string` - the expanded text

**Logic:**
1. Create namespace `lifemode_transclusions` if not exists
2. Set extmark with:
   - `conceal = ""` (hide the {{...}} token)
   - `virt_text = {{"▼ Transcluded from <title>", "LifeModeTransclusionVirtual"}}`
   - Gutter sign `»` with highlight `LifeModeTransclusionSign`
3. If expanded_content contains error markers (⚠️), use error highlight
4. Otherwise use success highlight `LifeModeTransclusion`

### Helper: `define_highlight_groups()`
Define or ensure highlight groups exist.

**Logic:**
```lua
vim.api.nvim_set_hl(0, "LifeModeTransclusion", {bg = "#2a2a2a"})
vim.api.nvim_set_hl(0, "LifeModeTransclusionSign", {fg = "#6c6c6c"})
vim.api.nvim_set_hl(0, "LifeModeTransclusionError", {bg = "#3a1a1a", fg = "#ff6666"})
vim.api.nvim_set_hl(0, "LifeModeTransclusionVirtual", {fg = "#4a4a4a"})
```

## Data Flow

```
render_transclusions(bufnr)
  ↓
nvim_buf_get_lines() → buffer_content
  ↓
transclude.parse(content) → tokens[]
  ↓
for each token:
  ↓
  transclude.expand(content[token], {}, 0, 10, index.find_by_id) → expanded
  ↓
  create_transclusion_extmark(bufnr, line, token, expanded)
    ↓
    nvim_buf_set_extmark(..., conceal="", virt_text=..., sign=...)
  ↓
set buffer conceallevel=2
```

## Visual Rendering Strategy

**For MVP (Phase 33):**
- Use extmarks with `conceal` option to hide {{uuid}} tokens
- Add virtual text at token position showing expansion
- Gutter sign for visual indicator
- No multi-line expansion rendering yet (just show inline)

**Simplifications for MVP:**
- Don't compute node titles (use UUID in virtual text)
- Don't handle multi-line transclusions specially
- No "End transclusion" marker (just start marker)
- Error states shown inline (⚠️ messages from expand())

**Future phases can add:**
- Multi-line background highlighting
- Title resolution from index
- End markers
- Hover behavior

## Integration with Index

Use `require("lifemode.infra.index").find_by_id` as fetch_fn for expansion.

This provides database access without coupling domain layer to infrastructure.

## Command Registration

Create command `:LifeModeRefreshTransclusions` that calls `render_transclusions()` on current buffer.

## Error Handling

**Invalid buffer:**
- Return `Err("buffer not valid")`

**Index not available:**
- Fail gracefully, show warning in transclusion spot

**Expansion errors:**
- Already handled by domain layer (inline ⚠️ messages)
- Render those error messages with error highlight

## Integration Tests

### Test 1: Render single transclusion
```lua
-- Given buffer with "Hello {{uuid-b}}"
-- And node B exists in index
-- When render_transclusions(bufnr)
-- Then buffer shows expanded content
-- And original token is concealed
```

### Test 2: Render with error
```lua
-- Given buffer with "{{missing-uuid}}"
-- When render_transclusions(bufnr)
-- Then buffer shows "⚠️ Node not found: {{missing-uuid}}"
-- And uses error highlight
```

### Test 3: Multiple transclusions
```lua
-- Given buffer with "{{a}} and {{b}}"
-- When render_transclusions(bufnr)
-- Then both tokens expanded and rendered
```

### Test 4: Command invocation
```lua
-- When :LifeModeRefreshTransclusions executed
-- Then current buffer transclusions rendered
```

## Dependencies

**Existing:**
- `domain.transclude.parse()` - parse tokens
- `domain.transclude.expand()` - expand recursively
- `infra.index.find_by_id()` - fetch nodes
- `nvim_buf_set_extmark()` - Neovim API

**New:**
- Transclusion namespace for extmarks
- Highlight group definitions

## Notes

- This is MVP rendering - focus on correctness, not polish
- Concealment hides original tokens when cursor not on line
- Virtual text shows expansion inline (good for short transclusions)
- Multi-line transclusions will look ugly (acceptable for MVP)
- Phase 34 will add caching for performance
- Future phases can improve visual polish (backgrounds, boundaries, etc.)
