local M = {}

local base = require('lifemode.views.base')
local lens = require('lifemode.lens')

local function get_today()
  return os.date('%Y-%m-%d')
end

local function get_week_end()
  return os.date('%Y-%m-%d', os.time() + 86400 * 7)
end

local function classify_due_date(due)
  if not due then return 'no_due' end

  local today = get_today()
  local week_end = get_week_end()

  if due < today then return 'overdue' end
  if due == today then return 'today' end
  if due <= week_end then return 'this_week' end
  return 'later'
end

local function get_all_todo_tasks(idx)
  if not idx or not idx.tasks_by_state or not idx.tasks_by_state.todo then
    return {}
  end

  local tasks = {}
  for _, node in ipairs(idx.tasks_by_state.todo) do
    table.insert(tasks, {
      node = node,
      file = node._file,
      id = node.id,
    })
  end

  return tasks
end

local function create_task_instance(ref)
  return {
    instance_id = base.next_id('tasks'),
    lens = 'task/brief',
    depth = 1,
    target_id = ref.id,
    node = ref.node,
    file = ref.file,
  }
end

local function create_group_instance(name, children, depth)
  return {
    instance_id = base.next_id('tasks'),
    lens = 'group/header',
    display = name,
    depth = depth or 0,
    collapsed = false,
    children = children,
  }
end

local function sort_by_priority(tasks_list)
  table.sort(tasks_list, function(a, b)
    local pa = a.node and a.node.priority
    local pb = b.node and b.node.priority
    if not pa and not pb then return false end
    if not pa then return false end
    if not pb then return true end
    return pa < pb
  end)
  return tasks_list
end

local function group_by_priority(tasks_list)
  local groups = { [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {}, none = {} }

  for _, ref in ipairs(tasks_list) do
    local priority = ref.node and ref.node.priority
    if priority and priority >= 1 and priority <= 5 then
      table.insert(groups[priority], ref)
    else
      table.insert(groups.none, ref)
    end
  end

  local result = {}
  for i = 1, 5 do
    if #groups[i] > 0 then
      local children = vim.tbl_map(create_task_instance, groups[i])
      table.insert(result, create_group_instance('Priority ' .. i, children, 0))
    end
  end

  if #groups.none > 0 then
    local children = vim.tbl_map(create_task_instance, groups.none)
    table.insert(result, create_group_instance('No Priority', children, 0))
  end

  return result
end

local function group_by_tag(tasks_list)
  local groups = {}
  local untagged = {}

  for _, ref in ipairs(tasks_list) do
    local tags = ref.node and ref.node.tags
    if tags and #tags > 0 then
      local first_tag = tags[1]
      groups[first_tag] = groups[first_tag] or {}
      table.insert(groups[first_tag], ref)
    else
      table.insert(untagged, ref)
    end
  end

  local tag_order = vim.tbl_keys(groups)
  table.sort(tag_order)

  local result = {}
  for _, tag in ipairs(tag_order) do
    local children = vim.tbl_map(create_task_instance, groups[tag])
    table.insert(result, create_group_instance('#' .. tag, children, 0))
  end

  if #untagged > 0 then
    local children = vim.tbl_map(create_task_instance, untagged)
    table.insert(result, create_group_instance('Untagged', children, 0))
  end

  return result
end

local function group_by_due_date(tasks_list)
  local groups = { overdue = {}, today = {}, this_week = {}, later = {}, no_due = {} }

  for _, ref in ipairs(tasks_list) do
    local due = ref.node and ref.node.due
    local category = classify_due_date(due)
    table.insert(groups[category], ref)
  end

  local category_names = {
    overdue = 'Overdue',
    today = 'Today',
    this_week = 'This Week',
    later = 'Later',
    no_due = 'No Due Date',
  }

  local result = {}
  for _, key in ipairs({'overdue', 'today', 'this_week', 'later', 'no_due'}) do
    if #groups[key] > 0 then
      local children = vim.tbl_map(create_task_instance, groups[key])
      table.insert(result, create_group_instance(category_names[key], children, 0))
    end
  end

  return result
end

local function apply_filter(tasks_list, filter)
  if not filter or vim.tbl_isempty(filter) then
    return tasks_list
  end

  local ok, query = pcall(require, 'lifemode.query')
  if not ok then return tasks_list end

  local nodes = vim.tbl_map(function(t) return t.node end, tasks_list)
  local matching_nodes = query.execute(filter, nodes)

  local node_set = {}
  for _, node in ipairs(matching_nodes) do
    node_set[node] = true
  end

  return vim.tbl_filter(function(t) return node_set[t.node] end, tasks_list)
end

function M.build_tree(idx, options)
  options = options or {}
  local grouping = options.grouping or 'by_due_date'

  local tasks_list = get_all_todo_tasks(idx)
  tasks_list = apply_filter(tasks_list, options.filter)
  sort_by_priority(tasks_list)

  local groupers = {
    by_priority = group_by_priority,
    by_tag = group_by_tag,
    by_due_date = group_by_due_date,
  }

  local grouper = groupers[grouping] or group_by_due_date
  return { root_instances = grouper(tasks_list), grouping = grouping }
end

local function render_task_instance(inst, current_line, output, options)
  local line_start = current_line
  local indent = base.get_indent(inst.depth, options.indent)

  local result = lens.render(inst.node, inst.lens)
  current_line = base.apply_lens_result(result, indent, current_line, output)

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

  return current_line
end

local function render_group_instance(inst, current_line, output, options)
  local line_start = current_line
  local indent = base.get_indent(inst.depth, options.indent)

  local display = inst.display or 'Group'
  local child_count = inst.children and #inst.children or 0
  local header_line = display .. ' (' .. child_count .. ')'

  table.insert(output.lines, indent .. header_line)
  table.insert(output.highlights, {
    line = current_line,
    col_start = #indent,
    col_end = #indent + #display,
    hl_group = 'LifeModeGroupHeader',
  })
  current_line = current_line + 1

  base.add_span(output, {
    line_start = line_start,
    line_end = current_line - 1,
    instance_id = inst.instance_id,
    instance = inst,
    depth = inst.depth,
    collapsed = inst.collapsed,
    lens = inst.lens,
  })

  if not inst.collapsed and inst.children then
    for _, child in ipairs(inst.children) do
      current_line = render_task_instance(child, current_line, output, options)
    end
  end

  return current_line
end

function M.render(tree, options)
  options = options or {}
  options.indent = options.indent or '  '

  local output = base.create_output()

  local current_line = 0
  for _, group in ipairs(tree.root_instances) do
    current_line = render_group_instance(group, current_line, output, options)
  end

  return output
end

function M._reset_counter()
  base.reset_counter()
end

return M
