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

--- Extract all tags from a line
--- @param line string Line text to extract tags from
--- @return table Array of tag strings (without # prefix)
function M.get_tags(line)
  local tags = {}
  -- Pattern: #([%w_/-]+) matches #tag or #tag/subtag
  -- Allows word chars, underscore, slash, and hyphen
  for tag in line:gmatch("#([%w_/-]+)") do
    table.insert(tags, tag)
  end
  return tags
end

--- Add a tag to a task
--- @param bufnr number Buffer handle
--- @param node_id string Node ID
--- @param tag string Tag to add (without # prefix)
--- @return boolean True if successful, false if not found or not a task
function M.add_tag(bufnr, node_id, tag)
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

  -- Check if tag already exists
  local existing_tags = M.get_tags(line)
  for _, existing_tag in ipairs(existing_tags) do
    if existing_tag == tag then
      -- Tag already present, do nothing
      return true
    end
  end

  -- Add tag before ^id if present, otherwise at end
  local new_line
  if line:match("%^[%w%-_]+%s*$") then
    -- Insert tag before ID
    new_line = line:gsub("(%s*)(%^[%w%-_]+%s*)$", " #" .. tag .. "%1%2")
  else
    -- No ID, append at end
    new_line = line .. " #" .. tag
  end

  -- Update the buffer
  vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {new_line})

  return true
end

--- Remove a tag from a task
--- @param bufnr number Buffer handle
--- @param node_id string Node ID
--- @param tag string Tag to remove (without # prefix)
--- @return boolean True if successful, false if not found or not a task
function M.remove_tag(bufnr, node_id, tag)
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

  -- Remove the tag
  -- Pattern: #tag_to_remove with surrounding spaces
  local escaped_tag = tag:gsub("([%-%.%+%[%]%(%)%$%^%%%?%*])", "%%%1")

  -- Try to match tag with space before it first (most common case)
  local new_line = line:gsub("%s#" .. escaped_tag .. "(%s*)", "%1")

  -- If that didn't work, try without leading space (tag at start of content)
  if new_line == line then
    new_line = line:gsub("#" .. escaped_tag .. "%s*", "")
  end

  -- Clean up any double spaces that might result
  new_line = new_line:gsub("%s%s+", " ")

  -- Update the buffer
  vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {new_line})

  return true
end

--- Interactive add tag - prompts user for tag and adds it to task at cursor
function M.add_tag_interactive()
  -- Get task at cursor
  local node_id, bufnr = M.get_task_at_cursor()

  if not node_id then
    vim.api.nvim_echo({{'No task at cursor', 'WarningMsg'}}, true, {})
    return
  end

  -- Get existing tags to show user
  local blocks = parser.parse_buffer(bufnr)
  local current_tags = {}
  for _, block in ipairs(blocks) do
    if block.id == node_id then
      local lines = vim.api.nvim_buf_get_lines(bufnr, block.line_num - 1, block.line_num, false)
      if #lines > 0 then
        current_tags = M.get_tags(lines[1])
      end
      break
    end
  end

  -- Prompt for tag
  local prompt = 'Add tag'
  if #current_tags > 0 then
    prompt = prompt .. ' (current: ' .. table.concat(current_tags, ', ') .. ')'
  end
  prompt = prompt .. ': '

  local tag = vim.fn.input(prompt)

  -- Clean up input - remove # prefix if user included it
  tag = tag:gsub('^#', ''):match('^%s*(.-)%s*$')  -- trim whitespace

  if tag == '' then
    vim.api.nvim_echo({{'Tag cannot be empty', 'WarningMsg'}}, true, {})
    return
  end

  -- Add tag
  local success = M.add_tag(bufnr, node_id, tag)

  if success then
    vim.api.nvim_echo({{'Added tag #' .. tag, 'Normal'}}, true, {})
  else
    vim.api.nvim_echo({{'Failed to add tag', 'ErrorMsg'}}, true, {})
  end
end

--- Interactive remove tag - prompts user for tag and removes it from task at cursor
function M.remove_tag_interactive()
  -- Get task at cursor
  local node_id, bufnr = M.get_task_at_cursor()

  if not node_id then
    vim.api.nvim_echo({{'No task at cursor', 'WarningMsg'}}, true, {})
    return
  end

  -- Get existing tags
  local blocks = parser.parse_buffer(bufnr)
  local current_tags = {}
  for _, block in ipairs(blocks) do
    if block.id == node_id then
      local lines = vim.api.nvim_buf_get_lines(bufnr, block.line_num - 1, block.line_num, false)
      if #lines > 0 then
        current_tags = M.get_tags(lines[1])
      end
      break
    end
  end

  if #current_tags == 0 then
    vim.api.nvim_echo({{'Task has no tags to remove', 'WarningMsg'}}, true, {})
    return
  end

  -- Prompt for tag
  local prompt = 'Remove tag (current: ' .. table.concat(current_tags, ', ') .. '): '
  local tag = vim.fn.input(prompt)

  -- Clean up input - remove # prefix if user included it
  tag = tag:gsub('^#', ''):match('^%s*(.-)%s*$')  -- trim whitespace

  if tag == '' then
    vim.api.nvim_echo({{'Tag cannot be empty', 'WarningMsg'}}, true, {})
    return
  end

  -- Remove tag
  local success = M.remove_tag(bufnr, node_id, tag)

  if success then
    vim.api.nvim_echo({{'Removed tag #' .. tag, 'Normal'}}, true, {})
  else
    vim.api.nvim_echo({{'Failed to remove tag', 'ErrorMsg'}}, true, {})
  end
end

--- Extract due date from task line
--- @param line string Line text to extract due date from
--- @return string|nil Due date (YYYY-MM-DD) or nil if not present or invalid format
function M.get_due(line)
  -- Pattern: @due(YYYY-MM-DD) - strict format with 4-digit year, 2-digit month/day
  local due_date = line:match("@due%((%d%d%d%d%-%d%d%-%d%d)%)")
  return due_date
end

--- Set or clear due date in task line
--- @param line string Task line text
--- @param date string|nil Due date (YYYY-MM-DD) or nil/empty to remove
--- @return string Updated line text
function M.set_due(line, date)
  -- Handle nil or empty string as removal
  if not date or date == '' then
    -- Remove due date
    local new_line = line:gsub("%s*@due%(%d%d%d%d%-%d%d%-%d%d%)%s*", " ")
    -- Clean up double spaces
    new_line = new_line:gsub("%s%s+", " ")
    -- Clean up trailing space before ID
    new_line = new_line:gsub("%s+(%^[%w%-_]+%s*)$", " %1")
    -- Clean up trailing space at end
    new_line = new_line:gsub("%s+$", "")
    return new_line
  end

  -- Check if due already exists
  if line:match("@due%(%d%d%d%d%-%d%d%-%d%d%)") then
    -- Update existing due
    return line:gsub("@due%(%d%d%d%d%-%d%d%-%d%d%)", "@due(" .. date .. ")")
  else
    -- Add new due
    -- If line has ID (^id), insert before it
    if line:match("%^[%w%-_]+%s*$") then
      return line:gsub("(%s*)(%^[%w%-_]+%s*)$", " @due(" .. date .. ")%1%2")
    else
      -- No ID, append at end
      return line .. " @due(" .. date .. ")"
    end
  end
end

--- Set due date on a task in buffer
--- @param bufnr number Buffer handle
--- @param node_id string Node ID
--- @param date string Due date (YYYY-MM-DD format)
--- @return boolean True if successful, false if not found/not a task/invalid format
function M.set_due_buffer(bufnr, node_id, date)
  -- Validate date format
  if not date:match("^%d%d%d%d%-%d%d%-%d%d$") then
    return false
  end

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

  -- Update the line
  local new_line = M.set_due(line, date)
  vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {new_line})

  return true
end

--- Clear due date from a task in buffer
--- @param bufnr number Buffer handle
--- @param node_id string Node ID
--- @return boolean True if successful, false if not found/not a task
function M.clear_due_buffer(bufnr, node_id)
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

  -- Update the line
  local new_line = M.set_due(line, nil)
  vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {new_line})

  return true
end

--- Interactive set due date - prompts user for date and sets it on task at cursor
function M.set_due_interactive()
  -- Get task at cursor
  local node_id, bufnr = M.get_task_at_cursor()

  if not node_id then
    vim.api.nvim_echo({{'No task at cursor', 'WarningMsg'}}, true, {})
    return
  end

  -- Get current due date if exists
  local blocks = parser.parse_buffer(bufnr)
  local current_due = nil
  for _, block in ipairs(blocks) do
    if block.id == node_id then
      local lines = vim.api.nvim_buf_get_lines(bufnr, block.line_num - 1, block.line_num, false)
      if #lines > 0 then
        current_due = M.get_due(lines[1])
      end
      break
    end
  end

  -- Prompt for date with current date as default
  local prompt = 'Set due date (YYYY-MM-DD)'
  if current_due then
    prompt = prompt .. ' [current: ' .. current_due .. ']'
  end
  prompt = prompt .. ': '

  local date = vim.fn.input(prompt, current_due or '')

  -- Trim whitespace
  date = date:match('^%s*(.-)%s*$')

  if date == '' then
    vim.api.nvim_echo({{'Date cannot be empty', 'WarningMsg'}}, true, {})
    return
  end

  -- Validate format
  if not date:match('^%d%d%d%d%-%d%d%-%d%d$') then
    vim.api.nvim_echo({{'Invalid date format. Use YYYY-MM-DD', 'ErrorMsg'}}, true, {})
    return
  end

  -- Set due date
  local success = M.set_due_buffer(bufnr, node_id, date)

  if success then
    vim.api.nvim_echo({{'Set due date to ' .. date, 'Normal'}}, true, {})
  else
    vim.api.nvim_echo({{'Failed to set due date', 'ErrorMsg'}}, true, {})
  end
end

--- Interactive clear due date - clears due date from task at cursor
function M.clear_due_interactive()
  -- Get task at cursor
  local node_id, bufnr = M.get_task_at_cursor()

  if not node_id then
    vim.api.nvim_echo({{'No task at cursor', 'WarningMsg'}}, true, {})
    return
  end

  -- Clear due date
  local success = M.clear_due_buffer(bufnr, node_id)

  if success then
    vim.api.nvim_echo({{'Cleared due date', 'Normal'}}, true, {})
  else
    vim.api.nvim_echo({{'Failed to clear due date', 'ErrorMsg'}}, true, {})
  end
end

return M
