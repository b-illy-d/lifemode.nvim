-- Block ID management for LifeMode
-- Ensures tasks have stable UUIDs for references

local parser = require('lifemode.parser')
local uuid = require('lifemode.uuid')

local M = {}

--- Ensure all tasks in a buffer have IDs
--- Adds UUID v4 to tasks that don't have an ID
--- @param bufnr number Buffer handle
--- @return number Count of IDs added
function M.ensure_ids_in_buffer(bufnr)
  local blocks = parser.parse_buffer(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local ids_added = 0

  for _, block in ipairs(blocks) do
    -- Only process tasks (not headings or list items)
    if block.type == "task" and not block.id then
      -- Generate UUID and append to line
      local new_id = uuid.generate()
      local line_idx = block.line_num - 1  -- Convert to 0-indexed
      local old_line = lines[line_idx + 1]  -- lines is 1-indexed
      local new_line = old_line .. " ^" .. new_id

      -- Update buffer
      vim.api.nvim_buf_set_lines(bufnr, line_idx, line_idx + 1, false, { new_line })

      -- Update our local copy for subsequent iterations
      lines[line_idx + 1] = new_line

      ids_added = ids_added + 1
    end
  end

  return ids_added
end

return M
