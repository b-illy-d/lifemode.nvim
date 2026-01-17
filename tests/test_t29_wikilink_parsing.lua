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

print('TEST: parse extracts simple wikilinks')
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '# Heading with [[Page Link]]',
})

local blocks = parser.parse_buffer(bufnr)
assert_truthy(blocks[1], 'block exists')
assert_truthy(blocks[1].refs, 'refs exists')
assert_equal(#blocks[1].refs, 1, 'one ref')
assert_equal(blocks[1].refs[1].type, 'wikilink', 'ref type is wikilink')
assert_equal(blocks[1].refs[1].target, 'Page Link', 'target is Page Link')
vim.api.nvim_buf_delete(bufnr, {force = true})
print('PASS')

print('TEST: parse extracts wikilink with heading')
bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '- [ ] Task with [[Page#Section]] reference',
})

blocks = parser.parse_buffer(bufnr)
assert_truthy(blocks[1].refs, 'refs exists')
assert_equal(blocks[1].refs[1].target, 'Page#Section', 'target includes heading')
vim.api.nvim_buf_delete(bufnr, {force = true})
print('PASS')

print('TEST: parse extracts wikilink with block ID')
bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '- [ ] Task linking to [[Page^block-123]]',
})

blocks = parser.parse_buffer(bufnr)
assert_truthy(blocks[1].refs, 'refs exists')
assert_equal(blocks[1].refs[1].target, 'Page^block-123', 'target includes block ID')
vim.api.nvim_buf_delete(bufnr, {force = true})
print('PASS')

print('TEST: parse extracts multiple wikilinks')
bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '# Links to [[Page One]] and [[Page Two]]',
})

blocks = parser.parse_buffer(bufnr)
assert_equal(#blocks[1].refs, 2, 'two refs')
assert_equal(blocks[1].refs[1].target, 'Page One', 'first target')
assert_equal(blocks[1].refs[2].target, 'Page Two', 'second target')
vim.api.nvim_buf_delete(bufnr, {force = true})
print('PASS')

print('TEST: wikilink with display text')
bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '# Link with [[Page|custom display]]',
})

blocks = parser.parse_buffer(bufnr)
assert_truthy(blocks[1].refs, 'refs exists')
assert_equal(blocks[1].refs[1].target, 'Page', 'target is Page')
assert_equal(blocks[1].refs[1].display, 'custom display', 'display text extracted')
vim.api.nvim_buf_delete(bufnr, {force = true})
print('PASS')

print('TEST: no refs for lines without wikilinks')
bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '# Plain heading without links',
})

blocks = parser.parse_buffer(bufnr)
assert_truthy(not blocks[1].refs or #blocks[1].refs == 0, 'no refs')
vim.api.nvim_buf_delete(bufnr, {force = true})
print('PASS')

print('\nAll tests passed')
vim.cmd('quit')
