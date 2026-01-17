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

print('TEST: get_ref_at_cursor detects Bible reference')
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  'Study notes on John 17:20 today',
})
vim.api.nvim_win_set_buf(0, bufnr)
vim.api.nvim_win_set_cursor(0, {1, 17})

local ref = bible.get_ref_at_cursor()
assert_truthy(ref, 'ref detected')
assert_equal(ref.book, 'John', 'book is John')
assert_equal(ref.chapter, 17, 'chapter is 17')
assert_equal(ref.verse_start, 20, 'verse is 20')
print('PASS')

print('TEST: get_ref_at_cursor returns nil when not on reference')
vim.api.nvim_win_set_cursor(0, {1, 0})
ref = bible.get_ref_at_cursor()
assert_truthy(ref == nil, 'no ref at start of line')
print('PASS')

print('TEST: get_ref_at_cursor detects range reference')
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  'Reading John 17:18-23 passage',
})
vim.api.nvim_win_set_cursor(0, {1, 12})
ref = bible.get_ref_at_cursor()
assert_truthy(ref, 'range ref detected')
assert_equal(ref.verse_start, 18, 'verse_start is 18')
assert_equal(ref.verse_end, 23, 'verse_end is 23')
print('PASS')

print('TEST: get_verse_url generates Bible Gateway URL')
local url = bible.get_verse_url('John', 17, 20, 20, 'ESV')
assert_truthy(url, 'URL generated')
assert_truthy(url:match('biblegateway.com'), 'is Bible Gateway URL')
assert_truthy(url:match('John'), 'contains book')
print('PASS')

print('TEST: get_verse_url handles ranges')
url = bible.get_verse_url('John', 17, 18, 23, 'ESV')
assert_truthy(url:match('18%-23') or url:match('18%-23'), 'contains range')
print('PASS')

vim.api.nvim_buf_delete(bufnr, {force = true})

print('\nAll tests passed')
vim.cmd('quit')
