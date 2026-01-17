local function reset_modules()
  package.loaded['lifemode'] = nil
  package.loaded['lifemode.init'] = nil
  package.loaded['lifemode.index'] = nil
  package.loaded['lifemode.parser'] = nil
  package.loaded['lifemode.vault'] = nil
  package.loaded['lifemode.lens'] = nil
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
  '- [ ] Test task !1 @due(2026-01-20) #work ^task-1',
}, test_vault .. '/tasks.md')

local lifemode = require('lifemode')
local index = require('lifemode.index')

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
})

print('TEST: <Space>l keymap exists on view buffer')
vim.cmd('LifeMode')
local bufnr = vim.api.nvim_get_current_buf()
local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
local found_l = false
local found_L = false

for _, km in ipairs(keymaps) do
  if km.lhs == ' l' or km.lhs == '<Space>l' then
    found_l = true
  end
  if km.lhs == ' L' or km.lhs == '<Space>L' then
    found_L = true
  end
end

assert_truthy(found_l, '<Space>l keymap exists')
assert_truthy(found_L, '<Space>L keymap exists')
print('PASS')

print('TEST: _cycle_lens_at_cursor function exists')
assert_truthy(lifemode._cycle_lens_at_cursor, '_cycle_lens_at_cursor exists')
print('PASS')

vim.cmd('bdelete!')
vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
