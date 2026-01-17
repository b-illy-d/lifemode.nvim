local M = {}

local config = require('lifemode.config')

local state = {
  config = nil,
  initialized = false,
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
  require('lifemode.controller')._reset_state()
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
  local controller = require('lifemode.controller')

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
  view.apply_rendered_content(bufnr, rendered)

  controller.set_current_view({
    bufnr = bufnr,
    tree = tree,
    index = idx,
    spans = rendered.spans,
    view_type = view_type,
  })

  controller.setup_keymaps(bufnr, state.config)
  vim.api.nvim_win_set_buf(0, bufnr)

  if view_type == 'daily' then
    local daily = require('lifemode.views.daily')
    local today_line = daily.find_today_line(rendered.spans)
    if today_line > 0 then
      vim.api.nvim_win_set_cursor(0, {today_line + 1, 0})
    end
  end
end

function M._get_current_view()
  return require('lifemode.controller').get_current_view()
end

function M._get_last_view_bufnr()
  return require('lifemode.controller').get_last_view_bufnr()
end

function M._return_to_view()
  require('lifemode.controller').return_to_view()
end

function M._refresh_view()
  require('lifemode.controller').refresh_view(state.config)
end

function M._setup_keymaps(bufnr)
  require('lifemode.controller').setup_keymaps(bufnr, state.config)
end

function M._apply_rendered_content(bufnr, rendered)
  require('lifemode.view').apply_rendered_content(bufnr, rendered)
end

function M._update_active_node()
  require('lifemode.controller').update_active_node()
end

function M.get_statusline_info()
  return require('lifemode.controller').get_statusline_info()
end

function M._expand_at_cursor()
  require('lifemode.controller').expand_at_cursor(state.config)
end

function M._collapse_at_cursor()
  require('lifemode.controller').collapse_at_cursor(state.config)
end

function M._jump_day(direction)
  require('lifemode.controller').jump_day(direction, state.config)
end

function M._jump_month(direction)
  require('lifemode.controller').jump_month(direction, state.config)
end

function M._toggle_task()
  require('lifemode.controller').toggle_task(state.config)
end

function M._inc_priority()
  require('lifemode.controller').inc_priority(state.config)
end

function M._dec_priority()
  require('lifemode.controller').dec_priority(state.config)
end

function M._jump_to_source()
  require('lifemode.controller').jump_to_source()
end

function M._show_backlinks(target)
  if not require_setup() then return end
  local controller = require('lifemode.controller')
  local cv = controller.get_current_view()
  local index = require('lifemode.index')
  local backlinks = index.get_backlinks(target, cv and cv.index)

  if #backlinks == 0 then
    vim.notify('No backlinks found for: ' .. target, vim.log.levels.INFO)
    return
  end

  local qf_items = vim.tbl_map(function(link)
    return {
      filename = link.file,
      lnum = (link.line or 0) + 1,
      text = 'References: ' .. target,
    }
  end, backlinks)

  vim.fn.setqflist(qf_items)
  vim.cmd('copen')
end

function M._backlinks_at_cursor()
  require('lifemode.controller').backlinks_at_cursor()
end

function M._cycle_lens_at_cursor(direction)
  require('lifemode.controller').cycle_lens_at_cursor(direction, state.config)
end

function M._cycle_grouping()
  require('lifemode.controller').cycle_grouping(state.config)
end

function M._show_bible_backlinks(verse_id)
  if not require_setup() then return end
  M._show_backlinks(verse_id)
end

function M._bible_backlinks_at_cursor()
  if not require_setup() then return end
  require('lifemode.controller').bible_backlinks_at_cursor(state.config)
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
