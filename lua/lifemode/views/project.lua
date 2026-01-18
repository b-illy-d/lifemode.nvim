local M = {}

local base = require('lifemode.views.base')
local lens = require('lifemode.lens')

local function select_lens_for_node(node)
  local node_type = node.type or 'note'
  if node_type == 'task' then return 'task/brief' end
  if node_type == 'quote' then return 'quote/brief' end
  if node_type == 'source' then return 'source/biblio' end
  if node_type == 'project' then return 'project/brief' end
  return 'node/brief'
end

local function create_node_instance(node, depth)
  return {
    instance_id = base.next_id('project'),
    lens = select_lens_for_node(node),
    depth = depth,
    target_id = node.id,
    node = node,
    file = node._file,
  }
end

local function create_project_header(project)
  local title = project.props and project.props.title or project.id or 'Project'
  return {
    instance_id = base.next_id('project'),
    lens = 'project/header',
    depth = 0,
    target_id = project.id,
    node = project,
    file = project._file,
    display = title,
    collapsed = false,
  }
end

function M.build_tree(project_node, idx)
  if not project_node then
    return { root_instances = {} }
  end

  local header = create_project_header(project_node)
  local children = {}

  if project_node.references then
    for _, ref_id in ipairs(project_node.references) do
      local referenced_node = idx.nodes[ref_id]
      if referenced_node then
        table.insert(children, create_node_instance(referenced_node, 1))
      else
        table.insert(children, {
          instance_id = base.next_id('project'),
          lens = 'missing/ref',
          depth = 1,
          target_id = ref_id,
          display = '[[' .. ref_id .. ']] (not found)',
        })
      end
    end
  end

  header.children = children
  return { root_instances = {header}, project = project_node }
end

local function render_header_instance(inst, current_line, output, options)
  local line_start = current_line
  local indent = base.get_indent(inst.depth, options.indent)

  local icon = inst.collapsed and '▸' or '▾'
  local line = icon .. ' 📁 ' .. inst.display

  table.insert(output.lines, indent .. line)
  table.insert(output.highlights, {
    line = current_line,
    col_start = #indent,
    col_end = #indent + #line,
    hl_group = 'LifeModeProject',
  })
  current_line = current_line + 1

  base.add_span(output, {
    line_start = line_start,
    line_end = current_line - 1,
    instance_id = inst.instance_id,
    instance = inst,
    depth = inst.depth,
    collapsed = inst.collapsed,
    target_id = inst.target_id,
    node = inst.node,
    file = inst.file,
    lens = inst.lens,
  })

  if not inst.collapsed and inst.children then
    for _, child in ipairs(inst.children) do
      current_line = render_node_instance(child, current_line, output, options)
    end
  end

  return current_line
end

function render_node_instance(inst, current_line, output, options)
  local line_start = current_line
  local indent = base.get_indent(inst.depth, options.indent)

  if inst.lens == 'missing/ref' then
    local line = inst.display or '(missing)'
    table.insert(output.lines, indent .. line)
    table.insert(output.highlights, {
      line = current_line,
      col_start = #indent,
      col_end = #indent + #line,
      hl_group = 'LifeModeMissing',
    })
    current_line = current_line + 1
  elseif inst.node then
    local result = lens.render(inst.node, inst.lens)
    current_line = base.apply_lens_result(result, indent, current_line, output)
  else
    table.insert(output.lines, indent .. '(unknown node)')
    current_line = current_line + 1
  end

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

function M.render(tree, options)
  options = options or {}
  options.indent = options.indent or '  '

  local output = base.create_output()
  local current_line = 0

  for _, root in ipairs(tree.root_instances) do
    if root.lens == 'project/header' then
      current_line = render_header_instance(root, current_line, output, options)
    else
      current_line = render_node_instance(root, current_line, output, options)
    end
  end

  return output
end

function M._reset_counter()
  base.reset_counter()
end

return M
