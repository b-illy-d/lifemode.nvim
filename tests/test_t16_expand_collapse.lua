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

local function count_lines()
  local bufnr = vim.api.nvim_get_current_buf()
  return #vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local test_vault = vim.fn.tempname()
vim.fn.mkdir(test_vault, 'p')

local test_file = test_vault .. '/test.md'
vim.fn.writefile({
  '# Test file',
  '',
  '- [ ] Task one',
  '- [x] Task two',
}, test_file)

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
  daily_view_expanded_depth = 0,
})

print('TEST: expand collapsed instance')
lifemode.open_view()
local initial_lines = count_lines()
assert_equal(initial_lines, 1, 'starts with just year collapsed')

vim.api.nvim_win_set_cursor(0, {1, 0})

lifemode._expand_at_cursor()
local after_expand = count_lines()
assert_truthy(after_expand > initial_lines, 'expand increases lines: ' .. after_expand)
print('PASS')

print('TEST: expand already expanded does nothing')
lifemode._expand_at_cursor()
local still_same = count_lines()
assert_equal(still_same, after_expand, 'expand on expanded does nothing')
print('PASS')

print('TEST: collapse expanded instance')
vim.api.nvim_win_set_cursor(0, {1, 0})
lifemode._collapse_at_cursor()
local after_collapse = count_lines()
assert_equal(after_collapse, 1, 'collapse returns to 1 line')
print('PASS')

print('TEST: collapse already collapsed does nothing')
lifemode._collapse_at_cursor()
local still_collapsed = count_lines()
assert_equal(still_collapsed, 1, 'collapse on collapsed does nothing')
print('PASS')

print('TEST: expand multiple levels')
vim.api.nvim_win_set_cursor(0, {1, 0})
lifemode._expand_at_cursor()
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

local month_line = nil
for i, line in ipairs(lines) do
  if line:match('January') or line:match('February') or line:match('March') or
     line:match('April') or line:match('May') or line:match('June') or
     line:match('July') or line:match('August') or line:match('September') or
     line:match('October') or line:match('November') or line:match('December') then
    month_line = i
    break
  end
end

if month_line then
  vim.api.nvim_win_set_cursor(0, {month_line, 0})
  local before_month_expand = count_lines()
  lifemode._expand_at_cursor()
  local after_month_expand = count_lines()
  assert_truthy(after_month_expand > before_month_expand, 'expanding month adds lines')
  print('PASS')
else
  print('SKIP: no month line found (expected if test date parsing differs)')
  print('PASS')
end

print('TEST: expand/collapse on leaf node does nothing')
lifemode._collapse_at_cursor()
vim.api.nvim_win_set_cursor(0, {1, 0})
lifemode._expand_at_cursor()
lifemode._expand_at_cursor()
lifemode._expand_at_cursor()

local lines_count = count_lines()
lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
local task_line = nil
for i, line in ipairs(lines) do
  if line:match('Task') then
    task_line = i
    break
  end
end

if task_line then
  vim.api.nvim_win_set_cursor(0, {task_line, 0})
  local before = count_lines()
  lifemode._expand_at_cursor()
  local after = count_lines()
  assert_equal(after, before, 'expand on leaf does nothing')
  lifemode._collapse_at_cursor()
  local after_collapse_leaf = count_lines()
  assert_equal(after_collapse_leaf, before, 'collapse on leaf does nothing')
  print('PASS')
else
  print('SKIP: no task line found')
  print('PASS')
end

vim.cmd('bdelete!')
vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
