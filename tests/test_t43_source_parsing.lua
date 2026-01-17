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

print('TEST: parse detects source node from list item with type:: source')
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '- type:: source',
  '  title:: The Art of Code',
  '  author:: John Smith',
  '  year:: 2020',
  '  ^source-1',
})

local blocks = parser.parse_buffer(bufnr)
local found_source = false
for _, b in ipairs(blocks) do
  if b.type == 'source' then
    found_source = true
    assert_equal(b.props.title, 'The Art of Code', 'title extracted')
    assert_equal(b.props.author, 'John Smith', 'author extracted')
    assert_equal(b.props.year, '2020', 'year extracted')
  end
end
assert_truthy(found_source, 'source node found')
vim.api.nvim_buf_delete(bufnr, {force = true})
print('PASS')

print('TEST: source node with url property')
bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '- type:: source',
  '  title:: Online Article',
  '  url:: https://example.com',
  '  ^source-2',
})

blocks = parser.parse_buffer(bufnr)
for _, b in ipairs(blocks) do
  if b.type == 'source' then
    assert_equal(b.props.url, 'https://example.com', 'url extracted')
  end
end
vim.api.nvim_buf_delete(bufnr, {force = true})
print('PASS')

print('TEST: source node with kind property')
bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '- type:: source',
  '  title:: My Book',
  '  kind:: book',
  '  ^source-3',
})

blocks = parser.parse_buffer(bufnr)
for _, b in ipairs(blocks) do
  if b.type == 'source' then
    assert_equal(b.props.kind, 'book', 'kind extracted')
  end
end
vim.api.nvim_buf_delete(bufnr, {force = true})
print('PASS')

print('TEST: non-source list item is not detected as source')
bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '- Regular list item',
  '- [ ] Task item',
})

blocks = parser.parse_buffer(bufnr)
for _, b in ipairs(blocks) do
  assert_truthy(b.type ~= 'source', 'no source in regular content')
end
vim.api.nvim_buf_delete(bufnr, {force = true})
print('PASS')

print('\nAll tests passed')
vim.cmd('quit')
