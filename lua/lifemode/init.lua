local M = {}

local config = require('lifemode.config')
local navigation = require('lifemode.navigation')

local state = {
  config = nil,
  initialized = false,
  current_view = nil,
}

local function require_setup()
  if not state.config then
    vim.notify('LifeMode not configured. Run require("lifemode").setup()', vim.log.levels.ERROR)
    return false
  end
  return true
end

local function register_commands()
  vim.api.nvim_create_user_command('LifeModeHello', function() M.hello() end, {})
  vim.api.nvim_create_user_command('LifeMode', function(opts)
    local view_type = opts.args and opts.args ~= '' and opts.args or 'daily'
    M.open_view(view_type)
  end, { nargs = '?' })
  vim.api.nvim_create_user_command('LifeModeDebugSpan', function() M.debug_span() end, {})
  vim.api.nvim_create_user_command('LifeModeParse', function() M.parse_current_buffer() end, {})
end

function M.setup(opts)
  if state.initialized then
    error('setup() already called - duplicate setup not allowed')
  end

  state.config = config.validate(opts or {})
  register_commands()
  state.initialized = true
end

function M.get_config()
  return state.config
end

function M._reset_state()
  state.config = nil
  state.initialized = false
  state.current_view = nil
end

function M.hello()
  if not require_setup() then return end

  local lines = {'LifeMode Configuration:', '----------------------'}
  for key, value in pairs(state.config) do
    table.insert(lines, string.format('  %s: %s', key, vim.inspect(value)))
  end
  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end

function M.open_view(view_type)
  if not require_setup() then return end
  view_type = view_type or 'daily'

  local index = require('lifemode.index')
  local view = require('lifemode.view')

  local idx = index.get_or_build(state.config.vault_root)
  local tree, rendered

  if view_type == 'tasks' then
    local tasks_view = require('lifemode.views.tasks')
    tree = tasks_view.build_tree(idx, state.config)
    rendered = tasks_view.render(tree, { index = idx })
  else
    local daily = require('lifemode.views.daily')
    tree = daily.build_tree(idx, state.config)
    rendered = daily.render(tree, { index = idx })
  end

  local bufnr = view.create_buffer()
  M._apply_rendered_content(bufnr, rendered)

  state.current_view = {
    bufnr = bufnr,
    tree = tree,
    index = idx,
    spans = rendered.spans,
    view_type = view_type,
  }

  M._setup_keymaps(bufnr)
  vim.api.nvim_win_set_buf(0, bufnr)

  if view_type == 'daily' then
    local daily = require('lifemode.views.daily')
    local today_line = daily.find_today_line(rendered.spans)
    if today_line > 0 then
      vim.api.nvim_win_set_cursor(0, {today_line + 1, 0})
    end
  end
end

function M._apply_rendered_content(bufnr, rendered)
  local extmarks = require('lifemode.extmarks')
  local ns = extmarks.create_namespace()

  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].readonly = false
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, rendered.lines)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  for _, span in ipairs(rendered.spans) do
    extmarks.set_instance_span(bufnr, span.line_start, span.line_end, span)
  end

  for _, hl in ipairs(rendered.highlights) do
    pcall(vim.api.nvim_buf_add_highlight, bufnr, ns, hl.hl_group, hl.line, hl.col_start, hl.col_end)
  end

  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
end

function M._refresh_view()
  local cv = state.current_view
  if not cv then return end

  local daily = require('lifemode.views.daily')
  local rendered = daily.render(cv.tree, { index = cv.index })

  M._apply_rendered_content(cv.bufnr, rendered)
  cv.spans = rendered.spans
end

function M._setup_keymaps(bufnr)
  local opts = { buffer = bufnr, silent = true }
  local refresh = function() M._refresh_view() end
  local cv = function() return state.current_view end

  vim.keymap.set('n', '<Space>e', function() navigation.expand_at_cursor(cv(), refresh) end, opts)
  vim.keymap.set('n', '<Space>E', function() navigation.collapse_at_cursor(cv(), refresh) end, opts)
  vim.keymap.set('n', ']d', function() navigation.jump(cv(), 'date/day', 1, refresh) end, opts)
  vim.keymap.set('n', '[d', function() navigation.jump(cv(), 'date/day', -1, refresh) end, opts)
  vim.keymap.set('n', ']m', function() navigation.jump(cv(), 'date/month', 1, refresh) end, opts)
  vim.keymap.set('n', '[m', function() navigation.jump(cv(), 'date/month', -1, refresh) end, opts)
  vim.keymap.set('n', 'gd', function() M._jump_to_source() end, opts)
  vim.keymap.set('n', '<CR>', function() M._jump_to_source() end, opts)
  vim.keymap.set('n', '<Space><Space>', function() M._toggle_task() end, opts)
  vim.keymap.set('n', '<Space>tp', function() M._inc_priority() end, opts)
  vim.keymap.set('n', '<Space>tP', function() M._dec_priority() end, opts)
  vim.keymap.set('n', '<Space>g', function() M._cycle_grouping() end, opts)
  vim.keymap.set('n', 'gr', function() M._backlinks_at_cursor() end, opts)
  vim.keymap.set('n', 'q', function() vim.cmd('bdelete') end, opts)
end

function M._get_current_view()
  return state.current_view
end

function M._get_last_view_bufnr()
  return state.last_view_bufnr
end

function M._return_to_view()
  if not state.last_view_bufnr then return end
  if not vim.api.nvim_buf_is_valid(state.last_view_bufnr) then
    state.last_view_bufnr = nil
    return
  end
  vim.api.nvim_set_current_buf(state.last_view_bufnr)
end

function M._expand_at_cursor()
  navigation.expand_at_cursor(state.current_view, function() M._refresh_view() end)
end

function M._collapse_at_cursor()
  navigation.collapse_at_cursor(state.current_view, function() M._refresh_view() end)
end

function M._jump_day(direction)
  navigation.jump(state.current_view, 'date/day', direction, function() M._refresh_view() end)
end

function M._jump_month(direction)
  navigation.jump(state.current_view, 'date/month', direction, function() M._refresh_view() end)
end

local function get_task_node_id()
  local extmarks = require('lifemode.extmarks')
  local metadata = extmarks.get_instance_at_cursor()

  if not metadata then return nil end
  if metadata.lens and metadata.lens:match('^date/') then return nil end

  local node = metadata.node
  if not node or node.type ~= 'task' then return nil end

  return metadata.target_id or (node and node.id)
end

local function refresh_after_patch()
  local index = require('lifemode.index')
  local daily = require('lifemode.views.daily')
  local cv = state.current_view
  if not cv then return end

  index._reset_state()
  local idx = index.get_or_build(state.config.vault_root)
  local tree = daily.build_tree(idx, state.config)

  cv.index = idx
  cv.tree = tree

  M._refresh_view()
end

function M._toggle_task()
  local patch = require('lifemode.patch')

  local node_id = get_task_node_id()
  if not node_id then return end

  local cv = state.current_view
  if not cv then return end

  local new_state = patch.toggle_task_state(node_id, cv.index)
  if not new_state then return end

  refresh_after_patch()
end

function M._inc_priority()
  local patch = require('lifemode.patch')

  local node_id = get_task_node_id()
  if not node_id then return end

  local cv = state.current_view
  if not cv then return end

  patch.inc_priority(node_id, cv.index)
  refresh_after_patch()
end

function M._dec_priority()
  local patch = require('lifemode.patch')

  local node_id = get_task_node_id()
  if not node_id then return end

  local cv = state.current_view
  if not cv then return end

  patch.dec_priority(node_id, cv.index)
  refresh_after_patch()
end

local GROUPING_CYCLE = {'by_due_date', 'by_priority', 'by_tag'}

function M._cycle_grouping()
  local cv = state.current_view
  if not cv then return end
  if cv.view_type ~= 'tasks' then return end

  local current = cv.tree and cv.tree.grouping or 'by_due_date'
  local next_idx = 1
  for i, g in ipairs(GROUPING_CYCLE) do
    if g == current then
      next_idx = (i % #GROUPING_CYCLE) + 1
      break
    end
  end

  local new_grouping = GROUPING_CYCLE[next_idx]
  local tasks_view = require('lifemode.views.tasks')

  local tree = tasks_view.build_tree(cv.index, { grouping = new_grouping })
  local rendered = tasks_view.render(tree, { index = cv.index })

  cv.tree = tree
  M._apply_rendered_content(cv.bufnr, rendered)
  cv.spans = rendered.spans
end

function M._jump_to_source()
  local extmarks = require('lifemode.extmarks')
  local metadata = extmarks.get_instance_at_cursor()

  if not metadata then return end
  if metadata.lens and metadata.lens:match('^date/') then return end

  local file = metadata.file
  local line = metadata.node and metadata.node.line

  if not file then
    if metadata.target_id and state.current_view and state.current_view.index then
      local loc = state.current_view.index.node_locations[metadata.target_id]
      if loc then
        file = loc.file
        line = loc.line
      end
    end
  end

  if not file then return end

  state.last_view_bufnr = vim.api.nvim_get_current_buf()
  vim.cmd('edit ' .. vim.fn.fnameescape(file))
  if line then
    vim.api.nvim_win_set_cursor(0, {line + 1, 0})
  end
end

function M._show_backlinks(target)
  if not require_setup() then return end
  if not target then return end

  local index = require('lifemode.index')
  local cv = state.current_view

  local idx = cv and cv.index
  local backlinks = index.get_backlinks(target, idx)

  if #backlinks == 0 then
    vim.notify('No backlinks found for: ' .. target, vim.log.levels.INFO)
    return
  end

  local qf_items = {}
  for _, link in ipairs(backlinks) do
    table.insert(qf_items, {
      filename = link.file,
      lnum = (link.line or 0) + 1,
      text = 'References: ' .. target,
    })
  end

  vim.fn.setqflist(qf_items)
  vim.cmd('copen')
end

function M._backlinks_at_cursor()
  local extmarks = require('lifemode.extmarks')
  local metadata = extmarks.get_instance_at_cursor()

  if not metadata then return end
  if metadata.lens and metadata.lens:match('^date/') then return end

  local node = metadata.node
  if not node then return end

  local target = node.text or node.id
  if not target then return end

  M._show_backlinks(target)
end

function M.debug_span()
  if not require_setup() then return end

  local extmarks = require('lifemode.extmarks')
  local metadata = extmarks.get_instance_at_cursor()

  if not metadata then
    vim.notify('No instance metadata at cursor', vim.log.levels.WARN)
    return
  end

  local lines = {'Instance Metadata:', '=================='}
  for key, value in pairs(metadata) do
    table.insert(lines, string.format('  %s: %s', key, vim.inspect(value)))
  end
  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end

function M.parse_current_buffer()
  if not require_setup() then return end

  local parser = require('lifemode.parser')
  local bufnr = vim.api.nvim_get_current_buf()
  local blocks = parser.parse_buffer(bufnr)

  local task_count = 0
  for _, block in ipairs(blocks) do
    if block.type == 'task' then task_count = task_count + 1 end
  end

  vim.notify(string.format('Parsed %d blocks (%d tasks)', #blocks, task_count), vim.log.levels.INFO)
end

return M
