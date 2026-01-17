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

local function assert_equal(actual, expected, label)
  if actual ~= expected then
    print('FAIL: ' .. label)
    print('  expected: ' .. vim.inspect(expected))
    print('  got: ' .. vim.inspect(actual))
    vim.cmd('cq 1')
  end
end

local test_vault = vim.fn.tempname()
vim.fn.mkdir(test_vault, 'p')

vim.fn.writefile({
  '# Target Note ^target-1',
  'Some content here.',
}, test_vault .. '/target.md')

vim.fn.writefile({
  '# Source Note',
  '- Link to [[Target Note]] ^source-1',
}, test_vault .. '/source.md')

vim.fn.writefile({
  '# Another Source',
  '- [ ] Task referencing [[Target Note]] ^source-2',
}, test_vault .. '/another.md')

local lifemode = require('lifemode')
local index = require('lifemode.index')

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
})

print('TEST: gr keymap exists on view buffer')
vim.cmd('LifeMode')
local bufnr = vim.api.nvim_get_current_buf()
local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
local found_gr = false

for _, km in ipairs(keymaps) do
  if km.lhs == 'gr' then
    found_gr = true
  end
end

assert_truthy(found_gr, 'gr keymap exists')
print('PASS')

print('TEST: show_backlinks populates quickfix list')
vim.fn.setqflist({})
lifemode._show_backlinks('Target Note')

local qflist = vim.fn.getqflist()
assert_truthy(#qflist >= 2, 'quickfix has backlinks')
print('PASS')

print('TEST: quickfix entries have correct file paths')
local found_source = false
local found_another = false
for _, item in ipairs(qflist) do
  local fname = vim.fn.bufname(item.bufnr)
  if fname:match('source%.md') then found_source = true end
  if fname:match('another%.md') then found_another = true end
end
assert_truthy(found_source, 'source.md in quickfix')
assert_truthy(found_another, 'another.md in quickfix')
print('PASS')

print('TEST: quickfix entries have line numbers')
for _, item in ipairs(qflist) do
  assert_truthy(item.lnum and item.lnum > 0, 'has line number')
end
print('PASS')

print('TEST: show_backlinks with no backlinks shows message')
vim.fn.setqflist({})
lifemode._show_backlinks('Nonexistent Page')
local empty_qf = vim.fn.getqflist()
assert_equal(#empty_qf, 0, 'empty quickfix for no backlinks')
print('PASS')

vim.cmd('bdelete!')
vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
