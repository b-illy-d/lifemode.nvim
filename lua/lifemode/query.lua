-- Task query and filtering system for LifeMode
-- Provides filtering by state, tags, and due date

local node = require('lifemode.node')
local parser = require('lifemode.parser')
local tasks = require('lifemode.tasks')

local M = {}

--- Get all tasks from the vault
--- @return table Array of {node_id, file, line, text, state, tags, due, priority}
function M.get_all_tasks()
  local lifemode = require('lifemode')
  local config = lifemode.get_config()

  if not config.vault_index or not config.vault_index.node_locations then
    return {}
  end

  local all_tasks = {}
  local index = config.vault_index

  -- Iterate through all nodes in the index
  for node_id, location in pairs(index.node_locations) do
    local file_path = location.file
    local line_num = location.line

    -- Read the line from file
    local file = io.open(file_path, "r")
    if file then
      local current_line = 0
      for line_text in file:lines() do
        current_line = current_line + 1
        if current_line == line_num then
          -- Check if this is a task line
          if line_text:match("^%s*%-%s*%[.%]") then
            -- Parse task properties
            local state = line_text:match("%[([%sxX])%]")
            state = (state and state:lower() == "x") and "done" or "todo"

            -- Extract tags
            local tags = {}
            for tag in line_text:gmatch("#([%w/%-_]+)") do
              table.insert(tags, tag)
            end

            -- Extract due date
            local due = line_text:match("@due%(([%d%-]+)%)")

            -- Extract priority
            local priority = tasks.get_priority(line_text)

            table.insert(all_tasks, {
              node_id = node_id,
              file = file_path,
              line = line_num,
              text = line_text,
              state = state,
              tags = tags,
              due = due,
              priority = priority,
            })
          end
          break
        end
      end
      file:close()
    end
  end

  return all_tasks
end

--- Filter tasks by criteria
--- @param tasks_list table Array of tasks from get_all_tasks()
--- @param filters table Filter criteria: {state, tag, due}
--- @return table Filtered array of tasks
function M.filter_tasks(tasks_list, filters)
  local filtered = {}

  for _, task in ipairs(tasks_list) do
    local matches = true

    -- Filter by state
    if filters.state and task.state ~= filters.state then
      matches = false
    end

    -- Filter by tag
    if matches and filters.tag then
      local has_tag = false
      for _, tag in ipairs(task.tags) do
        if tag == filters.tag or tag:match("^" .. vim.pesc(filters.tag)) then
          has_tag = true
          break
        end
      end
      if not has_tag then
        matches = false
      end
    end

    -- Filter by due date
    if matches and filters.due then
      if filters.due == "today" then
        -- Check if due date is today
        local today = os.date("%Y-%m-%d")
        if task.due ~= today then
          matches = false
        end
      elseif filters.due == "overdue" then
        -- Check if due date is in the past
        local today = os.date("%Y-%m-%d")
        if not task.due or task.due >= today then
          matches = false
        end
      elseif filters.due == "upcoming" then
        -- Check if due date is in the future
        local today = os.date("%Y-%m-%d")
        if not task.due or task.due <= today then
          matches = false
        end
      end
    end

    if matches then
      table.insert(filtered, task)
    end
  end

  return filtered
end

--- Convert tasks to quickfix list format
--- @param tasks_list table Array of tasks
--- @return table Quickfix list entries
function M.tasks_to_quickfix(tasks_list)
  local qf_list = {}

  for _, task in ipairs(tasks_list) do
    -- Format text with state indicator and metadata
    local display_text = task.text

    -- Strip ID for cleaner display
    display_text = display_text:gsub("%s*%^[%w%-_]+%s*$", "")

    table.insert(qf_list, {
      filename = task.file,
      lnum = task.line,
      col = 1,
      text = display_text,
      type = task.state == "todo" and "W" or "I",
    })
  end

  return qf_list
end

--- Show tasks in quickfix list
--- @param tasks_list table Array of tasks
--- @param title string Title for the quickfix list
function M.show_tasks_quickfix(tasks_list, title)
  local qf_list = M.tasks_to_quickfix(tasks_list)

  if #qf_list == 0 then
    vim.api.nvim_echo({{string.format("No tasks found for: %s", title), "WarningMsg"}}, true, {})
    return
  end

  -- Set quickfix list with title
  vim.fn.setqflist(qf_list, 'r')
  vim.fn.setqflist({}, 'a', {title = title})

  -- Open quickfix window
  vim.cmd('copen')

  vim.api.nvim_echo({{string.format("Found %d task(s)", #qf_list), "Normal"}}, false, {})
end

--- Get tasks due today
--- @return table Array of tasks
function M.get_tasks_today()
  local all_tasks = M.get_all_tasks()
  return M.filter_tasks(all_tasks, {
    state = "todo",
    due = "today",
  })
end

--- Get tasks by tag
--- @param tag string Tag to filter by
--- @return table Array of tasks
function M.get_tasks_by_tag(tag)
  local all_tasks = M.get_all_tasks()
  return M.filter_tasks(all_tasks, {
    state = "todo",
    tag = tag,
  })
end

--- Get all todo tasks
--- @return table Array of tasks
function M.get_all_todo_tasks()
  local all_tasks = M.get_all_tasks()
  return M.filter_tasks(all_tasks, {
    state = "todo",
  })
end

--- Get overdue tasks
--- @return table Array of tasks
function M.get_overdue_tasks()
  local all_tasks = M.get_all_tasks()
  return M.filter_tasks(all_tasks, {
    state = "todo",
    due = "overdue",
  })
end

return M
