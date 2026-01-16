local M = {}

local default_config = {
  leader = '<Space>',
  max_depth = 10,
  max_nodes_per_action = 100,
  bible_version = 'ESV',
  default_view = 'daily',
  daily_view_expanded_depth = 3,
  tasks_default_grouping = 'due_date',
  auto_index_on_startup = false,
}

local state = {
  config = nil,
  initialized = false,
}

function M.setup(opts)
  opts = opts or {}

  if state.initialized then
    error('setup() already called - duplicate setup not allowed')
  end

  if not opts.vault_root or opts.vault_root == '' then
    error('vault_root is required')
  end

  if type(opts.vault_root) ~= 'string' then
    error('vault_root must be a string')
  end

  if vim.trim(opts.vault_root) == '' then
    error('vault_root cannot be whitespace only')
  end

  state.config = vim.tbl_deep_extend('force', default_config, opts)

  if type(state.config.leader) ~= 'string' then
    error('leader must be a string')
  end

  if type(state.config.max_depth) ~= 'number' or state.config.max_depth <= 0 then
    error('max_depth must be a positive number')
  end

  if type(state.config.max_nodes_per_action) ~= 'number' or state.config.max_nodes_per_action <= 0 then
    error('max_nodes_per_action must be a positive number')
  end

  if type(state.config.bible_version) ~= 'string' then
    error('bible_version must be a string')
  end

  if type(state.config.default_view) ~= 'string' then
    error('default_view must be a string')
  end

  if type(state.config.daily_view_expanded_depth) ~= 'number' or state.config.daily_view_expanded_depth < 0 then
    error('daily_view_expanded_depth must be a non-negative number')
  end

  if type(state.config.tasks_default_grouping) ~= 'string' then
    error('tasks_default_grouping must be a string')
  end

  if type(state.config.auto_index_on_startup) ~= 'boolean' then
    error('auto_index_on_startup must be a boolean')
  end

  vim.api.nvim_create_user_command('LifeModeHello', function()
    M.hello()
  end, {})

  vim.api.nvim_create_user_command('LifeMode', function()
    M.open_view()
  end, {})

  vim.api.nvim_create_user_command('LifeModeOpen', function()
    M.open_view_buffer()
  end, {})

  vim.api.nvim_create_user_command('LifeModeDebugSpan', function()
    M.debug_span()
  end, {})

  vim.api.nvim_create_user_command('LifeModeParse', function()
    M.parse_current_buffer()
  end, {})

  state.initialized = true
end

function M.get_config()
  return state.config
end

function M._reset_state()
  state.config = nil
  state.initialized = false
end

function M.hello()
  if not state.config then
    vim.notify('LifeMode not configured. Run require("lifemode").setup()', vim.log.levels.ERROR)
    return
  end

  local lines = {
    'LifeMode Configuration:',
    '----------------------',
  }

  for key, value in pairs(state.config) do
    table.insert(lines, string.format('  %s: %s', key, vim.inspect(value)))
  end

  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end

function M.open_view()
  if not state.config then
    vim.notify('LifeMode not configured. Run require("lifemode").setup()', vim.log.levels.ERROR)
    return
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = 'nofile'
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].bufhidden = 'wipe'
  vim.api.nvim_buf_set_name(bufnr, 'LifeMode')

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    'LifeMode View (Empty)',
    '',
    'Default view: ' .. state.config.default_view,
    'Vault root: ' .. state.config.vault_root,
  })

  vim.api.nvim_win_set_buf(0, bufnr)
end

function M.open_view_buffer()
  if not state.config then
    vim.notify('LifeMode not configured. Run require("lifemode").setup()', vim.log.levels.ERROR)
    return
  end

  local view = require('lifemode.view')
  local bufnr = view.create_buffer()
  vim.api.nvim_win_set_buf(0, bufnr)
end

function M.debug_span()
  if not state.config then
    vim.notify('LifeMode not configured. Run require("lifemode").setup()', vim.log.levels.ERROR)
    return
  end

  local extmarks = require('lifemode.extmarks')
  local metadata = extmarks.get_instance_at_cursor()

  if not metadata then
    vim.notify('No instance metadata at cursor', vim.log.levels.WARN)
    return
  end

  local lines = {
    'Instance Metadata:',
    '==================',
  }

  for key, value in pairs(metadata) do
    table.insert(lines, string.format('  %s: %s', key, vim.inspect(value)))
  end

  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end

function M.parse_current_buffer()
  if not state.config then
    vim.notify('LifeMode not configured. Run require("lifemode").setup()', vim.log.levels.ERROR)
    return
  end

  local parser = require('lifemode.parser')
  local bufnr = vim.api.nvim_get_current_buf()
  local blocks = parser.parse_buffer(bufnr)

  local task_count = 0
  for _, block in ipairs(blocks) do
    if block.type == 'task' then
      task_count = task_count + 1
    end
  end

  vim.notify(string.format('Parsed %d blocks (%d tasks)', #blocks, task_count), vim.log.levels.INFO)
end

return M
