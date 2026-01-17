local function reset_modules()
  package.loaded['lifemode'] = nil
  package.loaded['lifemode.parser'] = nil
  package.loaded['lifemode.index'] = nil
  package.loaded['lifemode.vault'] = nil
  package.loaded['lifemode.bible'] = nil
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

local test_vault = vim.fn.tempname()
vim.fn.mkdir(test_vault, 'p')

print('TEST: parser extracts Bible references as refs')
vim.fn.writefile({
  '# Notes on John 17:20',
}, test_vault .. '/notes.md')

local parser = require('lifemode.parser')
local blocks = parser.parse_file(test_vault .. '/notes.md')
assert_truthy(blocks[1].refs, 'refs exist')
local found_bible = false
for _, ref in ipairs(blocks[1].refs) do
  if ref.type == 'bible' then
    found_bible = true
    assert_equal(ref.book, 'John', 'book is John')
    assert_equal(ref.verse_ids[1], 'bible:john:17:20', 'verse ID correct')
  end
end
assert_truthy(found_bible, 'found bible ref')
print('PASS')

print('TEST: index populates backlinks for Bible verses')
local index = require('lifemode.index')
index._reset_state()

vim.fn.writefile({
  '# Study notes',
  '- [ ] Meditate on John 17:20 ^task-1',
}, test_vault .. '/study.md')

local idx = index.build(test_vault)
local backlinks = index.get_backlinks('bible:john:17:20', idx)
assert_truthy(#backlinks >= 1, 'has backlink for verse')
print('PASS')

print('TEST: range references create backlinks for each verse')
vim.fn.writefile({
  '- Reading John 17:18-20 passage ^reading-1',
}, test_vault .. '/reading.md')

index._reset_state()
idx = index.build(test_vault)

local backlinks_18 = index.get_backlinks('bible:john:17:18', idx)
local backlinks_19 = index.get_backlinks('bible:john:17:19', idx)
local backlinks_20 = index.get_backlinks('bible:john:17:20', idx)

assert_truthy(#backlinks_18 >= 1, 'verse 18 has backlink')
assert_truthy(#backlinks_19 >= 1, 'verse 19 has backlink')
assert_truthy(#backlinks_20 >= 1, 'verse 20 has backlink')
print('PASS')

print('TEST: query all notes referencing a verse finds range mentions')
vim.fn.writefile({
  '- Direct ref to John 17:19',
}, test_vault .. '/direct.md')

index._reset_state()
idx = index.build(test_vault)

local all_19_backlinks = index.get_backlinks('bible:john:17:19', idx)
assert_truthy(#all_19_backlinks >= 2, 'finds direct and range refs')
print('PASS')

vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
