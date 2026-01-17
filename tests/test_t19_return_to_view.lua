local function reset_modules()
  package.loaded['lifemode'] = nil
  package.loaded['lifemode.init'] = nil
  package.loaded['lifemode.index'] = nil
  package.loaded['lifemode.views.daily'] = nil
  package.loaded['lifemode.view'] = nil
  package.loaded['lifemode.extmarks'] = nil
  package.loaded['lifemode.lens'] = nil
  package.loaded['lifemode.parser'] = nil
  package.loaded['lifemode.vault'] = nil
  package.loaded['lifemode.navigation'] = nil
end

reset_modules()

local lifemode = require('lifemode')
local index = require('lifemode.index')

local function assert_equal(actual, expected, label)
  if actual ~= expected then
    print('FAIL: ' .. label)
    print('  expected: ' .. vim.inspect(expected))
    print('  got: ' .. vim.inspect(actual))
    vim.cmd('cq 1')
  end
end

local function assert_truthy(value, label)
  if not value then
    print('FAIL: ' .. label)
    vim.cmd('cq 1')
  end
end

local test_vault = vim.fn.tempname()
vim.fn.mkdir(test_vault, 'p')

local test_file = test_vault .. '/notes.md'
vim.fn.writefile({
  '# My Notes',
  '',
  '- [ ] Task one',
  '- [x] Task two',
}, test_file)

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
  daily_view_expanded_depth = 3,
})

print('TEST: last_view_bufnr is tracked after jump')
lifemode.open_view()
local view_bufnr = vim.api.nvim_get_current_buf()

local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
local task_line = nil
for i, line in ipairs(lines) do
  if line:match('Task one') then
    task_line = i
    break
  end
end

if task_line then
  vim.api.nvim_win_set_cursor(0, {task_line, 0})
  lifemode._jump_to_source()

  local last_view = lifemode._get_last_view_bufnr()
  assert_equal(last_view, view_bufnr, 'last view bufnr is tracked')
else
  print('SKIP: no task line found')
end
print('PASS')

print('TEST: _return_to_view switches back to view buffer')
local source_bufnr = vim.api.nvim_get_current_buf()
assert_truthy(source_bufnr ~= view_bufnr, 'in source buffer')

lifemode._return_to_view()
local current_after = vim.api.nvim_get_current_buf()
assert_equal(current_after, view_bufnr, 'returned to view buffer')
print('PASS')

print('TEST: _return_to_view does nothing if no last view')
vim.cmd('bdelete!')
reset_modules()
lifemode = require('lifemode')
index = require('lifemode.index')

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
  daily_view_expanded_depth = 3,
})

local buf_before = vim.api.nvim_get_current_buf()
lifemode._return_to_view()
local buf_after = vim.api.nvim_get_current_buf()
assert_equal(buf_after, buf_before, 'no change when no last view')
print('PASS')

print('TEST: :LifeMode from source refreshes index')
vim.fn.writefile({
  '# My Notes',
  '',
  '- [ ] Task one',
  '- [x] Task two',
  '- [ ] New task added',
}, test_file)

lifemode.open_view()
local new_view_bufnr = vim.api.nvim_get_current_buf()
lines = vim.api.nvim_buf_get_lines(new_view_bufnr, 0, -1, false)

local found_new_task = false
for _, line in ipairs(lines) do
  if line:match('New task added') then
    found_new_task = true
    break
  end
end
assert_truthy(found_new_task, 'new task appears in view')
print('PASS')

vim.cmd('bdelete!')

vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
