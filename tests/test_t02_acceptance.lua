local function setup()
  vim.cmd('set runtimepath+=.')
  require('lifemode')._reset_state()
  require('lifemode').setup({ vault_root = '/tmp/vault' })
end

local function test_extmark_namespace_creation()
  local extmarks = require('lifemode.extmarks')
  local ns = extmarks.create_namespace()
  assert(type(ns) == 'number', 'Namespace should be a number')
  assert(ns > 0, 'Namespace should be positive')

  local ns2 = extmarks.create_namespace()
  assert(ns == ns2, 'Multiple calls should return same namespace')

  print('PASS: Extmark namespace creation')
end

local function test_set_instance_span()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    'Line 1',
    'Line 2',
    'Line 3',
  })

  local metadata = {
    instance_id = 'inst-001',
    node_id = 'node-123',
    lens = 'task/brief',
    depth = 1,
    collapsed = false,
  }

  extmarks.set_instance_span(bufnr, 0, 2, metadata)

  print('PASS: Set instance span')
end

local function test_get_instance_at_cursor()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    'Line 1',
    'Line 2',
    'Line 3',
  })
  vim.api.nvim_win_set_buf(0, bufnr)

  local metadata = {
    instance_id = 'inst-002',
    node_id = 'node-456',
    lens = 'task/detail',
    depth = 2,
    collapsed = true,
  }

  extmarks.set_instance_span(bufnr, 1, 1, metadata)

  vim.api.nvim_win_set_cursor(0, {2, 0})

  local retrieved = extmarks.get_instance_at_cursor()
  assert(retrieved ~= nil, 'Should retrieve metadata at cursor')
  assert(retrieved.instance_id == 'inst-002', 'instance_id should match')
  assert(retrieved.node_id == 'node-456', 'node_id should match')
  assert(retrieved.lens == 'task/detail', 'lens should match')
  assert(retrieved.depth == 2, 'depth should match')
  assert(retrieved.collapsed == true, 'collapsed should match')

  print('PASS: Get instance at cursor')
end

local function test_get_instance_no_extmark()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'No extmark here' })
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.api.nvim_win_set_cursor(0, {1, 0})

  local retrieved = extmarks.get_instance_at_cursor()
  assert(retrieved == nil, 'Should return nil when no extmark at cursor')

  print('PASS: Get instance no extmark')
end

local function test_debug_span_command()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Test line' })
  vim.api.nvim_win_set_buf(0, bufnr)

  local metadata = {
    instance_id = 'inst-debug',
    node_id = 'node-debug',
    lens = 'node/raw',
    depth = 0,
    collapsed = false,
  }

  extmarks.set_instance_span(bufnr, 0, 0, metadata)
  vim.api.nvim_win_set_cursor(0, {1, 0})

  vim.cmd('LifeModeDebugSpan')

  print('PASS: Debug span command')
end

local function run_all_tests()
  setup()

  print('Running T02 Acceptance Tests...')
  print('')

  test_extmark_namespace_creation()
  test_set_instance_span()
  test_get_instance_at_cursor()
  test_get_instance_no_extmark()
  test_debug_span_command()

  print('')
  print('All T02 acceptance tests passed!')
end

run_all_tests()
