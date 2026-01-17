local M = {}

local LENS_REGISTRY = {}

local function register(name, render_fn)
  LENS_REGISTRY[name] = render_fn
end

function M.render(node, lens_name, params)
  if not node then error('node is required') end
  if not lens_name then error('lens_name is required') end

  local renderer = LENS_REGISTRY[lens_name]
  if not renderer then error('Unknown lens: ' .. lens_name) end

  return renderer(node, params)
end

function M.get_available_lenses(node_type)
  local available = {
    task = {'task/brief', 'task/detail', 'node/raw'},
    heading = {'heading/brief', 'node/raw'},
    list_item = {'node/raw'},
    source = {'source/biblio', 'node/raw'},
    citation = {'citation/brief', 'node/raw'},
  }
  return available[node_type] or {}
end

function M.cycle(current, node_type, direction)
  direction = direction or 1
  local available = M.get_available_lenses(node_type)

  if #available == 0 then return current end

  local current_idx = 0
  for i, lens_name in ipairs(available) do
    if lens_name == current then
      current_idx = i
      break
    end
  end

  if current_idx == 0 then
    return available[1]
  end

  local next_idx = current_idx + direction
  if next_idx > #available then next_idx = 1 end
  if next_idx < 1 then next_idx = #available end

  return available[next_idx]
end

local function highlight_span(line, text, hl_group)
  local start_pos = line:find(text, 1, true)
  if not start_pos then return nil end

  return {
    line = 0,
    col_start = start_pos - 1,
    col_end = start_pos + #text - 1,
    hl_group = hl_group,
  }
end

local function full_line_highlight(line, hl_group)
  return {
    line = 0,
    col_start = 0,
    col_end = #line,
    hl_group = hl_group,
  }
end

register('task/brief', function(node)
  local checkbox = node.state == 'done' and '[x]' or '[ ]'
  local parts = {checkbox, node.text}

  if node.priority then table.insert(parts, '!' .. node.priority) end
  if node.due then table.insert(parts, '@due(' .. node.due .. ')') end

  local line = table.concat(parts, ' ')
  local highlights = {}

  if node.state == 'done' then
    table.insert(highlights, full_line_highlight(line, 'LifeModeDone'))
    return { lines = {line}, highlights = highlights }
  end

  if node.priority then
    local is_high = node.priority == 1 or node.priority == 2
    local is_low = node.priority == 4 or node.priority == 5
    local hl_group = is_high and 'LifeModePriorityHigh' or (is_low and 'LifeModePriorityLow' or nil)

    if hl_group then
      local hl = highlight_span(line, '!' .. node.priority, hl_group)
      if hl then table.insert(highlights, hl) end
    end
  end

  if node.due then
    local hl = highlight_span(line, '@due(' .. node.due .. ')', 'LifeModeDue')
    if hl then table.insert(highlights, hl) end
  end

  return { lines = {line}, highlights = highlights }
end)

register('task/detail', function(node)
  local checkbox = node.state == 'done' and '[x]' or '[ ]'
  local lines = {checkbox .. ' ' .. node.text}
  local highlights = {}

  if node.state == 'done' then
    table.insert(highlights, full_line_highlight(lines[1], 'LifeModeDone'))
  end

  local meta_parts = {}
  if node.priority then
    table.insert(meta_parts, '!' .. node.priority)
  end
  if node.due then
    table.insert(meta_parts, '@due(' .. node.due .. ')')
  end
  if node.tags and #node.tags > 0 then
    for _, tag in ipairs(node.tags) do
      table.insert(meta_parts, '#' .. tag)
    end
  end

  if #meta_parts > 0 then
    table.insert(lines, '  ' .. table.concat(meta_parts, ' '))
  end

  return { lines = lines, highlights = highlights }
end)

register('node/raw', function(node)
  local line
  if node.type == 'heading' then
    line = string.rep('#', node.level) .. ' ' .. node.text
  elseif node.type == 'task' then
    local checkbox = node.state == 'done' and '[x]' or '[ ]'
    line = '- ' .. checkbox .. ' ' .. node.text
  elseif node.type == 'list_item' then
    line = '- ' .. node.text
  else
    line = node.text or ''
  end

  return { lines = {line}, highlights = {} }
end)

register('heading/brief', function(node)
  local line = string.rep('#', node.level) .. ' ' .. node.text
  return {
    lines = {line},
    highlights = {full_line_highlight(line, 'LifeModeHeading')},
  }
end)

local function render_date_group(node, params, hl_group)
  local icon = (params and params.collapsed) and '▸' or '▾'
  local line = icon .. ' ' .. (node.display or node.date or 'Unknown')

  return {
    lines = {line},
    highlights = {full_line_highlight(line, hl_group)},
  }
end

register('date/year', function(node, params)
  return render_date_group(node, params, 'LifeModeDateYear')
end)

register('date/month', function(node, params)
  return render_date_group(node, params, 'LifeModeDateMonth')
end)

register('date/day', function(node, params)
  return render_date_group(node, params, 'LifeModeDateDay')
end)

register('source/biblio', function(node)
  local props = node.props or {}
  local parts = {}

  if props.author then
    table.insert(parts, props.author)
  end

  if props.year then
    table.insert(parts, '(' .. props.year .. ')')
  end

  if props.title then
    table.insert(parts, '"' .. props.title .. '"')
  end

  if props.kind then
    table.insert(parts, '[' .. props.kind .. ']')
  end

  local line = #parts > 0 and table.concat(parts, ' ') or (node.text or 'Source')
  return { lines = {line}, highlights = {} }
end)

register('citation/brief', function(node)
  local props = node.props or {}
  local parts = {'[cite]'}

  if props.source then
    table.insert(parts, props.source)
  end

  if props.pages then
    table.insert(parts, 'pp. ' .. props.pages)
  elseif props.locator then
    table.insert(parts, props.locator)
  end

  local line = table.concat(parts, ' ')
  return { lines = {line}, highlights = {} }
end)

return M
