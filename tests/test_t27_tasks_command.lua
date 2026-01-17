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

local lifemode = require('lifemode')
local index = require('lifemode.index')

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
})

local today = os.date('%Y-%m-%d')

print('TEST: :LifeMode tasks command opens tasks view')
vim.fn.writefile({
  '- [ ] Task one !1 @due(' .. today .. ') ^task-1',
  '- [ ] Task two !3 ^task-2',
}, test_file)

vim.cmd('LifeMode tasks')
local bufnr = vim.api.nvim_get_current_buf()

assert_equal(vim.bo[bufnr].filetype, 'lifemode', 'buffer has lifemode filetype')
assert_equal(vim.bo[bufnr].buftype, 'nofile', 'buffer is nofile')
print('PASS')

print('TEST: tasks view shows task content')
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
local found_task = false
for _, line in ipairs(lines) do
  if line:match('Task one') or line:match('Task two') then
    found_task = true
    break
  end
end
assert_truthy(found_task, 'buffer contains task text')
print('PASS')

print('TEST: tasks view shows group headers')
local found_header = false
for _, line in ipairs(lines) do
  if line:match('Today') or line:match('No Due') or line:match('Priority') then
    found_header = true
    break
  end
end
assert_truthy(found_header, 'buffer contains group header')
print('PASS')

print('TEST: tasks view has keymaps')
local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
local found_quit = false
local found_toggle = false

for _, km in ipairs(keymaps) do
  if km.lhs == 'q' then found_quit = true end
  if km.lhs == '  ' or km.lhs == '<Space><Space>' then found_toggle = true end
end

assert_truthy(found_quit, 'quit keymap exists')
assert_truthy(found_toggle, 'toggle keymap exists')
print('PASS')

vim.cmd('bdelete!')

vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
