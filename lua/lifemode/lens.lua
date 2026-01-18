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
    note = {'node/brief', 'node/full', 'node/raw'},
    quote = {'quote/brief', 'quote/full', 'node/raw'},
    source = {'source/biblio', 'node/raw'},
    citation = {'citation/brief', 'node/raw'},
    project = {'project/brief', 'project/expanded', 'node/raw'},
    heading = {'heading/brief', 'node/raw'},
    list_item = {'node/raw'},
  }
  return available[node_type] or {'node/brief', 'node/raw'}
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

local function extract_title_from_content(content)
  if not content then return nil end
  local title = content:match('^#%s+([^\n]+)')
  return title
end

local function extract_first_line(content)
  if not content then return nil end
  for line in content:gmatch('[^\n]+') do
    local trimmed = vim.trim(line)
    if trimmed ~= '' and not trimmed:match('^#') then
      if #trimmed > 60 then
        return trimmed:sub(1, 57) .. '...'
      end
      return trimmed
    end
  end
  return nil
end

register('task/brief', function(node)
  local checkbox = node.state == 'done' and '[x]' or '[ ]'
  local parts = {checkbox, node.text or ''}

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
  local lines = {checkbox .. ' ' .. (node.text or '')}
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

register('node/brief', function(node)
  local title = extract_title_from_content(node.content)
  local first_line = extract_first_line(node.content)
  local display = title or first_line or node.id or 'Note'

  local line = '📝 ' .. display
  return { lines = {line}, highlights = {} }
end)

register('node/full', function(node)
  local lines = {}

  if node.content then
    for line in (node.content .. '\n'):gmatch('([^\n]*)\n') do
      table.insert(lines, line)
    end
  else
    table.insert(lines, '(empty note)')
  end

  return { lines = lines, highlights = {} }
end)

register('node/raw', function(node)
  local lines = {}

  for key, value in pairs(node.props or {}) do
    table.insert(lines, key .. ':: ' .. tostring(value))
  end

  if #lines > 0 then
    table.insert(lines, '')
  end

  if node.content then
    for line in (node.content .. '\n'):gmatch('([^\n]*)\n') do
      table.insert(lines, line)
    end
  end

  if #lines == 0 then
    lines = {'(empty)'}
  end

  return { lines = lines, highlights = {} }
end)

register('quote/brief', function(node)
  local quote_text = node.content or ''
  local first_line = quote_text:match('^"?([^\n"]+)')
  if first_line then
    if #first_line > 50 then
      first_line = first_line:sub(1, 47) .. '...'
    end
    first_line = '"' .. first_line .. '"'
  else
    first_line = '"..."'
  end

  local author = node.props and node.props.author
  local line = first_line
  if author then
    line = line .. ' —' .. author
  end

  return {
    lines = {line},
    highlights = {full_line_highlight(line, 'LifeModeQuote')},
  }
end)

register('quote/full', function(node)
  local lines = {}
  local quote_text = node.content or ''

  table.insert(lines, quote_text)

  local author = node.props and node.props.author
  local source = node.props and node.props.source
  if author or source then
    local attribution = '— ' .. (author or '')
    if source then
      attribution = attribution .. ', ' .. source
    end
    table.insert(lines, attribution)
  end

  return { lines = lines, highlights = {} }
end)

register('project/brief', function(node)
  local title = node.props and node.props.title or node.id or 'Project'
  local ref_count = node.references and #node.references or 0

  local line = '📁 ' .. title .. ' (' .. ref_count .. ' items)'
  return {
    lines = {line},
    highlights = {full_line_highlight(line, 'LifeModeProject')},
  }
end)

register('project/expanded', function(node, params)
  local lines = {}
  local title = node.props and node.props.title or node.id or 'Project'

  table.insert(lines, '📁 ' .. title)
  table.insert(lines, '')

  if node.references then
    for i, ref in ipairs(node.references) do
      table.insert(lines, '  ' .. i .. '. [[' .. ref .. ']]')
    end
  end

  return { lines = lines, highlights = {} }
end)

register('heading/brief', function(node)
  local level = node.level or 1
  local line = string.rep('#', level) .. ' ' .. (node.text or '')
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
