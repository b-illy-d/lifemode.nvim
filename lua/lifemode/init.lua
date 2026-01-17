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
  vim.api.nvim_create_user_command('LifeMode', function() M.open_view() end, {})
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

function M.open_view()
  if not require_setup() then return end

  local index = require('lifemode.index')
  local daily = require('lifemode.views.daily')
  local view = require('lifemode.view')
  local extmarks = require('lifemode.extmarks')

  local idx = index.get_or_build(state.config.vault_root)
  local tree = daily.build_tree(idx, state.config)
  local rendered = daily.render(tree, { index = idx })

  local bufnr = view.create_buffer()
  M._apply_rendered_content(bufnr, rendered)

  state.current_view = {
    bufnr = bufnr,
    tree = tree,
    index = idx,
    spans = rendered.spans,
  }

  M._setup_keymaps(bufnr)
  vim.api.nvim_win_set_buf(0, bufnr)

  local today_line = daily.find_today_line(rendered.spans)
  if today_line > 0 then
    vim.api.nvim_win_set_cursor(0, {today_line + 1, 0})
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
