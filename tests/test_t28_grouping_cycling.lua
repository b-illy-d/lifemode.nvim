local function reset_modules()
  package.loaded['lifemode'] = nil
  package.loaded['lifemode.init'] = nil
  package.loaded['lifemode.index'] = nil
  package.loaded['lifemode.parser'] = nil
  package.loaded['lifemode.vault'] = nil
  package.loaded['lifemode.views.tasks'] = nil
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

local test_file = test_vault .. '/tasks.md'

local lifemode = require('lifemode')
local index = require('lifemode.index')

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
})

vim.fn.writefile({
  '- [ ] Task one !1 #work ^task-1',
  '- [ ] Task two !3 #home ^task-2',
}, test_file)

print('TEST: <Space>g keymap exists on tasks view')
vim.cmd('LifeMode tasks')
local bufnr = vim.api.nvim_get_current_buf()
local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
local found_cycle = false

for _, km in ipairs(keymaps) do
  if km.lhs == ' g' or km.lhs == '<Space>g' then
    found_cycle = true
  end
end

assert_truthy(found_cycle, '<Space>g keymap exists')
print('PASS')

print('TEST: cycling grouping changes view')
local lines_before = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
local found_due_group = false
for _, line in ipairs(lines_before) do
  if line:match('No Due Date') or line:match('Today') or line:match('Overdue') then
    found_due_group = true
    break
  end
end
assert_truthy(found_due_group, 'starts with due date grouping')

lifemode._cycle_grouping()

local lines_after = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
local found_priority_group = false
for _, line in ipairs(lines_after) do
  if line:match('Priority') or line:match('No Priority') then
    found_priority_group = true
    break
  end
end
assert_truthy(found_priority_group, 'cycled to priority grouping')
print('PASS')

print('TEST: cycle through all groupings and back')
lifemode._cycle_grouping()

local lines_tag = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
local found_tag_group = false
for _, line in ipairs(lines_tag) do
  if line:match('#work') or line:match('#home') or line:match('Untagged') then
    found_tag_group = true
    break
  end
end
assert_truthy(found_tag_group, 'cycled to tag grouping')

lifemode._cycle_grouping()

local lines_back = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
found_due_group = false
for _, line in ipairs(lines_back) do
  if line:match('No Due Date') or line:match('Today') or line:match('Overdue') then
    found_due_group = true
    break
  end
end
assert_truthy(found_due_group, 'cycled back to due date grouping')
print('PASS')

vim.cmd('bdelete!')

vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
