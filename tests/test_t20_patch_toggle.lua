local function reset_modules()
  package.loaded['lifemode'] = nil
  package.loaded['lifemode.init'] = nil
  package.loaded['lifemode.index'] = nil
  package.loaded['lifemode.patch'] = nil
  package.loaded['lifemode.parser'] = nil
  package.loaded['lifemode.vault'] = nil
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
local patch = require('lifemode.patch')

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
})

print('TEST: toggle_task_state changes todo to done')
vim.fn.writefile({
  '# Tasks',
  '',
  '- [ ] Task to complete ^task-1',
}, test_file)

index._reset_state()
local idx = index.get_or_build(test_vault)

patch.toggle_task_state('task-1', idx)

local lines = vim.fn.readfile(test_file)
assert_match(lines[3], '%- %[x%] Task to complete', 'task changed to done')
print('PASS')

print('TEST: toggle_task_state changes done to todo')
vim.fn.writefile({
  '# Tasks',
  '',
  '- [x] Completed task ^task-2',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

patch.toggle_task_state('task-2', idx)

lines = vim.fn.readfile(test_file)
assert_match(lines[3], '%- %[ %] Completed task', 'task changed to todo')
print('PASS')

print('TEST: toggle preserves metadata')
vim.fn.writefile({
  '# Tasks',
  '',
  '- [ ] Task !2 @due(2026-01-20) #work ^task-3',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

patch.toggle_task_state('task-3', idx)

lines = vim.fn.readfile(test_file)
assert_match(lines[3], '!2', 'priority preserved')
assert_match(lines[3], '@due%(2026%-01%-20%)', 'due date preserved')
assert_match(lines[3], '#work', 'tag preserved')
assert_match(lines[3], '%^task%-3', 'ID preserved')
print('PASS')

print('TEST: toggle returns new state')
vim.fn.writefile({
  '# Tasks',
  '',
  '- [ ] Task ^task-4',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

local new_state = patch.toggle_task_state('task-4', idx)
assert_equal(new_state, 'done', 'returns new state done')

new_state = patch.toggle_task_state('task-4', idx)
assert_equal(new_state, 'todo', 'returns new state todo')
print('PASS')

print('TEST: toggle with non-existent ID returns nil')
vim.fn.writefile({
  '# Tasks',
  '',
  '- [ ] Task ^task-5',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

local result = patch.toggle_task_state('non-existent-id', idx)
assert_equal(result, nil, 'returns nil for non-existent ID')
print('PASS')

vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
