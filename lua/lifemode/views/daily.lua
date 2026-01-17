local M = {}

local dates = require('lifemode.core.dates')
local lens = require('lifemode.lens')

local instance_counter = 0

local function next_instance_id()
  instance_counter = instance_counter + 1
  return 'inst_' .. instance_counter
end

local function create_leaf_instance(ref)
  return {
    instance_id = next_instance_id(),
    lens = 'task/brief',
    depth = 3,
    target_id = ref.id,
    node = ref.node,
    file = ref.file,
  }
end

local function create_day_instance(day, refs, is_today, expanded_depth)
  return {
    instance_id = next_instance_id(),
    lens = 'date/day',
    date = day,
    depth = 2,
    collapsed = not is_today or expanded_depth < 3,
    children = vim.tbl_map(create_leaf_instance, refs),
    display = dates.format_day(day),
  }
end

local function create_month_instance(month, days_data, today_parts, expanded_depth)
  local is_today_month = month == today_parts.month
  local children = {}

  for _, day in ipairs(days_data.day_order) do
    local is_today = day == today_parts.day
    table.insert(children, create_day_instance(day, days_data.days[day], is_today, expanded_depth))
  end

  return {
    instance_id = next_instance_id(),
    lens = 'date/month',
    date = month,
    depth = 1,
    collapsed = not is_today_month or expanded_depth < 2,
    children = children,
    display = dates.format_month(month),
  }
end

local function create_year_instance(year, year_data, today_parts, expanded_depth)
  local is_today_year = year == today_parts.year
  local children = {}

  for _, month in ipairs(year_data.month_order) do
    table.insert(children, create_month_instance(month, year_data.months[month], today_parts, expanded_depth))
  end

  return {
    instance_id = next_instance_id(),
    lens = 'date/year',
    date = year,
    depth = 0,
    collapsed = not is_today_year or expanded_depth < 1,
    children = children,
    display = year,
  }
end

local function group_nodes_by_date(nodes_by_date)
  local years = {}
  local year_order = {}

  for date_str, node_refs in pairs(nodes_by_date) do
    local parts = dates.parse(date_str)
    if not parts or #node_refs == 0 then goto continue end

    if not years[parts.year] then
      years[parts.year] = { months = {}, month_order = {} }
      table.insert(year_order, parts.year)
    end

    local year_data = years[parts.year]
    if not year_data.months[parts.month] then
      year_data.months[parts.month] = { days = {}, day_order = {} }
      table.insert(year_data.month_order, parts.month)
    end

    local month_data = year_data.months[parts.month]
    if not month_data.days[parts.day] then
      month_data.days[parts.day] = {}
      table.insert(month_data.day_order, parts.day)
    end

    for _, ref in ipairs(node_refs) do
      table.insert(month_data.days[parts.day], ref)
    end

    ::continue::
  end

  return years, year_order
end

local function sort_date_hierarchy(years, year_order)
  dates.sort_descending(year_order)

  for _, year in ipairs(year_order) do
    dates.sort_descending(years[year].month_order)
    for _, month in ipairs(years[year].month_order) do
      dates.sort_descending(years[year].months[month].day_order)
    end
  end
end

function M.build_tree(idx, config)
  config = config or {}
  local expanded_depth = config.daily_view_expanded_depth or 3
  local today = dates.today()
  local today_parts = dates.parse(today) or { year = today:sub(1, 4), month = today:sub(1, 7), day = today }

  local years, year_order = group_nodes_by_date(idx.nodes_by_date)
  sort_date_hierarchy(years, year_order)

  local root_instances = {}
  for _, year in ipairs(year_order) do
    table.insert(root_instances, create_year_instance(year, years[year], today_parts, expanded_depth))
  end

  return { root_instances = root_instances }
end

local function resolve_node(leaf, index)
  if leaf.node then return leaf.node end
  if not leaf.target_id or not index then return nil end

  local loc = index.node_locations[leaf.target_id]
  if not loc then return nil end

  return { id = leaf.target_id, file = loc.file, line = loc.line }
end

local function select_lens_for_node(node, default_lens)
  if node.type == 'heading' then return 'heading/brief' end
  if node.type == 'task' then return 'task/brief' end
  if node.type then return 'node/raw' end
  return default_lens
end

local function render_date_instance(inst, indent, current_line, output)
  local result = lens.render(inst, inst.lens, { collapsed = inst.collapsed })

  for _, content_line in ipairs(result.lines) do
    table.insert(output.lines, indent .. content_line)
    for _, hl in ipairs(result.highlights) do
      table.insert(output.highlights, {
        line = current_line,
        col_start = #indent + hl.col_start,
        col_end = #indent + hl.col_end,
        hl_group = hl.hl_group,
      })
    end
    current_line = current_line + 1
  end

  return current_line
end

local function render_leaf_instance(inst, indent, current_line, output, index)
  local node = resolve_node(inst, index)

  if not node then
    table.insert(output.lines, indent .. '(unknown node)')
    return current_line + 1
  end

  local node_lens = select_lens_for_node(node, inst.lens)
  local result = lens.render(node, node_lens)

  for _, content_line in ipairs(result.lines) do
    table.insert(output.lines, indent .. content_line)
    for _, hl in ipairs(result.highlights) do
      table.insert(output.highlights, {
        line = current_line,
        col_start = #indent + hl.col_start,
        col_end = #indent + hl.col_end,
        hl_group = hl.hl_group,
      })
    end
    current_line = current_line + 1
  end

  return current_line
end

local function render_instance(inst, current_line, output, options)
  local line_start = current_line
  local indent = string.rep(options.indent, inst.depth)
  local is_date = inst.lens:match('^date/')

  if is_date then
    current_line = render_date_instance(inst, indent, current_line, output)

    table.insert(output.spans, {
      line_start = line_start,
      line_end = current_line - 1,
      instance_id = inst.instance_id,
      instance = inst,
      depth = inst.depth,
      collapsed = inst.collapsed,
      lens = inst.lens,
      date = inst.date,
    })

    if not inst.collapsed and inst.children then
      for _, child in ipairs(inst.children) do
        current_line = render_instance(child, current_line, output, options)
      end
    end
  else
    current_line = render_leaf_instance(inst, indent, current_line, output, options.index)

    table.insert(output.spans, {
      line_start = line_start,
      line_end = current_line - 1,
      instance_id = inst.instance_id,
      instance = inst,
      depth = inst.depth,
      target_id = inst.target_id,
      node = inst.node,
      file = inst.file,
      lens = inst.lens,
    })
  end

  return current_line
end

function M.render(tree, options)
  options = options or {}
  options.indent = options.indent or '  '

  local output = { lines = {}, spans = {}, highlights = {} }

  local current_line = 0
  for _, root in ipairs(tree.root_instances) do
    current_line = render_instance(root, current_line, output, options)
  end

  return output
end

function M.find_instance_by_id(tree, instance_id)
  local function search(instances)
    for _, inst in ipairs(instances) do
      if inst.instance_id == instance_id then return inst end
      if inst.children then
        local found = search(inst.children)
        if found then return found end
      end
    end
    return nil
  end
  return search(tree.root_instances)
end

function M.find_today_line(spans)
  local today = dates.today()
  for _, span in ipairs(spans) do
    if span.date == today then return span.line_start end
  end
  return 0
end

function M._reset_counter()
  instance_counter = 0
end

return M
