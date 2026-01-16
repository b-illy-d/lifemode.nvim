local function setup()
  vim.cmd('set runtimepath+=.')
  require('lifemode')._reset_state()
  require('lifemode').setup({ vault_root = '/tmp/vault' })
end

local function test_extmark_creation_failure()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local original_set_extmark = vim.api.nvim_buf_set_extmark
  vim.api.nvim_buf_set_extmark = function()
    return nil
  end

  local bufnr = view.create_buffer()
  local success, err = pcall(extmarks.set_instance_span, bufnr, 0, 0, { instance_id = 'test' })

  vim.api.nvim_buf_set_extmark = original_set_extmark

  assert(not success, 'Should error when extmark creation fails')
  assert(err:match('Failed to create extmark'), 'Error message should be specific')

  print('PASS: Extmark creation failure handling')
end

local function test_stale_metadata_after_buffer_deletion()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr1 = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr1, 0, -1, false, { 'Test' })
  extmarks.set_instance_span(bufnr1, 0, 0, { instance_id = 'stale-test' })

  vim.api.nvim_buf_delete(bufnr1, { force = true })

  if extmarks._metadata_store and extmarks._metadata_store[bufnr1] then
    print('WARNING: Stale metadata remains after buffer deletion')
    print('  bufnr=' .. bufnr1 .. ' still has metadata entries')
    return false
  else
    print('PASS: No stale metadata after buffer deletion')
    return true
  end
end

local function test_concurrent_namespace_creation()
  package.loaded['lifemode.extmarks'] = nil
  local extmarks1 = require('lifemode.extmarks')
  local ns1 = extmarks1.create_namespace()

  local extmarks2 = require('lifemode.extmarks')
  local ns2 = extmarks2.create_namespace()

  assert(ns1 == ns2, 'Multiple module references should share same namespace')
  print('PASS: Concurrent namespace creation')
end

local function test_invalid_buffer_variations()
  local extmarks = require('lifemode.extmarks')

  local invalid_buffers = { 0, nil, -1, 999999 }
  local errors_caught = 0

  for _, bufnr in ipairs(invalid_buffers) do
    local success, _ = pcall(extmarks.set_instance_span, bufnr, 0, 0, {})
    if not success then
      errors_caught = errors_caught + 1
    end
  end

  if errors_caught >= 2 then
    print('PASS: Invalid buffer variations (' .. errors_caught .. '/4 caught)')
  else
    print('WARNING: Only ' .. errors_caught .. '/4 invalid buffers caught')
  end
end

local function test_metadata_key_collision()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Line 1', 'Line 2', 'Line 3' })

  extmarks.set_instance_span(bufnr, 0, 0, { instance_id = 'first' })
  extmarks.set_instance_span(bufnr, 0, 0, { instance_id = 'second' })

  vim.api.nvim_win_set_buf(0, bufnr)
  vim.api.nvim_win_set_cursor(0, {1, 0})

  local meta = extmarks.get_instance_at_cursor()

  if meta.instance_id == 'second' then
    print('PASS: Metadata key collision (overwrites correctly)')
  elseif meta.instance_id == 'first' then
    print('WARNING: Multiple spans at same position, retrieves first not last')
  else
    print('PASS: Metadata key collision (retrieves one of them)')
  end
end

local function test_empty_metadata_storage()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Empty buffer' })
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.api.nvim_win_set_cursor(0, {1, 0})

  local metadata = extmarks.get_instance_at_cursor()
  assert(metadata == nil, 'Should return nil when no metadata exists')

  print('PASS: Empty metadata storage')
end

local function test_extmark_api_edge_cases()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Line 1' })

  local success, err = pcall(extmarks.set_instance_span, bufnr, -1, 0, {})
  if not success then
    print('PASS: Negative line numbers caught by API')
  else
    print('WARNING: Negative line numbers accepted (may cause issues)')
  end
end

local function test_metadata_retrieval_after_mark_deletion()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Test' })
  vim.api.nvim_win_set_buf(0, bufnr)

  extmarks.set_instance_span(bufnr, 0, 0, { instance_id = 'deleted-test' })

  local ns = extmarks.create_namespace()
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  vim.api.nvim_win_set_cursor(0, {1, 0})
  local meta = extmarks.get_instance_at_cursor()

  if meta == nil then
    print('PASS: No metadata retrieved after extmark deletion')
  else
    print('WARNING: Stale metadata retrieved after extmark deletion')
    print('  Found: ' .. vim.inspect(meta))
    return false
  end

  return true
end

local function test_get_extmarks_api_failure()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Test' })
  vim.api.nvim_win_set_buf(0, bufnr)

  extmarks.set_instance_span(bufnr, 0, 0, { instance_id = 'test' })

  local original_get_extmarks = vim.api.nvim_buf_get_extmarks
  vim.api.nvim_buf_get_extmarks = function()
    error('Mock API failure')
  end

  local success, err = pcall(extmarks.get_instance_at_cursor)
  vim.api.nvim_buf_get_extmarks = original_get_extmarks

  if not success then
    print('PASS: API failure propagates error (not silent)')
  else
    print('WARNING: API failure returns result without error')
  end
end

local function test_start_end_line_validation()
  local extmarks = require('lifemode.extmarks')
  local view = require('lifemode.view')

  local bufnr = view.create_buffer()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Line 1' })

  local success1, _ = pcall(extmarks.set_instance_span, bufnr, 1, 0, {})
  local success2, _ = pcall(extmarks.set_instance_span, bufnr, 0, 1, {})

  if not success1 then
    print('WARNING: start_line > end_line rejected (may be overly strict)')
  else
    print('INFO: start_line > end_line accepted (Neovim API handles)')
  end

  print('PASS: Start/end line validation tested')
end

local function run_all_tests()
  setup()

  print('=== T02 SILENT FAILURE HUNT ===')
  print('')

  local issues = {}

  test_extmark_creation_failure()
  if not test_stale_metadata_after_buffer_deletion() then
    table.insert(issues, 'CRITICAL: Stale metadata after buffer deletion')
  end
  test_concurrent_namespace_creation()
  test_invalid_buffer_variations()
  test_metadata_key_collision()
  test_empty_metadata_storage()
  test_extmark_api_edge_cases()
  if not test_metadata_retrieval_after_mark_deletion() then
    table.insert(issues, 'HIGH: Stale metadata after extmark deletion')
  end
  test_get_extmarks_api_failure()
  test_start_end_line_validation()

  print('')
  print('=== SUMMARY ===')

  if #issues == 0 then
    print('✓ No critical silent failures detected')
  else
    print('⚠ Issues found:')
    for _, issue in ipairs(issues) do
      print('  - ' .. issue)
    end
  end

  print('')
  print('All silent failure tests completed')
end

run_all_tests()
