local M = {}

local base = require('lifemode.views.base')
local dates = require('lifemode.core.dates')
local lens = require('lifemode.lens')

local function create_leaf_instance(node)
  local node_lens = 'node/brief'
  if node.type == 'task' then
    node_lens = 'task/brief'
  elseif node.type == 'quote' then
    node_lens = 'quote/brief'
  elseif node.type == 'source' then
    node_lens = 'source/biblio'
  elseif node.type == 'project' then
    node_lens = 'project/brief'
  end

  return {
    instance_id = base.next_id('daily'),
    lens = node_lens,
    depth = 3,
    target_id = node.id,
    node = node,
    file = node._file,
  }
end

local function create_day_instance(day, nodes, is_today, expanded_depth)
  return {
    instance_id = base.next_id('daily'),
    lens = 'date/day',
    date = day,
    depth = 2,
    collapsed = not is_today or expanded_depth < 3,
    children = vim.tbl_map(create_leaf_instance, nodes),
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
    instance_id = base.next_id('daily'),
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
    instance_id = base.next_id('daily'),
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

  for date_str, nodes in pairs(nodes_by_date) do
    local parts = dates.parse(date_str)
    if not parts or #nodes == 0 then goto continue end

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

    for _, node in ipairs(nodes) do
      table.insert(month_data.days[parts.day], node)
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

local function render_date_instance(inst, indent, current_line, output)
  local result = lens.render(inst, inst.lens, { collapsed = inst.collapsed })
  return base.apply_lens_result(result, indent, current_line, output)
end

local function render_leaf_instance(inst, indent, current_line, output)
  local node = inst.node

  if not node then
    table.insert(output.lines, indent .. '(unknown node)')
    return current_line + 1
  end

  local result = lens.render(node, inst.lens)
  return base.apply_lens_result(result, indent, current_line, output)
end

local function render_instance(inst, current_line, output, options)
  local line_start = current_line
  local indent = base.get_indent(inst.depth, options.indent)
  local is_date = inst.lens:match('^date/')

  if is_date then
    current_line = render_date_instance(inst, indent, current_line, output)

    base.add_span(output, {
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
    current_line = render_leaf_instance(inst, indent, current_line, output)

    base.add_span(output, {
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

  local output = base.create_output()

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
  base.reset_counter()
end

return M
