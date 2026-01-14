-- LifeMode: Extmark-based span mapping
-- Tracks metadata for rendered blocks using Neovim extmarks

local M = {}

-- Namespace for LifeMode extmarks
local namespace = nil

-- Metadata storage: extmark_id -> metadata
-- Indexed by "bufnr:extmark_id" to handle multiple buffers
local metadata_store = {}

-- Get or create the LifeMode extmark namespace
function M.get_namespace()
  if not namespace then
    namespace = vim.api.nvim_create_namespace('lifemode')
  end
  return namespace
end

-- Set span metadata for a line range in a buffer
-- @param bufnr number: Buffer number
-- @param start_line number: Start line (0-indexed)
-- @param end_line number: End line (0-indexed, inclusive)
-- @param metadata table: Metadata table with fields:
--   - instance_id: unique instance identifier
--   - node_id: canonical node identifier
--   - lens: renderer choice (e.g., 'task/brief')
--   - span_start: start line of span
--   - span_end: end line of span
function M.set_span_metadata(bufnr, start_line, end_line, metadata)
  local ns = M.get_namespace()

  -- Clear any existing extmarks in this range first
  local existing = vim.api.nvim_buf_get_extmarks(
    bufnr,
    ns,
    {start_line, 0},
    {end_line, -1},
    {}
  )

  for _, mark in ipairs(existing) do
    local mark_id = mark[1]
    vim.api.nvim_buf_del_extmark(bufnr, ns, mark_id)
    -- Clean up metadata store
    metadata_store[bufnr .. ':' .. mark_id] = nil
  end

  -- Set extmark at start of span
  -- end_row is exclusive in nvim_buf_set_extmark, so add 1
  local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns, start_line, 0, {
    end_row = end_line + 1,
    end_col = 0,
  })

  -- Store metadata separately
  metadata_store[bufnr .. ':' .. mark_id] = metadata
end

-- Get span metadata at a specific line
-- @param bufnr number: Buffer number
-- @param line number: Line number (0-indexed)
-- @return table|nil: Metadata table if found, nil otherwise
function M.get_span_at_line(bufnr, line)
  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  -- Check if line is in range
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if line < 0 or line >= line_count then
    return nil
  end

  local ns = M.get_namespace()

  -- Get all extmarks in the buffer with details to check for overlaps
  -- We need to check from start of buffer to the target line + 1
  -- to catch extmarks that start before this line but cover it
  local marks = vim.api.nvim_buf_get_extmarks(
    bufnr,
    ns,
    {0, 0},
    {line, -1},
    {details = true, overlap = true}
  )

  -- Find the extmark that covers this line
  for _, mark in ipairs(marks) do
    local mark_id = mark[1]
    local start_row = mark[2]
    local details = mark[4]

    -- Check if this extmark spans over the target line
    if details and details.end_row then
      local end_row = details.end_row - 1 -- end_row is exclusive, convert to inclusive
      if start_row <= line and line <= end_row then
        local metadata = metadata_store[bufnr .. ':' .. mark_id]
        if metadata then
          return metadata
        end
      end
    end
  end

  return nil
end

-- Get span metadata at current cursor position
-- @return table|nil: Metadata table if found, nil otherwise
function M.get_span_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1 -- Convert to 0-indexed

  return M.get_span_at_line(bufnr, line)
end

-- Reset state for testing
function M._reset_for_testing()
  namespace = nil
  metadata_store = {}
end

return M
