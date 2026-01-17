local M = {}

local files = require('lifemode.core.files')

local function get_node_location(node_id, idx)
  if not idx or not idx.node_locations then return nil end
  return idx.node_locations[node_id]
end

local function get_line_at(loc)
  local lines = files.read_lines(loc.file)
  if not lines then return nil, nil end
  local line_num = loc.line + 1
  local line = lines[line_num]
  if not line then return nil, nil end
  return lines, line_num
end

function M.generate_id()
  local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return template:gsub('[xy]', function(c)
    local v = (c == 'x') and math.random(0, 15) or math.random(8, 11)
    return string.format('%x', v)
  end)
end

function M.ensure_id(file, line_idx)
  local lines = files.read_lines(file)
  if not lines then return nil end

  local line_num = line_idx + 1
  local line = lines[line_num]
  if not line then return nil end

  local existing = line:match('%^([%w%-_:]+)%s*$')
  if existing then return existing end

  local new_id = M.generate_id()
  lines[line_num] = line .. ' ^' .. new_id
  files.write_lines(file, lines)

  return new_id
end

function M.toggle_task_state(node_id, idx)
  local loc = get_node_location(node_id, idx)
  if not loc then return nil end

  local lines, line_num = get_line_at(loc)
  if not lines then return nil end

  local line = lines[line_num]
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
  files.write_lines(loc.file, lines)

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

local function compute_new_priority(current, direction)
  if direction > 0 then
    if not current then return 3 end
    return math.max(1, current - 1)
  else
    if not current then return nil end
    if current >= 5 then return nil end
    return current + 1
  end
end

local function change_priority(node_id, idx, direction)
  local loc = get_node_location(node_id, idx)
  if not loc then return nil end

  local lines, line_num = get_line_at(loc)
  if not lines then return nil end

  local line = lines[line_num]
  local current = extract_priority(line)

  if direction < 0 and not current then return nil end

  local new_priority = compute_new_priority(current, direction)
  lines[line_num] = replace_priority(line, current, new_priority)
  files.write_lines(loc.file, lines)

  return new_priority
end

function M.inc_priority(node_id, idx)
  return change_priority(node_id, idx, 1)
end

function M.dec_priority(node_id, idx)
  return change_priority(node_id, idx, -1)
end

local function is_valid_date(date)
  return date and date:match('^%d%d%d%d%-%d%d%-%d%d$') ~= nil
end

function M.set_due(node_id, date, idx)
  if not is_valid_date(date) then return nil end

  local loc = get_node_location(node_id, idx)
  if not loc then return nil end

  local lines, line_num = get_line_at(loc)
  if not lines then return nil end

  local line = lines[line_num]
  local new_line

  if line:match('@due%([^)]+%)') then
    new_line = line:gsub('@due%([^)]+%)', '@due(' .. date .. ')')
  else
    local checkbox_end = line:find('%]') + 1
    new_line = line:sub(1, checkbox_end) .. ' @due(' .. date .. ')' .. line:sub(checkbox_end + 1)
  end

  lines[line_num] = new_line
  files.write_lines(loc.file, lines)

  return date
end

function M.clear_due(node_id, idx)
  local loc = get_node_location(node_id, idx)
  if not loc then return false end

  local lines, line_num = get_line_at(loc)
  if not lines then return false end

  local line = lines[line_num]
  if not line:match('@due%([^)]+%)') then return false end

  lines[line_num] = line:gsub('%s*@due%([^)]+%)', '')
  files.write_lines(loc.file, lines)

  return true
end

local function escape_pattern(str)
  return str:gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]', '%%%1')
end

local function has_tag(line, tag)
  local escaped = escape_pattern(tag)
  return line:match('#' .. escaped .. '$') or line:match('#' .. escaped .. '[^%w_/%-]')
end

function M.add_tag(node_id, tag, idx)
  local loc = get_node_location(node_id, idx)
  if not loc then return false end

  local lines, line_num = get_line_at(loc)
  if not lines then return false end

  local line = lines[line_num]
  if has_tag(line, tag) then return false end

  local new_line
  if line:match('%s*%^[%w%-_:]+%s*$') then
    new_line = line:gsub('%s*(%^[%w%-_:]+)%s*$', ' #' .. tag .. ' %1')
  else
    new_line = line .. ' #' .. tag
  end

  lines[line_num] = new_line
  files.write_lines(loc.file, lines)

  return true
end

function M.remove_tag(node_id, tag, idx)
  local loc = get_node_location(node_id, idx)
  if not loc then return false end

  local lines, line_num = get_line_at(loc)
  if not lines then return false end

  local line = lines[line_num]
  if not has_tag(line, tag) then return false end

  lines[line_num] = line:gsub('%s*#' .. escape_pattern(tag), '')
  files.write_lines(loc.file, lines)

  return true
end

return M
