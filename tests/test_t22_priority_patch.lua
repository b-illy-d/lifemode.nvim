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

print('TEST: inc_priority increases priority number')
vim.fn.writefile({
  '- [ ] Task !3 ^task-1',
}, test_file)

index._reset_state()
local idx = index.get_or_build(test_vault)

local new_priority = patch.inc_priority('task-1', idx)
assert_equal(new_priority, 2, 'priority increased to 2')

local lines = vim.fn.readfile(test_file)
assert_match(lines[1], '!2', 'file has !2')
assert_not_match(lines[1], '!3', 'file no longer has !3')
print('PASS')

print('TEST: dec_priority decreases priority number')
vim.fn.writefile({
  '- [ ] Task !2 ^task-2',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

new_priority = patch.dec_priority('task-2', idx)
assert_equal(new_priority, 3, 'priority decreased to 3')

lines = vim.fn.readfile(test_file)
assert_match(lines[1], '!3', 'file has !3')
print('PASS')

print('TEST: inc_priority at !1 stays at !1')
vim.fn.writefile({
  '- [ ] Task !1 ^task-3',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

new_priority = patch.inc_priority('task-3', idx)
assert_equal(new_priority, 1, 'priority stays at 1')

lines = vim.fn.readfile(test_file)
assert_match(lines[1], '!1', 'file still has !1')
print('PASS')

print('TEST: dec_priority at !5 removes priority')
vim.fn.writefile({
  '- [ ] Task !5 ^task-4',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

new_priority = patch.dec_priority('task-4', idx)
assert_equal(new_priority, nil, 'priority removed')

lines = vim.fn.readfile(test_file)
assert_not_match(lines[1], '![1-5]', 'file has no priority')
print('PASS')

print('TEST: inc_priority on no-priority task adds !3')
vim.fn.writefile({
  '- [ ] Task without priority ^task-5',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

new_priority = patch.inc_priority('task-5', idx)
assert_equal(new_priority, 3, 'priority added as !3')

lines = vim.fn.readfile(test_file)
assert_match(lines[1], '!3', 'file has !3')
print('PASS')

print('TEST: priority preserves other metadata')
vim.fn.writefile({
  '- [ ] Task !3 @due(2026-01-20) #work ^task-6',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

patch.inc_priority('task-6', idx)

lines = vim.fn.readfile(test_file)
assert_match(lines[1], '@due%(2026%-01%-20%)', 'due date preserved')
assert_match(lines[1], '#work', 'tag preserved')
assert_match(lines[1], '%^task%-6', 'ID preserved')
print('PASS')

vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
