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

local function assert_match(str, pattern, label)
  if not str or not str:match(pattern) then
    print('FAIL: ' .. label)
    print('  pattern: ' .. pattern)
    print('  string: ' .. vim.inspect(str))
    vim.cmd('cq 1')
  end
end

local function assert_not_match(str, pattern, label)
  if str and str:match(pattern) then
    print('FAIL: ' .. label)
    print('  should not match: ' .. pattern)
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

print('TEST: set_due adds due date to task without one')
vim.fn.writefile({
  '- [ ] Task without due ^task-1',
}, test_file)

index._reset_state()
local idx = index.get_or_build(test_vault)

local result = patch.set_due('task-1', '2026-02-15', idx)
assert_equal(result, '2026-02-15', 'returns new due date')

local lines = vim.fn.readfile(test_file)
assert_match(lines[1], '@due%(2026%-02%-15%)', 'file has due date')
print('PASS')

print('TEST: set_due updates existing due date')
vim.fn.writefile({
  '- [ ] Task @due(2026-01-01) ^task-2',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

result = patch.set_due('task-2', '2026-03-20', idx)
assert_equal(result, '2026-03-20', 'returns new due date')

lines = vim.fn.readfile(test_file)
assert_match(lines[1], '@due%(2026%-03%-20%)', 'file has new due date')
assert_not_match(lines[1], '@due%(2026%-01%-01%)', 'old due date removed')
print('PASS')

print('TEST: clear_due removes due date')
vim.fn.writefile({
  '- [ ] Task @due(2026-01-01) ^task-3',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

result = patch.clear_due('task-3', idx)
assert_equal(result, true, 'returns true')

lines = vim.fn.readfile(test_file)
assert_not_match(lines[1], '@due', 'file has no due date')
print('PASS')

print('TEST: clear_due on task without due does nothing')
vim.fn.writefile({
  '- [ ] Task without due ^task-4',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

result = patch.clear_due('task-4', idx)
assert_equal(result, false, 'returns false')
print('PASS')

print('TEST: set_due preserves other metadata')
vim.fn.writefile({
  '- [ ] Task !2 #work ^task-5',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

patch.set_due('task-5', '2026-04-01', idx)

lines = vim.fn.readfile(test_file)
assert_match(lines[1], '!2', 'priority preserved')
assert_match(lines[1], '#work', 'tag preserved')
assert_match(lines[1], '%^task%-5', 'ID preserved')
print('PASS')

print('TEST: set_due validates date format')
vim.fn.writefile({
  '- [ ] Task ^task-6',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

result = patch.set_due('task-6', 'invalid-date', idx)
assert_equal(result, nil, 'returns nil for invalid date')

lines = vim.fn.readfile(test_file)
assert_not_match(lines[1], '@due', 'no due date added for invalid format')
print('PASS')

vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
