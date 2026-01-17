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

print('TEST: add_tag adds tag to task without tags')
vim.fn.writefile({
  '- [ ] Task without tags ^task-1',
}, test_file)

index._reset_state()
local idx = index.get_or_build(test_vault)

local result = patch.add_tag('task-1', 'work', idx)
assert_equal(result, true, 'returns true')

local lines = vim.fn.readfile(test_file)
assert_match(lines[1], '#work', 'file has tag')
print('PASS')

print('TEST: add_tag adds tag to task with existing tags')
vim.fn.writefile({
  '- [ ] Task #existing ^task-2',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

result = patch.add_tag('task-2', 'newtag', idx)
assert_equal(result, true, 'returns true')

lines = vim.fn.readfile(test_file)
assert_match(lines[1], '#existing', 'existing tag preserved')
assert_match(lines[1], '#newtag', 'new tag added')
print('PASS')

print('TEST: add_tag does not duplicate existing tag')
vim.fn.writefile({
  '- [ ] Task #work ^task-3',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

result = patch.add_tag('task-3', 'work', idx)
assert_equal(result, false, 'returns false for duplicate')

lines = vim.fn.readfile(test_file)
local count = 0
for _ in lines[1]:gmatch('#work') do count = count + 1 end
assert_equal(count, 1, 'tag not duplicated')
print('PASS')

print('TEST: remove_tag removes existing tag')
vim.fn.writefile({
  '- [ ] Task #work #home ^task-4',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

result = patch.remove_tag('task-4', 'work', idx)
assert_equal(result, true, 'returns true')

lines = vim.fn.readfile(test_file)
assert_not_match(lines[1], '#work', 'tag removed')
assert_match(lines[1], '#home', 'other tag preserved')
print('PASS')

print('TEST: remove_tag returns false for non-existent tag')
vim.fn.writefile({
  '- [ ] Task #work ^task-5',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

result = patch.remove_tag('task-5', 'nonexistent', idx)
assert_equal(result, false, 'returns false')
print('PASS')

print('TEST: tag operations preserve other metadata')
vim.fn.writefile({
  '- [ ] Task !2 @due(2026-01-20) ^task-6',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

patch.add_tag('task-6', 'important', idx)

lines = vim.fn.readfile(test_file)
assert_match(lines[1], '!2', 'priority preserved')
assert_match(lines[1], '@due%(2026%-01%-20%)', 'due date preserved')
assert_match(lines[1], '%^task%-6', 'ID preserved')
print('PASS')

print('TEST: add_tag handles nested tags')
vim.fn.writefile({
  '- [ ] Task ^task-7',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

patch.add_tag('task-7', 'project/sub', idx)

lines = vim.fn.readfile(test_file)
assert_match(lines[1], '#project/sub', 'nested tag added')
print('PASS')

vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
