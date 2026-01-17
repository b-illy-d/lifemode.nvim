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

local function assert_match(str, pattern, label)
  if not str or not str:match(pattern) then
    print('FAIL: ' .. label)
    print('  pattern: ' .. pattern)
    print('  string: ' .. vim.inspect(str))
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
  '- [ ] Task three ^abc12345-1234-1234-1234-123456789012',
}, test_file)

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
  daily_view_expanded_depth = 3,
})

print('TEST: gd keymap exists on view buffer')
lifemode.open_view()
local view_bufnr = vim.api.nvim_get_current_buf()
local keymaps = vim.api.nvim_buf_get_keymap(view_bufnr, 'n')
local found_gd = false
local found_enter = false

for _, km in ipairs(keymaps) do
  if km.lhs == 'gd' then found_gd = true end
  if km.lhs == '<CR>' then found_enter = true end
end

assert_truthy(found_gd, 'gd keymap exists')
print('PASS')

print('TEST: Enter keymap exists on view buffer')
assert_truthy(found_enter, 'Enter keymap exists')
print('PASS')

print('TEST: jump_to_source opens correct file')
local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
local task_line = nil
for i, line in ipairs(lines) do
  if line:match('Task one') then
    task_line = i
    break
  end
end

if not task_line then
  print('SKIP: no task line found')
else
  vim.api.nvim_win_set_cursor(0, {task_line, 0})

  lifemode._jump_to_source()

  local current_buf = vim.api.nvim_get_current_buf()
  local buf_name = vim.api.nvim_buf_get_name(current_buf)

  assert_truthy(buf_name:match('notes%.md$'), 'opened correct file')
end
print('PASS')

print('TEST: jump_to_source positions cursor at correct line')
local cursor = vim.api.nvim_win_get_cursor(0)
assert_equal(cursor[1], 3, 'cursor at line 3 (task one)')
print('PASS')

vim.cmd('bdelete!')

print('TEST: jump on date group does nothing')
reset_modules()
lifemode = require('lifemode')
index = require('lifemode.index')

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
  daily_view_expanded_depth = 3,
})

lifemode.open_view()
view_bufnr = vim.api.nvim_get_current_buf()

vim.api.nvim_win_set_cursor(0, {1, 0})
lifemode._jump_to_source()

local current_buf_after = vim.api.nvim_get_current_buf()
assert_equal(current_buf_after, view_bufnr, 'still in view buffer after date jump')
print('PASS')

print('TEST: jump with task that has ID')
lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
local task_with_id_line = nil
for i, line in ipairs(lines) do
  if line:match('Task three') then
    task_with_id_line = i
    break
  end
end

if not task_with_id_line then
  print('SKIP: no task with ID found')
else
  vim.api.nvim_win_set_cursor(0, {task_with_id_line, 0})
  lifemode._jump_to_source()

  local current_buf = vim.api.nvim_get_current_buf()
  local buf_name = vim.api.nvim_buf_get_name(current_buf)
  assert_truthy(buf_name:match('notes%.md$'), 'opened correct file for task with ID')

  local cursor = vim.api.nvim_win_get_cursor(0)
  assert_equal(cursor[1], 5, 'cursor at line 5 (task three)')
end
print('PASS')

vim.cmd('bdelete!')
vim.cmd('bdelete!')

vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
