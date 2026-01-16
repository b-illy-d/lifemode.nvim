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

  return {
    type = 'task',
    line = line_idx,
    state = state,
    text = text,
    id = id,
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

return M
