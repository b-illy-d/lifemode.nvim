local function reset_modules()
  package.loaded['lifemode.index'] = nil
  package.loaded['lifemode.parser'] = nil
  package.loaded['lifemode.patch'] = nil
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

local index = require('lifemode.index')
local parser = require('lifemode.parser')

local test_dir = vim.fn.tempname()
vim.fn.mkdir(test_dir, 'p')

print('TEST: find_nodes_needing_ids returns tasks without IDs')
local test_file = test_dir .. '/tasks.md'
vim.fn.writefile({
  '- [ ] Task with id ^existing-id',
  '- [ ] Task without id',
  '## Heading without id',
  '- List item with [[link]]',
}, test_file)

local nodes = parser.parse_file(test_file)
local needing_ids = index.find_nodes_needing_ids(nodes, test_file)
assert_equal(#needing_ids, 3, 'found 3 nodes needing IDs')
print('PASS')

print('TEST: assign_missing_ids adds IDs to nodes')
local count = index.assign_missing_ids(needing_ids)
assert_equal(count, 3, 'assigned 3 IDs')

local lines = vim.fn.readfile(test_file)
assert_match(lines[1], '%^existing%-id', 'existing ID preserved')
assert_match(lines[2], '%^[a-f0-9%-]+$', 'task got ID')
assert_match(lines[3], '%^[a-f0-9%-]+$', 'heading got ID')
assert_match(lines[4], '%^[a-f0-9%-]+$', 'list item with link got ID')
print('PASS')

print('TEST: nodes with IDs are not in needing_ids list')
test_file = test_dir .. '/all_have_ids.md'
vim.fn.writefile({
  '- [ ] Task one ^id1',
  '- [ ] Task two ^id2',
}, test_file)

nodes = parser.parse_file(test_file)
needing_ids = index.find_nodes_needing_ids(nodes, test_file)
assert_equal(#needing_ids, 0, 'no nodes need IDs')
print('PASS')

print('TEST: plain list items without links do not need IDs')
test_file = test_dir .. '/plain_list.md'
vim.fn.writefile({
  '- Plain item without links',
  '- Another plain item',
}, test_file)

nodes = parser.parse_file(test_file)
needing_ids = index.find_nodes_needing_ids(nodes, test_file)
assert_equal(#needing_ids, 0, 'plain list items do not need IDs')
print('PASS')

vim.fn.delete(test_dir, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
