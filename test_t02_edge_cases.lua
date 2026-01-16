local function setup()
  vim.cmd('set runtimepath+=.')
  require('lifemode')._reset_state()
  require('lifemode').setup({ vault_root = '/tmp/vault' })
end

local function test_invalid_buffer_error()
  local extmarks = require('lifemode.extmarks')

  local success, err = pcall(extmarks.set_instance_span, 0, 0, 0, {})
  assert(not success, 'Should error on invalid buffer')
  assert(err:match('Invalid buffer number'), 'Error message should mention invalid buffer')

  print('PASS: Invalid buffer error')
end

local function test_multiple_extmarks_in_buffer()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    'Line 1',
    'Line 2',
    'Line 3',
    'Line 4',
    'Line 5',
  })
  vim.api.nvim_win_set_buf(0, bufnr)

  extmarks.set_instance_span(bufnr, 0, 1, { instance_id = 'inst-1', node_id = 'node-1' })
  extmarks.set_instance_span(bufnr, 2, 3, { instance_id = 'inst-2', node_id = 'node-2' })
  extmarks.set_instance_span(bufnr, 4, 4, { instance_id = 'inst-3', node_id = 'node-3' })

  vim.api.nvim_win_set_cursor(0, {1, 0})
  local meta1 = extmarks.get_instance_at_cursor()
  assert(meta1 and meta1.instance_id == 'inst-1', 'Should get first instance')

  vim.api.nvim_win_set_cursor(0, {3, 0})
  local meta2 = extmarks.get_instance_at_cursor()
  assert(meta2 and meta2.instance_id == 'inst-2', 'Should get second instance')

  vim.api.nvim_win_set_cursor(0, {5, 0})
  local meta3 = extmarks.get_instance_at_cursor()
  assert(meta3 and meta3.instance_id == 'inst-3', 'Should get third instance')

  print('PASS: Multiple extmarks in buffer')
end

local function test_overlapping_spans()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    'Line 1',
    'Line 2',
    'Line 3',
  })
  vim.api.nvim_win_set_buf(0, bufnr)

  extmarks.set_instance_span(bufnr, 0, 2, { instance_id = 'outer', node_id = 'node-outer' })
  extmarks.set_instance_span(bufnr, 1, 1, { instance_id = 'inner', node_id = 'node-inner' })

  vim.api.nvim_win_set_cursor(0, {2, 0})
  local meta = extmarks.get_instance_at_cursor()
  assert(meta ~= nil, 'Should retrieve some metadata on overlap')

  print('PASS: Overlapping spans')
end

local function test_single_line_span()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Single line' })
  vim.api.nvim_win_set_buf(0, bufnr)

  extmarks.set_instance_span(bufnr, 0, 0, { instance_id = 'single', node_id = 'node-single' })

  vim.api.nvim_win_set_cursor(0, {1, 0})
  local meta = extmarks.get_instance_at_cursor()
  assert(meta and meta.instance_id == 'single', 'Should handle single-line span')

  print('PASS: Single line span')
end

local function test_multiline_span()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    'Line 1',
    'Line 2',
    'Line 3',
    'Line 4',
    'Line 5',
  })
  vim.api.nvim_win_set_buf(0, bufnr)

  extmarks.set_instance_span(bufnr, 1, 3, { instance_id = 'multi', node_id = 'node-multi' })

  vim.api.nvim_win_set_cursor(0, {2, 0})
  local meta2 = extmarks.get_instance_at_cursor()
  assert(meta2 and meta2.instance_id == 'multi', 'Should get metadata on first line')

  vim.api.nvim_win_set_cursor(0, {3, 0})
  local meta3 = extmarks.get_instance_at_cursor()
  assert(meta3 and meta3.instance_id == 'multi', 'Should get metadata on middle line')

  vim.api.nvim_win_set_cursor(0, {4, 0})
  local meta4 = extmarks.get_instance_at_cursor()
  assert(meta4 and meta4.instance_id == 'multi', 'Should get metadata on last line')

  vim.api.nvim_win_set_cursor(0, {1, 0})
  local meta1 = extmarks.get_instance_at_cursor()
  assert(meta1 == nil, 'Should return nil outside span')

  vim.api.nvim_win_set_cursor(0, {5, 0})
  local meta5 = extmarks.get_instance_at_cursor()
  assert(meta5 == nil, 'Should return nil after span')

  print('PASS: Multiline span')
end

local function test_namespace_persistence()
  local extmarks = require('lifemode.extmarks')
  local ns1 = extmarks.create_namespace()
  local ns2 = extmarks.create_namespace()
  local ns3 = extmarks.create_namespace()
  assert(ns1 == ns2 and ns2 == ns3, 'Namespace should persist across calls')

  print('PASS: Namespace persistence')
end

local function test_metadata_with_all_fields()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Test' })
  vim.api.nvim_win_set_buf(0, bufnr)

  local metadata = {
    instance_id = 'inst-full',
    node_id = 'node-full',
    lens = 'task/detail',
    depth = 5,
    collapsed = true,
    span_start = 0,
    span_end = 0,
  }

  extmarks.set_instance_span(bufnr, 0, 0, metadata)

  vim.api.nvim_win_set_cursor(0, {1, 0})
  local retrieved = extmarks.get_instance_at_cursor()
  assert(retrieved ~= nil, 'Should retrieve metadata')
  assert(retrieved.instance_id == 'inst-full', 'instance_id preserved')
  assert(retrieved.node_id == 'node-full', 'node_id preserved')
  assert(retrieved.lens == 'task/detail', 'lens preserved')
  assert(retrieved.depth == 5, 'depth preserved')
  assert(retrieved.collapsed == true, 'collapsed preserved')
  assert(retrieved.span_start == 0, 'span_start preserved')
  assert(retrieved.span_end == 0, 'span_end preserved')

  print('PASS: Metadata with all fields')
end

local function test_buffer_deletion_cleanup()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Test' })
  vim.api.nvim_win_set_buf(0, bufnr)

  extmarks.set_instance_span(bufnr, 0, 0, { instance_id = 'temp' })

  vim.api.nvim_buf_delete(bufnr, { force = true })

  local new_bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(new_bufnr, 0, -1, false, { 'New buffer' })
  vim.api.nvim_win_set_buf(0, new_bufnr)
  vim.api.nvim_win_set_cursor(0, {1, 0})

  local meta = extmarks.get_instance_at_cursor()
  assert(meta == nil, 'Should not retrieve metadata from deleted buffer')

  print('PASS: Buffer deletion cleanup')
end

local function run_all_tests()
  setup()

  print('Running T02 Edge Case Tests...')
  print('')

  test_invalid_buffer_error()
  test_multiple_extmarks_in_buffer()
  test_overlapping_spans()
  test_single_line_span()
  test_multiline_span()
  test_namespace_persistence()
  test_metadata_with_all_fields()
  test_buffer_deletion_cleanup()

  print('')
  print('All T02 edge case tests passed!')
end

run_all_tests()
