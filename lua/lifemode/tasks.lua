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

--- Extract priority from task line
--- @param line string Task line text
--- @return number|nil Priority level (1-5) or nil if not present or invalid
function M.get_priority(line)
  -- Match !N where N is 1-5
  local priority_str = line:match("!([1-5])")
  if priority_str then
    return tonumber(priority_str)
  end
  return nil
end

--- Set or update priority in task line
--- @param line string Task line text
--- @param priority number|nil Priority level (1-5) or nil to remove
--- @return string Updated line text
function M.set_priority(line, priority)
  if priority == nil then
    -- Remove priority
    return line:gsub("!%d+%s*", "")
  end

  -- Check if priority already exists
  if line:match("!%d+") then
    -- Update existing priority
    return line:gsub("!%d+", "!" .. priority)
  else
    -- Add new priority
    -- If line has ID (^id), insert before it with space
    if line:match("%^[%w%-_]+%s*$") then
      return line:gsub("(%s+)(%^[%w%-_]+%s*)$", " !" .. priority .. "%1%2")
    else
      -- No ID, append at end
      return line .. " !" .. priority
    end
  end
end

--- Increment priority (toward !1)
--- @param bufnr number Buffer handle
--- @param node_id string Node ID
--- @return boolean True if successful, false if not found or not a task
function M.inc_priority(bufnr, node_id)
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
  local current_priority = M.get_priority(line)

  -- Determine new priority
  local new_priority
  if current_priority == nil then
    -- No priority, add !5 (lowest)
    new_priority = 5
  elseif current_priority > 1 then
    -- Increment toward !1
    new_priority = current_priority - 1
  else
    -- Already at !1, stay there
    new_priority = 1
  end

  -- Update the line
  local new_line = M.set_priority(line, new_priority)
  vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {new_line})

  return true
end

--- Decrement priority (toward !5)
--- @param bufnr number Buffer handle
--- @param node_id string Node ID
--- @return boolean True if successful, false if not found or not a task
function M.dec_priority(bufnr, node_id)
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
  local current_priority = M.get_priority(line)

  -- Determine new priority
  if current_priority == nil then
    -- No priority, do nothing
    return true
  elseif current_priority < 5 then
    -- Decrement toward !5
    local new_priority = current_priority + 1
    local new_line = M.set_priority(line, new_priority)
    vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {new_line})
  end
  -- Already at !5 or no priority, stay there (do nothing)

  return true
end

return M
