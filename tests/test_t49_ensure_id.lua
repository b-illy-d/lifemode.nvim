local function reset_modules()
  package.loaded['lifemode.patch'] = nil
  package.loaded['lifemode.parser'] = nil
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

local function assert_match(actual, pattern, label)
  if not actual or not actual:match(pattern) then
    print('FAIL: ' .. label)
    print('  expected pattern: ' .. pattern)
    print('  got: ' .. vim.inspect(actual))
    vim.cmd('cq 1')
  end
end

local patch = require('lifemode.patch')
local parser = require('lifemode.parser')

local test_dir = vim.fn.tempname()
vim.fn.mkdir(test_dir, 'p')

print('TEST: generate_id returns UUID-like string')
local id = patch.generate_id()
assert_truthy(id, 'id generated')
assert_match(id, '^[a-f0-9%-]+$', 'id is hex with hyphens')
assert_equal(#id, 36, 'id is 36 chars (UUID format)')
print('PASS')

print('TEST: ensure_id adds ID to task without one')
local test_file = test_dir .. '/test_task.md'
vim.fn.writefile({'- [ ] Buy milk'}, test_file)
local result = patch.ensure_id(test_file, 0)
assert_truthy(result, 'returned new ID')
local lines = vim.fn.readfile(test_file)
assert_match(lines[1], '%^[a-f0-9%-]+$', 'line ends with ID')
print('PASS')

print('TEST: ensure_id returns existing ID if present')
test_file = test_dir .. '/test_with_id.md'
vim.fn.writefile({'- [ ] Buy eggs ^existing-id'}, test_file)
result = patch.ensure_id(test_file, 0)
assert_equal(result, 'existing-id', 'returns existing ID')
lines = vim.fn.readfile(test_file)
assert_truthy(lines[1]:match('%^existing%-id$'), 'original ID preserved')
print('PASS')

print('TEST: ensure_id works on headings')
test_file = test_dir .. '/test_heading.md'
vim.fn.writefile({'## My Heading'}, test_file)
result = patch.ensure_id(test_file, 0)
assert_truthy(result, 'returned new ID')
lines = vim.fn.readfile(test_file)
assert_match(lines[1], '^## My Heading %^[a-f0-9%-]+$', 'heading has ID')
print('PASS')

print('TEST: ensure_id works on list items')
test_file = test_dir .. '/test_list.md'
vim.fn.writefile({'- Some item with [[link]]'}, test_file)
result = patch.ensure_id(test_file, 0)
assert_truthy(result, 'returned new ID')
lines = vim.fn.readfile(test_file)
assert_match(lines[1], '%^[a-f0-9%-]+$', 'list item has ID')
print('PASS')

vim.fn.delete(test_dir, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
