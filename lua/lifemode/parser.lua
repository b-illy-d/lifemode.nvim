local M = {}

function M.parse_buffer(bufnr)
  if bufnr == 0 or not bufnr then
    error('Invalid buffer number')
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = {}

  for line_idx, line in ipairs(lines) do
    local block = M._parse_line(line, line_idx - 1)
    if block then
      table.insert(blocks, block)
    end
  end

  return blocks
end

function M.parse_file(path)
  if not path or path == '' then
    error('path is required')
  end

  local lines = vim.fn.readfile(path)
  local blocks = {}

  for line_idx, line in ipairs(lines) do
    local block = M._parse_line(line, line_idx - 1)
    if block then
      table.insert(blocks, block)
    end
  end

  return blocks
end

function M._parse_line(line, line_idx)
  local heading_match = line:match('^(#+)%s+(.*)$')
  if heading_match then
    return M._parse_heading(line, line_idx)
  end

  local task_match = line:match('^%s*%-%s+%[([%sxX])%]%s+(.*)$')
  if task_match then
    return M._parse_task(line, line_idx)
  end

  local list_match = line:match('^%s*%-%s+(.*)$')
  if list_match then
    return M._parse_list_item(line, line_idx)
  end

  return nil
end

function M._parse_heading(line, line_idx)
  local hashes, rest = line:match('^(#+)%s+(.*)$')
  local level = #hashes
  local text, id = M._extract_id(rest)

  return {
    type = 'heading',
    line = line_idx,
    level = level,
    text = text,
    id = id,
  }
end

function M._parse_task(line, line_idx)
  local state_char, rest = line:match('^%s*%-%s+%[([%sxX])%]%s+(.*)$')
  local state = (state_char == 'x' or state_char == 'X') and 'done' or 'todo'
  local text, id = M._extract_id(rest)

  local priority = M._extract_priority(text)
  local due = M._extract_due(text)
  local tags = M._extract_tags(text)

  text = M._strip_metadata(text)

  return {
    type = 'task',
    line = line_idx,
    state = state,
    text = text,
    id = id,
    priority = priority,
    due = due,
    tags = tags,
  }
end

function M._parse_list_item(line, line_idx)
  local rest = line:match('^%s*%-%s+(.*)$')
  local text, id = M._extract_id(rest)

  return {
    type = 'list_item',
    line = line_idx,
    text = text,
    id = id,
  }
end

function M._extract_id(text)
  local before_id, id = text:match('^(.-)%s*%^([%w%-:]+)%s*$')
  if before_id and id then
    return vim.trim(before_id), id
  end
  return vim.trim(text), nil
end

function M._extract_priority(text)
  local priorities = {}

  for i = 1, #text do
    local char = text:sub(i, i)
    if char == '!' then
      local digit = text:sub(i+1, i+1)
      if digit:match('[1-5]') then
        local after = i + 2 <= #text and text:sub(i+2, i+2) or ' '
        if not after:match('%w') then
          table.insert(priorities, tonumber(digit))
        end
      end
    end
  end

  if #priorities > 0 then
    return priorities[#priorities]
  end
  return nil
end

function M._extract_due(text)
  local due = text:match('@due%((%d%d%d%d%-%d%d%-%d%d)%)')
  return due
end

function M._extract_tags(text)
  local tags = {}
  local seen = {}

  for i = 1, #text do
    local char = text:sub(i, i)
    if char == '#' then
      local before = i > 1 and text:sub(i-1, i-1) or ' '
      if before:match('[%s%p]') or before == '' then
        local tag_match = text:sub(i+1):match('^([%w_/%-]+)')
        if tag_match and not tag_match:match('^[%d]+$') and not seen[tag_match] then
          table.insert(tags, tag_match)
          seen[tag_match] = true
        end
      end
    end
  end

  if #tags > 0 then
    return tags
  end
  return nil
end

function M._strip_metadata(text)
  text = text:gsub('!%d+%s*', '')
  text = text:gsub('@due%([^)]+%)%s*', '')
  text = text:gsub('%s*#[%w_/%-]+', '')
  text = vim.trim(text)
  text = text:gsub('%s+', ' ')
  return text
end

return M
