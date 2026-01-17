local function reset_modules()
  package.loaded['lifemode'] = nil
  package.loaded['lifemode.init'] = nil
  package.loaded['lifemode.index'] = nil
  package.loaded['lifemode.parser'] = nil
  package.loaded['lifemode.vault'] = nil
  package.loaded['lifemode.views.daily'] = nil
  package.loaded['lifemode.view'] = nil
  package.loaded['lifemode.extmarks'] = nil
end

reset_modules()

local function assert_truthy(value, label)
  if not value then
    print('FAIL: ' .. label)
    vim.cmd('cq 1')
  end
end

local test_vault = vim.fn.tempname()
vim.fn.mkdir(test_vault, 'p')

vim.fn.writefile({
  '- [ ] Task one ^task-1',
}, test_vault .. '/tasks.md')

local lifemode = require('lifemode')
local index = require('lifemode.index')

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
})

print('TEST: get_statusline_info function exists')
assert_truthy(lifemode.get_statusline_info, 'get_statusline_info exists')
print('PASS')

print('TEST: statusline info includes node type')
vim.cmd('LifeMode')
lifemode._update_active_node()
local info = lifemode.get_statusline_info()
assert_truthy(info, 'info returned')
assert_truthy(type(info) == 'string', 'info is string')
print('PASS')

print('TEST: statusline empty when no active node')
vim.api.nvim_win_set_cursor(0, {1, 0})
lifemode._update_active_node()
info = lifemode.get_statusline_info()
assert_truthy(type(info) == 'string', 'returns string even if empty')
print('PASS')

vim.cmd('bdelete!')
vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
