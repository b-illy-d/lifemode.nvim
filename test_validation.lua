local lifemode = require('lifemode')

print('=== VALIDATION TEST SUITE ===\n')

local function test_should_fail(description, setup_opts)
  print('Test: ' .. description)
  local ok, err = pcall(function()
    lifemode._reset_state()
    lifemode.setup(setup_opts)
  end)
  if ok then
    print('  FAIL - No error thrown')
    return false
  else
    print('  PASS - Error: ' .. tostring(err))
    return true
  end
end

local function test_should_pass(description, setup_opts)
  print('Test: ' .. description)
  local ok, err = pcall(function()
    lifemode._reset_state()
    lifemode.setup(setup_opts)
  end)
  if ok then
    print('  PASS - Accepted valid config')
    return true
  else
    print('  FAIL - Error: ' .. tostring(err))
    return false
  end
end

local passed = 0
local failed = 0

if test_should_fail('vault_root is nil', {}) then passed = passed + 1 else failed = failed + 1 end
if test_should_fail('vault_root is empty string', { vault_root = '' }) then passed = passed + 1 else failed = failed + 1 end
if test_should_fail('vault_root is number', { vault_root = 12345 }) then passed = passed + 1 else failed = failed + 1 end
if test_should_fail('vault_root is table', { vault_root = { '/tmp/test' } }) then passed = passed + 1 else failed = failed + 1 end
if test_should_fail('vault_root is whitespace only', { vault_root = '   ' }) then passed = passed + 1 else failed = failed + 1 end

if test_should_fail('max_depth is string', { vault_root = '/tmp/test', max_depth = 'ten' }) then passed = passed + 1 else failed = failed + 1 end
if test_should_fail('max_depth is negative', { vault_root = '/tmp/test', max_depth = -5 }) then passed = passed + 1 else failed = failed + 1 end
if test_should_fail('max_depth is zero', { vault_root = '/tmp/test', max_depth = 0 }) then passed = passed + 1 else failed = failed + 1 end

if test_should_fail('max_nodes_per_action is string', { vault_root = '/tmp/test', max_nodes_per_action = 'hundred' }) then passed = passed + 1 else failed = failed + 1 end
if test_should_fail('max_nodes_per_action is negative', { vault_root = '/tmp/test', max_nodes_per_action = -100 }) then passed = passed + 1 else failed = failed + 1 end
if test_should_fail('max_nodes_per_action is zero', { vault_root = '/tmp/test', max_nodes_per_action = 0 }) then passed = passed + 1 else failed = failed + 1 end

if test_should_fail('bible_version is number', { vault_root = '/tmp/test', bible_version = 42 }) then passed = passed + 1 else failed = failed + 1 end
if test_should_fail('default_view is number', { vault_root = '/tmp/test', default_view = 123 }) then passed = passed + 1 else failed = failed + 1 end
if test_should_fail('auto_index_on_startup is string', { vault_root = '/tmp/test', auto_index_on_startup = 'yes' }) then passed = passed + 1 else failed = failed + 1 end

if test_should_pass('valid minimal config', { vault_root = '/tmp/test' }) then passed = passed + 1 else failed = failed + 1 end
if test_should_pass('valid full config', {
  vault_root = '/tmp/test',
  leader = '<Leader>',
  max_depth = 20,
  max_nodes_per_action = 200,
  bible_version = 'NIV',
  default_view = 'tasks',
  daily_view_expanded_depth = 5,
  tasks_default_grouping = 'context',
  auto_index_on_startup = true,
}) then passed = passed + 1 else failed = failed + 1 end

print('\n=== VALIDATION TEST SUMMARY ===')
print(string.format('Passed: %d / %d', passed, passed + failed))
print(string.format('Failed: %d / %d', failed, passed + failed))

if failed > 0 then
  os.exit(1)
else
  os.exit(0)
end
