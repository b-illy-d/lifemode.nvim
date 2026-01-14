-- LifeMode: Active node highlighting and winbar updates
-- Tracks which node is under the cursor and provides visual feedback

local M = {}

-- Namespace for active node highlight
local highlight_namespace = nil

-- Get or create the highlight namespace
function M.get_highlight_namespace()
  if not highlight_namespace then
    highlight_namespace = vim.api.nvim_create_namespace('lifemode_active_node')

    -- Define highlight group for active node (subtle background)
    vim.api.nvim_set_hl(0, 'LifeModeActiveNode', {
      bg = '#2d3436',  -- Subtle gray background
      default = true,  -- Allow user overrides
    })
  end
  return highlight_namespace
end

-- Highlight the active span (node under cursor)
-- @param bufnr number: Buffer number
-- @param start_line number: Start line (0-indexed)
-- @param end_line number: End line (0-indexed, inclusive)
function M.highlight_active_span(bufnr, start_line, end_line)
  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local ns = M.get_highlight_namespace()

  -- Clear any existing highlight in this buffer
  M.clear_active_highlight(bufnr)

  -- Add highlight extmark for the span
  -- end_row is exclusive, so add 1
  vim.api.nvim_buf_set_extmark(bufnr, ns, start_line, 0, {
    end_row = end_line + 1,
    end_col = 0,
    hl_group = 'LifeModeActiveNode',
    hl_eol = true,  -- Highlight to end of line
  })
end

-- Clear active highlight from buffer
-- @param bufnr number: Buffer number
function M.clear_active_highlight(bufnr)
  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local ns = M.get_highlight_namespace()

  -- Clear all extmarks in this namespace for this buffer
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

-- Update winbar with node metadata
-- @param bufnr number: Buffer number
-- @param node_info table|nil: Node metadata with fields: type, node_id, lens
function M.update_winbar(bufnr, node_info)
  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Format winbar text
  local winbar_text = ''

  if node_info then
    local parts = {}

    if node_info.type then
      table.insert(parts, string.format("Type: %s", node_info.type))
    end

    if node_info.node_id then
      table.insert(parts, string.format("ID: %s", node_info.node_id))
    end

    if node_info.lens then
      table.insert(parts, string.format("Lens: %s", node_info.lens))
    end

    winbar_text = table.concat(parts, " | ")
  end

  -- Set winbar for all windows showing this buffer
  -- winbar is window-local, not buffer-local
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
      vim.api.nvim_win_set_option(win, 'winbar', winbar_text)
    end
  end
end

-- Update active node highlight and winbar based on cursor position
-- @param bufnr number: Buffer number
function M.update_active_node(bufnr)
  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local extmarks = require('lifemode.extmarks')

  -- Get cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1  -- Convert to 0-indexed

  -- Get span metadata at cursor line
  local span = extmarks.get_span_at_line(bufnr, line)

  if span then
    -- Highlight the span
    M.highlight_active_span(bufnr, span.span_start, span.span_end)

    -- Update winbar with span metadata
    -- Extract type from node_id if available (e.g., "task-123" -> "task")
    local node_type = span.type
    if not node_type and span.node_id then
      node_type = span.node_id:match("^([^%-]+)")
    end

    M.update_winbar(bufnr, {
      type = node_type,
      node_id = span.node_id,
      lens = span.lens,
    })
  else
    -- No span at cursor - clear highlight and winbar
    M.clear_active_highlight(bufnr)
    M.update_winbar(bufnr, nil)
  end
end

-- Set up cursor movement tracking for a buffer
-- @param bufnr number: Buffer number
function M.track_cursor_movement(bufnr)
  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Create autocmd group for this buffer
  local group = vim.api.nvim_create_augroup('LifeModeActiveNode_' .. bufnr, { clear = true })

  -- Track cursor movement
  vim.api.nvim_create_autocmd({'CursorMoved', 'CursorMovedI'}, {
    group = group,
    buffer = bufnr,
    callback = function()
      M.update_active_node(bufnr)
    end,
  })

  -- Initial update
  M.update_active_node(bufnr)
end

-- Reset state for testing
function M._reset_for_testing()
  highlight_namespace = nil
end

return M
