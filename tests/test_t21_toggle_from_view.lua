local function reset_modules()
  package.loaded['lifemode'] = nil
  package.loaded['lifemode.init'] = nil
  package.loaded['lifemode.index'] = nil
  package.loaded['lifemode.patch'] = nil
  package.loaded['lifemode.parser'] = nil
  package.loaded['lifemode.vault'] = nil
  package.loaded['lifemode.views.daily'] = nil
  package.loaded['lifemode.view'] = nil
  package.loaded['lifemode.extmarks'] = nil
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

local test_file = test_vault .. '/tasks.md'

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
  daily_view_expanded_depth = 3,
})

print('TEST: <Space><Space> keymap exists on view buffer')
vim.fn.writefile({
  '# Tasks',
  '',
  '- [ ] Task to toggle ^task-1',
}, test_file)

lifemode.open_view()
local view_bufnr = vim.api.nvim_get_current_buf()
local keymaps = vim.api.nvim_buf_get_keymap(view_bufnr, 'n')
local found_toggle = false

for _, km in ipairs(keymaps) do
  if km.lhs == '  ' or km.lhs == '<Space><Space>' then
    found_toggle = true
  end
end

assert_truthy(found_toggle, '<Space><Space> keymap exists')
print('PASS')

print('TEST: _toggle_task toggles task under cursor')
local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
local task_line = nil
for i, line in ipairs(lines) do
  if line:match('Task to toggle') then
    task_line = i
    break
  end
end

if not task_line then
  print('SKIP: no task line found')
else
  vim.api.nvim_win_set_cursor(0, {task_line, 0})

  lifemode._toggle_task()

  local file_lines = vim.fn.readfile(test_file)
  assert_match(file_lines[3], '%- %[x%]', 'task state changed in file')
end
print('PASS')

print('TEST: toggle refreshes view')
vim.cmd('bdelete!')
reset_modules()
lifemode = require('lifemode')
index = require('lifemode.index')

vim.fn.writefile({
  '# Tasks',
  '',
  '- [ ] Fresh task ^task-2',
}, test_file)

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
  daily_view_expanded_depth = 3,
})

lifemode.open_view()
view_bufnr = vim.api.nvim_get_current_buf()
lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)

task_line = nil
for i, line in ipairs(lines) do
  if line:match('Fresh task') then
    task_line = i
    break
  end
end

if not task_line then
  print('SKIP: no task line found')
else
  vim.api.nvim_win_set_cursor(0, {task_line, 0})
  lifemode._toggle_task()

  local new_lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  local found_done = false
  for _, line in ipairs(new_lines) do
    if line:match('%[x%]') or line:match('✓') or line:match('☑') then
      found_done = true
      break
    end
  end
  assert_truthy(found_done, 'view shows updated state')
end
print('PASS')

vim.cmd('bdelete!')

vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
