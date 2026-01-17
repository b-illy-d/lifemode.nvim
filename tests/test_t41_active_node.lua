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
  '- [ ] Task two ^task-2',
}, test_vault .. '/tasks.md')

local lifemode = require('lifemode')
local index = require('lifemode.index')

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
})

print('TEST: CursorMoved autocmd is set up on view buffer')
vim.cmd('LifeMode')
local bufnr = vim.api.nvim_get_current_buf()
local autocmds = vim.api.nvim_get_autocmds({
  buffer = bufnr,
  event = 'CursorMoved',
})
assert_truthy(#autocmds >= 1, 'CursorMoved autocmd exists')
print('PASS')

print('TEST: _update_active_node function exists')
assert_truthy(lifemode._update_active_node, '_update_active_node exists')
print('PASS')

print('TEST: active highlight group is defined')
local hl = vim.api.nvim_get_hl(0, {name = 'LifeModeActive'})
assert_truthy(hl, 'LifeModeActive highlight group exists')
print('PASS')

vim.cmd('bdelete!')
vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
