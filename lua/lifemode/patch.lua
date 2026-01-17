local M = {}

local function get_node_location(node_id, idx)
  if not idx or not idx.node_locations then return nil end
  return idx.node_locations[node_id]
end

local function read_file_lines(path)
  local lines = vim.fn.readfile(path)
  if not lines or #lines == 0 then return nil end
  return lines
end

local function write_file_lines(path, lines)
  vim.fn.writefile(lines, path)
end

function M.toggle_task_state(node_id, idx)
  local loc = get_node_location(node_id, idx)
  if not loc then return nil end

  local lines = read_file_lines(loc.file)
  if not lines then return nil end

  local line_num = loc.line + 1
  local line = lines[line_num]
  if not line then return nil end

  local new_line, new_state
  if line:match('%- %[ %]') then
    new_line = line:gsub('%- %[ %]', '- [x]', 1)
    new_state = 'done'
  elseif line:match('%- %[x%]') or line:match('%- %[X%]') then
    new_line = line:gsub('%- %[[xX]%]', '- [ ]', 1)
    new_state = 'todo'
  else
    return nil
  end

  lines[line_num] = new_line
  write_file_lines(loc.file, lines)

  return new_state
end

local function extract_priority(line)
  local priority = line:match('!([1-5])')
  return priority and tonumber(priority) or nil
end

local function replace_priority(line, old_priority, new_priority)
  if old_priority and new_priority then
    return line:gsub('!' .. old_priority, '!' .. new_priority, 1)
  elseif old_priority and not new_priority then
    return line:gsub('%s*!' .. old_priority, '', 1)
  elseif not old_priority and new_priority then
    local checkbox_end = line:find('%]') + 1
    return line:sub(1, checkbox_end) .. ' !' .. new_priority .. line:sub(checkbox_end + 1)
  end
  return line
end

function M.inc_priority(node_id, idx)
  local loc = get_node_location(node_id, idx)
  if not loc then return nil end

  local lines = read_file_lines(loc.file)
  if not lines then return nil end

  local line_num = loc.line + 1
  local line = lines[line_num]
  if not line then return nil end

  local current = extract_priority(line)
  local new_priority

  if not current then
    new_priority = 3
  elseif current > 1 then
    new_priority = current - 1
  else
    new_priority = 1
  end

  lines[line_num] = replace_priority(line, current, new_priority)
  write_file_lines(loc.file, lines)

  return new_priority
end

function M.dec_priority(node_id, idx)
  local loc = get_node_location(node_id, idx)
  if not loc then return nil end

  local lines = read_file_lines(loc.file)
  if not lines then return nil end

  local line_num = loc.line + 1
  local line = lines[line_num]
  if not line then return nil end

  local current = extract_priority(line)
  local new_priority

  if not current then
    return nil
  elseif current < 5 then
    new_priority = current + 1
  else
    new_priority = nil
  end

  lines[line_num] = replace_priority(line, current, new_priority)
  write_file_lines(loc.file, lines)

  return new_priority
end

local function validate_date(date)
  if not date then return false end
  return date:match('^%d%d%d%d%-%d%d%-%d%d$') ~= nil
end

function M.set_due(node_id, date, idx)
  if not validate_date(date) then return nil end

  local loc = get_node_location(node_id, idx)
  if not loc then return nil end

  local lines = read_file_lines(loc.file)
  if not lines then return nil end

  local line_num = loc.line + 1
  local line = lines[line_num]
  if not line then return nil end

  local new_line
  if line:match('@due%([^)]+%)') then
    new_line = line:gsub('@due%([^)]+%)', '@due(' .. date .. ')')
  else
    local checkbox_end = line:find('%]') + 1
    new_line = line:sub(1, checkbox_end) .. ' @due(' .. date .. ')' .. line:sub(checkbox_end + 1)
  end

  lines[line_num] = new_line
  write_file_lines(loc.file, lines)

  return date
end

function M.clear_due(node_id, idx)
  local loc = get_node_location(node_id, idx)
  if not loc then return false end

  local lines = read_file_lines(loc.file)
  if not lines then return false end

  local line_num = loc.line + 1
  local line = lines[line_num]
  if not line then return false end

  if not line:match('@due%([^)]+%)') then
    return false
  end

  local new_line = line:gsub('%s*@due%([^)]+%)', '')
  lines[line_num] = new_line
  write_file_lines(loc.file, lines)

  return true
end

local function escape_pattern(str)
  return str:gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]', '%%%1')
end

local function has_tag(line, tag)
  local pattern = '#' .. escape_pattern(tag) .. '([^%w_/%-]|$)'
  if line:match('#' .. escape_pattern(tag) .. '$') then return true end
  if line:match('#' .. escape_pattern(tag) .. '[^%w_/%-]') then return true end
  return false
end

function M.add_tag(node_id, tag, idx)
  local loc = get_node_location(node_id, idx)
  if not loc then return false end

  local lines = read_file_lines(loc.file)
  if not lines then return false end

  local line_num = loc.line + 1
  local line = lines[line_num]
  if not line then return false end

  if has_tag(line, tag) then
    return false
  end

  local id_match = line:match('%s*%^[%w%-_:]+%s*$')
  local new_line
  if id_match then
    new_line = line:gsub('%s*(%^[%w%-_:]+)%s*$', ' #' .. tag .. ' %1')
  else
    new_line = line .. ' #' .. tag
  end

  lines[line_num] = new_line
  write_file_lines(loc.file, lines)

  return true
end

function M.remove_tag(node_id, tag, idx)
  local loc = get_node_location(node_id, idx)
  if not loc then return false end

  local lines = read_file_lines(loc.file)
  if not lines then return false end

  local line_num = loc.line + 1
  local line = lines[line_num]
  if not line then return false end

  if not has_tag(line, tag) then
    return false
  end

  local new_line = line:gsub('%s*#' .. escape_pattern(tag), '')
  lines[line_num] = new_line
  write_file_lines(loc.file, lines)

  return true
end

return M
