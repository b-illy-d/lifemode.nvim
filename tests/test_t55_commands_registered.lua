local function reset_modules()
  package.loaded['lifemode'] = nil
  package.loaded['lifemode.config'] = nil
end

reset_modules()

local function assert_truthy(value, label)
  if not value then
    print('FAIL: ' .. label)
    vim.cmd('cq 1')
  end
end

local function command_exists(name)
  local commands = vim.api.nvim_get_commands({})
  return commands[name] ~= nil
end

local test_dir = vim.fn.tempname()
vim.fn.mkdir(test_dir, 'p')
vim.fn.writefile({'# Test'}, test_dir .. '/test.md')

local lifemode = require('lifemode')
lifemode.setup({ vault_root = test_dir })

print('TEST: LifeMode command registered')
assert_truthy(command_exists('LifeMode'), 'LifeMode command exists')
print('PASS')

print('TEST: LifeModeParse command registered')
assert_truthy(command_exists('LifeModeParse'), 'LifeModeParse command exists')
print('PASS')

print('TEST: LifeModeDebugSpan command registered')
assert_truthy(command_exists('LifeModeDebugSpan'), 'LifeModeDebugSpan command exists')
print('PASS')

print('TEST: LifeModeHello command registered')
assert_truthy(command_exists('LifeModeHello'), 'LifeModeHello command exists')
print('PASS')

vim.fn.delete(test_dir, 'rf')
lifemode._reset_state()

print('\nAll tests passed')
vim.cmd('quit')
