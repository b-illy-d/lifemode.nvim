local function reset_modules()
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

local parser = require('lifemode.parser')

print('TEST: parse detects citation node')
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '- type:: citation',
  '  source:: ^source-1',
  '  pages:: 42-45',
  '  ^cite-1',
})

local blocks = parser.parse_buffer(bufnr)
local found_citation = false
for _, b in ipairs(blocks) do
  if b.type == 'citation' then
    found_citation = true
    assert_equal(b.props.source, '^source-1', 'source ref extracted')
    assert_equal(b.props.pages, '42-45', 'pages extracted')
    assert_equal(b.id, 'cite-1', 'id extracted')
  end
end
assert_truthy(found_citation, 'citation node found')
vim.api.nvim_buf_delete(bufnr, {force = true})
print('PASS')

print('TEST: citation with locator property')
bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '- type:: citation',
  '  source:: ^my-book',
  '  locator:: chapter 3',
  '  ^cite-2',
})

blocks = parser.parse_buffer(bufnr)
for _, b in ipairs(blocks) do
  if b.type == 'citation' then
    assert_equal(b.props.locator, 'chapter 3', 'locator extracted')
  end
end
vim.api.nvim_buf_delete(bufnr, {force = true})
print('PASS')

print('TEST: citation text can include note')
bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '- type:: citation',
  '  source:: ^ref-1',
  '  note:: Key insight about the topic',
  '  ^cite-3',
})

blocks = parser.parse_buffer(bufnr)
for _, b in ipairs(blocks) do
  if b.type == 'citation' then
    assert_equal(b.props.note, 'Key insight about the topic', 'note extracted')
  end
end
vim.api.nvim_buf_delete(bufnr, {force = true})
print('PASS')

print('TEST: regular list item is not citation')
bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '- Regular list item',
  '- [ ] Task item',
})

blocks = parser.parse_buffer(bufnr)
for _, b in ipairs(blocks) do
  assert_truthy(b.type ~= 'citation', 'no citation in regular content')
end
vim.api.nvim_buf_delete(bufnr, {force = true})
print('PASS')

print('\nAll tests passed')
vim.cmd('quit')
