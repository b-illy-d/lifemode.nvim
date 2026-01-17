local function reset_modules()
  package.loaded['lifemode.parser'] = nil
  package.loaded['lifemode.index'] = nil
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

local function assert_contains(list, value, label)
  for _, v in ipairs(list or {}) do
    if v == value then return end
  end
  print('FAIL: ' .. label)
  print('  list: ' .. vim.inspect(list))
  print('  expected to contain: ' .. vim.inspect(value))
  vim.cmd('cq 1')
end

local test_vault = vim.fn.tempname()
vim.fn.mkdir(test_vault, 'p')

print('TEST: backlinks index is populated from refs')
vim.fn.writefile({
  '# Notes about [[Target Page]]',
  '- [ ] Task linking to [[Another Page]] ^task-1',
}, test_vault .. '/source.md')

vim.fn.writefile({
  '# Target Page ^target-id',
}, test_vault .. '/target.md')

local index = require('lifemode.index')
index._reset_state()

local idx = index.build(test_vault)
assert_truthy(idx.backlinks, 'backlinks exists')
assert_truthy(idx.backlinks['Target Page'], 'Target Page has backlinks')
print('PASS')

print('TEST: backlinks contain source node IDs')
local backlinks = idx.backlinks['Target Page'] or {}
assert_equal(#backlinks, 1, 'one backlink to Target Page')
print('PASS')

print('TEST: get_backlinks returns list of source nodes')
local result = index.get_backlinks('Target Page', idx)
assert_truthy(result, 'get_backlinks returns result')
assert_equal(#result, 1, 'one backlink returned')
print('PASS')

print('TEST: backlinks work with heading targets')
vim.fn.writefile({
  '# Source file',
  '- Link to [[Target Page#Section]] ^source-2',
}, test_vault .. '/source2.md')

index._reset_state()
idx = index.build(test_vault)

local section_backlinks = index.get_backlinks('Target Page#Section', idx)
assert_truthy(section_backlinks, 'heading backlinks exist')
assert_equal(#section_backlinks, 1, 'one heading backlink')
print('PASS')

print('TEST: backlinks work with block ID targets')
vim.fn.writefile({
  '# Source file',
  '- Link to [[Target Page^target-id]]',
}, test_vault .. '/source3.md')

index._reset_state()
idx = index.build(test_vault)

local block_backlinks = index.get_backlinks('Target Page^target-id', idx)
assert_truthy(block_backlinks, 'block ID backlinks exist')
assert_equal(#block_backlinks, 1, 'one block backlink')
print('PASS')

print('TEST: get_backlinks returns empty list for no backlinks')
local empty = index.get_backlinks('Nonexistent Page', idx)
assert_truthy(empty, 'returns list even if empty')
assert_equal(#empty, 0, 'empty list')
print('PASS')

print('TEST: multiple backlinks to same target')
vim.fn.writefile({
  '- First link to [[Popular Page]]',
  '- Second link to [[Popular Page]]',
}, test_vault .. '/multi.md')

vim.fn.writefile({
  '- Another file links to [[Popular Page]] too',
}, test_vault .. '/another.md')

index._reset_state()
idx = index.build(test_vault)

local popular_backlinks = index.get_backlinks('Popular Page', idx)
assert_truthy(#popular_backlinks >= 2, 'multiple backlinks found')
print('PASS')

vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
