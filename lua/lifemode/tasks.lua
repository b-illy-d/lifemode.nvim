-- Task state management for LifeMode
-- Provides functions to toggle task state ([ ] ↔ [x])

local parser = require('lifemode.parser')

local M = {}

--- Toggle task state between [ ] and [x]
--- @param bufnr number Buffer handle
--- @param node_id string Node ID to toggle
--- @return boolean True if toggled successfully, false if not found or not a task
function M.toggle_task_state(bufnr, node_id)
  -- Parse buffer to find the task
  local blocks = parser.parse_buffer(bufnr)

  -- Find the block with matching ID
  local target_block = nil
  for _, block in ipairs(blocks) do
    if block.id == node_id then
      if block.type == "task" then
        target_block = block
        break
      else
        -- Found node but it's not a task
        return false
      end
    end
  end

  if not target_block then
    -- Node not found
    return false
  end

  -- Get the line content
  local line_num = target_block.line_num
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
  if #lines == 0 then
    return false
  end

  local line = lines[1]

  -- Toggle the checkbox state
  local new_line
  if line:match("%[ %]") then
    -- Toggle todo to done
    new_line = line:gsub("%[ %]", "[x]", 1)
  elseif line:match("%[x%]") or line:match("%[X%]") then
    -- Toggle done to todo (handle both [x] and [X])
    new_line = line:gsub("%[[xX]%]", "[ ]", 1)
  else
    -- No checkbox found, shouldn't happen but handle gracefully
    return false
  end

  -- Update the buffer
  vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {new_line})

  return true
end

--- Get task at cursor position
--- @return string|nil node_id Node ID if cursor is on a task, nil otherwise
--- @return number|nil bufnr Buffer handle if task found
function M.get_task_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]  -- 1-indexed

  -- Parse buffer
  local blocks = parser.parse_buffer(bufnr)

  -- Find block at cursor line
  for _, block in ipairs(blocks) do
    if block.line_num == row and block.type == "task" and block.id then
      return block.id, bufnr
    end
  end

  return nil
end

return M
