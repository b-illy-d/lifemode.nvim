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

local bible = require('lifemode.bible')

print('TEST: parse single verse reference')
local refs = bible.extract_refs('Study notes on John 17:20 today')
assert_truthy(refs, 'refs exist')
assert_equal(#refs, 1, 'one ref')
assert_equal(refs[1].book, 'John', 'book is John')
assert_equal(refs[1].chapter, 17, 'chapter is 17')
assert_equal(refs[1].verse_start, 20, 'verse_start is 20')
assert_equal(refs[1].verse_end, 20, 'verse_end is 20')
print('PASS')

print('TEST: parse verse range reference')
refs = bible.extract_refs('Reading John 17:18-23 for devotions')
assert_truthy(refs, 'refs exist')
assert_equal(#refs, 1, 'one ref')
assert_equal(refs[1].book, 'John', 'book is John')
assert_equal(refs[1].verse_start, 18, 'verse_start is 18')
assert_equal(refs[1].verse_end, 23, 'verse_end is 23')
print('PASS')

print('TEST: parse abbreviated book name')
refs = bible.extract_refs('Reflecting on Rom 8:28')
assert_truthy(refs, 'refs exist')
assert_equal(refs[1].book, 'Romans', 'Rom maps to Romans')
print('PASS')

print('TEST: parse multiple references')
refs = bible.extract_refs('Compare John 3:16 with Rom 8:28')
assert_equal(#refs, 2, 'two refs')
assert_equal(refs[1].book, 'John', 'first is John')
assert_equal(refs[2].book, 'Romans', 'second is Romans')
print('PASS')

print('TEST: parse common abbreviations')
refs = bible.extract_refs('See Gen 1:1')
assert_equal(refs[1].book, 'Genesis', 'Gen maps to Genesis')

refs = bible.extract_refs('See Ex 20:3')
assert_equal(refs[1].book, 'Exodus', 'Ex maps to Exodus')

refs = bible.extract_refs('See Ps 23:1')
assert_equal(refs[1].book, 'Psalms', 'Ps maps to Psalms')

refs = bible.extract_refs('See Matt 5:3')
assert_equal(refs[1].book, 'Matthew', 'Matt maps to Matthew')

refs = bible.extract_refs('See 1 Cor 13:4')
assert_equal(refs[1].book, '1 Corinthians', '1 Cor maps to 1 Corinthians')
print('PASS')

print('TEST: no refs in text without references')
refs = bible.extract_refs('This is just regular text')
assert_truthy(not refs or #refs == 0, 'no refs')
print('PASS')

print('TEST: get_canonical_book returns canonical name')
local canonical = bible.get_canonical_book('Rom')
assert_equal(canonical, 'Romans', 'Rom -> Romans')

canonical = bible.get_canonical_book('Romans')
assert_equal(canonical, 'Romans', 'Romans -> Romans')

canonical = bible.get_canonical_book('1Cor')
assert_equal(canonical, '1 Corinthians', '1Cor -> 1 Corinthians')
print('PASS')

print('TEST: handles numbered books')
refs = bible.extract_refs('Reading 1 John 4:8')
assert_truthy(refs, 'refs exist')
assert_equal(refs[1].book, '1 John', 'book is 1 John')
print('PASS')

print('\nAll tests passed')
vim.cmd('quit')
