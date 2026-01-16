vim.opt.rtp:prepend('.')
local lifemode = require('lifemode')

print('=== COMMAND REGISTRATION EDGE CASES ===\n')

print('Test 1: Commands registered after first setup')
lifemode._reset_state()
lifemode.setup({ vault_root = '/tmp/test1' })
local exists1 = vim.fn.exists(':LifeModeHello')
local exists2 = vim.fn.exists(':LifeMode')
print('  After first setup:')
print('    :LifeModeHello exists: ' .. tostring(exists1 == 2))
print('    :LifeMode exists: ' .. tostring(exists2 == 2))

print('\nTest 2: Commands after second setup (duplicate registration)')
lifemode.setup({ vault_root = '/tmp/test2' })
local exists3 = vim.fn.exists(':LifeModeHello')
local exists4 = vim.fn.exists(':LifeMode')
print('  After second setup:')
print('    :LifeModeHello exists: ' .. tostring(exists3 == 2))
print('    :LifeMode exists: ' .. tostring(exists4 == 2))
print('  POTENTIAL ISSUE: Commands registered twice, possible memory leak')

print('\nTest 3: Check command callback behavior after re-registration')
vim.cmd('LifeModeHello')
print('  Command executed (check if config from second setup is used)')

print('\nTest 4: nvim_create_user_command with duplicate name')
local ok, err = pcall(vim.api.nvim_create_user_command, 'TestCmd', function() end, {})
print('  First registration: ok=' .. tostring(ok))
ok, err = pcall(vim.api.nvim_create_user_command, 'TestCmd', function() end, {})
print('  Second registration: ok=' .. tostring(ok))
if not ok then
  print('  Error: ' .. tostring(err))
end

print('\n=== END COMMAND REGISTRATION EDGE CASES ===')
