local M = {}

function M.render(node, lens_name, params)
  if not node then
    error('node is required')
  end
  if not lens_name then
    error('lens_name is required')
  end

  if lens_name == 'task/brief' then
    return M._render_task_brief(node)
  elseif lens_name == 'node/raw' then
    return M._render_node_raw(node)
  elseif lens_name == 'heading/brief' then
    return M._render_heading_brief(node)
  else
    error('Unknown lens: ' .. lens_name)
  end
end

function M._render_task_brief(node)
  local state_icon = node.state == 'done' and '[x]' or '[ ]'
  local parts = {state_icon, node.text}

  if node.priority then
    table.insert(parts, '!' .. node.priority)
  end

  if node.due then
    table.insert(parts, '@due(' .. node.due .. ')')
  end

  local line = table.concat(parts, ' ')
  local highlights = {}

  if node.state == 'done' then
    table.insert(highlights, {
      line = 0,
      col_start = 0,
      col_end = #line,
      hl_group = 'LifeModeDone',
    })
  else
    if node.priority and (node.priority == 1 or node.priority == 2) then
      local priority_text = '!' .. node.priority
      local priority_start = line:find(priority_text, 1, true)
      if priority_start then
        table.insert(highlights, {
          line = 0,
          col_start = priority_start - 1,
          col_end = priority_start + #priority_text - 1,
          hl_group = 'LifeModePriorityHigh',
        })
      end
    elseif node.priority and (node.priority == 4 or node.priority == 5) then
      local priority_text = '!' .. node.priority
      local priority_start = line:find(priority_text, 1, true)
      if priority_start then
        table.insert(highlights, {
          line = 0,
          col_start = priority_start - 1,
          col_end = priority_start + #priority_text - 1,
          hl_group = 'LifeModePriorityLow',
        })
      end
    end

    if node.due then
      local due_text = '@due(' .. node.due .. ')'
      local due_start = line:find(due_text, 1, true)
      if due_start then
        table.insert(highlights, {
          line = 0,
          col_start = due_start - 1,
          col_end = due_start + #due_text - 1,
          hl_group = 'LifeModeDue',
        })
      end
    end
  end

  return {
    lines = {line},
    highlights = highlights,
  }
end

function M._render_node_raw(node)
  local line
  if node.type == 'heading' then
    local hashes = string.rep('#', node.level)
    line = hashes .. ' ' .. node.text
  elseif node.type == 'task' then
    local state_icon = node.state == 'done' and '[x]' or '[ ]'
    line = '- ' .. state_icon .. ' ' .. node.text
  elseif node.type == 'list_item' then
    line = '- ' .. node.text
  else
    line = node.text or ''
  end

  return {
    lines = {line},
    highlights = {},
  }
end

function M._render_heading_brief(node)
  local hashes = string.rep('#', node.level)
  local line = hashes .. ' ' .. node.text

  return {
    lines = {line},
    highlights = {
      {
        line = 0,
        col_start = 0,
        col_end = #line,
        hl_group = 'LifeModeHeading',
      },
    },
  }
end

function M.get_available_lenses(node_type)
  if node_type == 'task' then
    return {'task/brief', 'node/raw'}
  elseif node_type == 'heading' then
    return {'heading/brief', 'node/raw'}
  elseif node_type == 'list_item' then
    return {'node/raw'}
  else
    return {}
  end
end

return M
