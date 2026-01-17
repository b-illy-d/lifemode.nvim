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

local test_dir = vim.fn.tempname()
vim.fn.mkdir(test_dir, 'p')

print('TEST: empty file returns empty list')
local test_file = test_dir .. '/empty.md'
vim.fn.writefile({}, test_file)
local blocks = parser.parse_file(test_file)
assert_equal(#blocks, 0, 'empty file has no blocks')
print('PASS')

print('TEST: file with only whitespace')
test_file = test_dir .. '/whitespace.md'
vim.fn.writefile({'', '   ', '\t', ''}, test_file)
blocks = parser.parse_file(test_file)
assert_equal(#blocks, 0, 'whitespace-only file has no blocks')
print('PASS')

print('TEST: heading levels 1-6')
test_file = test_dir .. '/headings.md'
vim.fn.writefile({
  '# H1',
  '## H2',
  '### H3',
  '#### H4',
  '##### H5',
  '###### H6',
}, test_file)
blocks = parser.parse_file(test_file)
assert_equal(#blocks, 6, 'found 6 headings')
assert_equal(blocks[1].level, 1, 'first is level 1')
assert_equal(blocks[6].level, 6, 'sixth is level 6')
print('PASS')

print('TEST: task with all metadata')
test_file = test_dir .. '/full_task.md'
vim.fn.writefile({
  '- [ ] Do thing !1 @due(2026-01-20) #work #urgent ^task-id',
}, test_file)
blocks = parser.parse_file(test_file)
assert_equal(#blocks, 1, 'found 1 task')
assert_equal(blocks[1].type, 'task', 'type is task')
assert_equal(blocks[1].state, 'todo', 'state is todo')
assert_equal(blocks[1].priority, 1, 'priority is 1')
assert_equal(blocks[1].due, '2026-01-20', 'due date parsed')
assert_truthy(blocks[1].tags, 'has tags')
assert_equal(#blocks[1].tags, 2, 'has 2 tags')
assert_equal(blocks[1].id, 'task-id', 'id parsed')
print('PASS')

print('TEST: done task')
test_file = test_dir .. '/done_task.md'
vim.fn.writefile({'- [x] Completed task'}, test_file)
blocks = parser.parse_file(test_file)
assert_equal(blocks[1].state, 'done', 'state is done')
print('PASS')

print('TEST: uppercase X in done task')
test_file = test_dir .. '/done_upper.md'
vim.fn.writefile({'- [X] Done with uppercase'}, test_file)
blocks = parser.parse_file(test_file)
assert_equal(blocks[1].state, 'done', 'uppercase X is done')
print('PASS')

print('TEST: source node with properties')
test_file = test_dir .. '/source.md'
vim.fn.writefile({
  '- type:: source',
  '  author:: John Doe',
  '  year:: 2024',
  '  title:: My Book',
}, test_file)
blocks = parser.parse_file(test_file)
assert_equal(#blocks, 1, 'found 1 source')
assert_equal(blocks[1].type, 'source', 'type is source')
assert_equal(blocks[1].props.author, 'John Doe', 'author parsed')
assert_equal(blocks[1].props.year, '2024', 'year parsed')
assert_equal(blocks[1].props.title, 'My Book', 'title parsed')
print('PASS')

print('TEST: citation node with properties')
test_file = test_dir .. '/citation.md'
vim.fn.writefile({
  '- type:: citation',
  '  source:: doe2024',
  '  pages:: 42-45',
}, test_file)
blocks = parser.parse_file(test_file)
assert_equal(#blocks, 1, 'found 1 citation')
assert_equal(blocks[1].type, 'citation', 'type is citation')
assert_equal(blocks[1].props.source, 'doe2024', 'source parsed')
assert_equal(blocks[1].props.pages, '42-45', 'pages parsed')
print('PASS')

print('TEST: wikilinks in text')
test_file = test_dir .. '/wikilinks.md'
vim.fn.writefile({'- Item with [[Page]] and [[Other#heading]]'}, test_file)
blocks = parser.parse_file(test_file)
assert_truthy(blocks[1].refs, 'has refs')
assert_equal(#blocks[1].refs, 2, 'found 2 refs')
assert_equal(blocks[1].refs[1].target, 'Page', 'first target')
assert_equal(blocks[1].refs[2].target, 'Other#heading', 'second target')
print('PASS')

print('TEST: ID with colons and underscores')
test_file = test_dir .. '/complex_id.md'
vim.fn.writefile({'## Heading ^my_complex:id-here'}, test_file)
blocks = parser.parse_file(test_file)
assert_equal(blocks[1].id, 'my_complex:id-here', 'complex ID parsed')
print('PASS')

print('TEST: malformed task (missing space) becomes list item')
test_file = test_dir .. '/malformed.md'
vim.fn.writefile({'- []Missing space'}, test_file)
blocks = parser.parse_file(test_file)
assert_equal(blocks[1].type, 'list_item', 'treated as list item')
print('PASS')

vim.fn.delete(test_dir, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
