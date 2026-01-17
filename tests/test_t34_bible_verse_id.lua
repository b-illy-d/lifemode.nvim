local function reset_modules()
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

local function assert_contains(list, value, label)
  for _, v in ipairs(list or {}) do
    if v == value then return end
  end
  print('FAIL: ' .. label)
  print('  list: ' .. vim.inspect(list))
  print('  expected to contain: ' .. vim.inspect(value))
  vim.cmd('cq 1')
end

local bible = require('lifemode.bible')

print('TEST: generate_verse_id produces deterministic ID')
local id = bible.generate_verse_id('John', 17, 20)
assert_equal(id, 'bible:john:17:20', 'correct ID format')
print('PASS')

print('TEST: generate_verse_id lowercases book name')
id = bible.generate_verse_id('JOHN', 17, 20)
assert_equal(id, 'bible:john:17:20', 'book lowercase')
print('PASS')

print('TEST: generate_verse_id handles numbered books')
id = bible.generate_verse_id('1 Corinthians', 13, 4)
assert_equal(id, 'bible:1-corinthians:13:4', 'numbered book ID')
print('PASS')

print('TEST: expand_range returns list of verse IDs')
local ids = bible.expand_range('John', 17, 18, 20)
assert_equal(#ids, 3, 'three verse IDs')
assert_contains(ids, 'bible:john:17:18', 'has verse 18')
assert_contains(ids, 'bible:john:17:19', 'has verse 19')
assert_contains(ids, 'bible:john:17:20', 'has verse 20')
print('PASS')

print('TEST: expand_range with single verse returns one ID')
ids = bible.expand_range('John', 17, 20, 20)
assert_equal(#ids, 1, 'one verse ID')
assert_equal(ids[1], 'bible:john:17:20', 'correct ID')
print('PASS')

print('TEST: extract_refs includes verse IDs')
local refs = bible.extract_refs('Study John 17:20')
assert_truthy(refs, 'refs exist')
assert_truthy(refs[1].verse_ids, 'has verse_ids')
assert_equal(#refs[1].verse_ids, 1, 'one verse ID')
assert_equal(refs[1].verse_ids[1], 'bible:john:17:20', 'correct ID')
print('PASS')

print('TEST: extract_refs with range includes all verse IDs')
refs = bible.extract_refs('Read John 17:18-20')
assert_truthy(refs, 'refs exist')
assert_equal(#refs[1].verse_ids, 3, 'three verse IDs')
print('PASS')

print('\nAll tests passed')
vim.cmd('quit')
