local function reset_modules()
  package.loaded['lifemode'] = nil
  package.loaded['lifemode.init'] = nil
  package.loaded['lifemode.index'] = nil
  package.loaded['lifemode.parser'] = nil
  package.loaded['lifemode.vault'] = nil
  package.loaded['lifemode.wikilink'] = nil
end

reset_modules()

local function assert_truthy(value, label)
  if not value then
    print('FAIL: ' .. label)
    vim.cmd('cq 1')
  end
end

local function assert_equal(actual, expected, label)
  if actual ~= expected then
    print('FAIL: ' .. label)
    print('  expected: ' .. vim.inspect(expected))
    print('  got: ' .. vim.inspect(actual))
    vim.cmd('cq 1')
  end
end

local test_vault = vim.fn.tempname()
vim.fn.mkdir(test_vault, 'p')

vim.fn.writefile({
  '# Target Page',
  '',
  '## Section One',
  'Some content.',
  '',
  '## Section Two ^block-id',
  'More content.',
}, test_vault .. '/Target Page.md')

vim.fn.writefile({
  '# Source Page',
  '',
  '- Link to [[Target Page]]',
  '- Link with heading [[Target Page#Section Two]]',
  '- Link with block ID [[Target Page^block-id]]',
}, test_vault .. '/Source.md')

local lifemode = require('lifemode')
local index = require('lifemode.index')

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
})

print('TEST: get_wikilink_at_cursor detects simple wikilink')
vim.cmd('edit ' .. test_vault .. '/Source.md')
vim.api.nvim_win_set_cursor(0, {3, 12})

local wikilink = require('lifemode.wikilink')
local result = wikilink.get_at_cursor()
assert_truthy(result, 'wikilink detected')
assert_equal(result.target, 'Target Page', 'target is Target Page')
print('PASS')

print('TEST: get_wikilink_at_cursor detects heading link')
vim.api.nvim_win_set_cursor(0, {4, 25})
result = wikilink.get_at_cursor()
assert_truthy(result, 'wikilink detected')
assert_equal(result.page, 'Target Page', 'page is Target Page')
assert_equal(result.heading, 'Section Two', 'heading is Section Two')
print('PASS')

print('TEST: get_wikilink_at_cursor detects block ID link')
vim.api.nvim_win_set_cursor(0, {5, 25})
result = wikilink.get_at_cursor()
assert_truthy(result, 'wikilink detected')
assert_equal(result.page, 'Target Page', 'page is Target Page')
assert_equal(result.block_id, 'block-id', 'block_id is block-id')
print('PASS')

print('TEST: goto_definition jumps to page file')
vim.api.nvim_win_set_cursor(0, {3, 12})
wikilink.goto_definition(test_vault)
local current_file = vim.fn.expand('%:t')
assert_equal(current_file, 'Target Page.md', 'jumped to Target Page.md')
print('PASS')

print('TEST: goto_definition with heading jumps to correct line')
vim.cmd('edit ' .. test_vault .. '/Source.md')
vim.api.nvim_win_set_cursor(0, {4, 25})
wikilink.goto_definition(test_vault)
local cursor = vim.api.nvim_win_get_cursor(0)
assert_equal(cursor[1], 6, 'jumped to Section Two line')
print('PASS')

print('TEST: goto_definition with block ID jumps to correct line')
vim.cmd('edit ' .. test_vault .. '/Source.md')
vim.api.nvim_win_set_cursor(0, {5, 25})
wikilink.goto_definition(test_vault)
cursor = vim.api.nvim_win_get_cursor(0)
assert_equal(cursor[1], 6, 'jumped to block ID line')
print('PASS')

print('TEST: get_wikilink_at_cursor returns nil outside wikilink')
vim.cmd('edit ' .. test_vault .. '/Source.md')
vim.api.nvim_win_set_cursor(0, {1, 0})
result = wikilink.get_at_cursor()
assert_truthy(result == nil, 'no wikilink at heading')
print('PASS')

vim.cmd('bdelete!')
vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
