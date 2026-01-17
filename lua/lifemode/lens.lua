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
    task = {'task/brief', 'node/raw'},
    heading = {'heading/brief', 'node/raw'},
    list_item = {'node/raw'},
  }
  return available[node_type] or {}
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

return M
