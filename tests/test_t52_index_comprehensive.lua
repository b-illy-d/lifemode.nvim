local function reset_modules()
  package.loaded['lifemode.index'] = nil
  package.loaded['lifemode.parser'] = nil
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

local index = require('lifemode.index')

local test_dir = vim.fn.tempname()
vim.fn.mkdir(test_dir, 'p')

print('TEST: create returns empty index structure')
local idx = index.create()
assert_truthy(idx.node_locations, 'has node_locations')
assert_truthy(idx.tasks_by_state, 'has tasks_by_state')
assert_truthy(idx.tasks_by_state.todo, 'has todo state')
assert_truthy(idx.tasks_by_state.done, 'has done state')
assert_truthy(idx.nodes_by_date, 'has nodes_by_date')
assert_truthy(idx.backlinks, 'has backlinks')
print('PASS')

print('TEST: add_node stores node location by ID')
idx = index.create()
local node = { type = 'task', id = 'test-id', text = 'Test', state = 'todo', line = 5 }
index.add_node(idx, node, '/test/file.md', 1000)
assert_truthy(idx.node_locations['test-id'], 'location stored')
assert_equal(idx.node_locations['test-id'].file, '/test/file.md', 'file stored')
assert_equal(idx.node_locations['test-id'].line, 5, 'line stored')
print('PASS')

print('TEST: add_node categorizes tasks by state')
idx = index.create()
local todo = { type = 'task', id = 'todo-1', text = 'Todo', state = 'todo', line = 0 }
local done = { type = 'task', id = 'done-1', text = 'Done', state = 'done', line = 1 }
index.add_node(idx, todo, '/test.md', 1000)
index.add_node(idx, done, '/test.md', 1000)
assert_equal(#idx.tasks_by_state.todo, 1, 'one todo task')
assert_equal(#idx.tasks_by_state.done, 1, 'one done task')
print('PASS')

print('TEST: add_node indexes backlinks from wikilinks')
idx = index.create()
node = {
  type = 'list_item',
  id = 'source-node',
  text = 'See [[Target]]',
  line = 0,
  refs = {{ type = 'wikilink', target = 'Target' }},
}
index.add_node(idx, node, '/source.md', 1000)
local backlinks = index.get_backlinks('Target', idx)
assert_equal(#backlinks, 1, 'one backlink')
assert_equal(backlinks[1].source_id, 'source-node', 'correct source')
print('PASS')

print('TEST: add_node indexes backlinks from Bible refs')
idx = index.create()
node = {
  type = 'list_item',
  id = 'bible-ref-node',
  text = 'John 3:16',
  line = 0,
  refs = {{ type = 'bible', verse_ids = {'bible:john:3:16'} }},
}
index.add_node(idx, node, '/notes.md', 1000)
backlinks = index.get_backlinks('bible:john:3:16', idx)
assert_equal(#backlinks, 1, 'one backlink to verse')
print('PASS')

print('TEST: build creates index from vault')
vim.fn.writefile({'- [ ] Task one ^task-1', '- [ ] Task two ^task-2'}, test_dir .. '/tasks.md')
vim.fn.writefile({'## Heading ^head-1'}, test_dir .. '/doc.md')
idx = index.build(test_dir)
assert_truthy(idx.node_locations['task-1'], 'task-1 indexed')
assert_truthy(idx.node_locations['task-2'], 'task-2 indexed')
assert_truthy(idx.node_locations['head-1'], 'head-1 indexed')
assert_equal(#idx.tasks_by_state.todo, 2, 'two tasks')
print('PASS')

print('TEST: get_backlinks returns empty for unknown target')
backlinks = index.get_backlinks('nonexistent', idx)
assert_equal(#backlinks, 0, 'no backlinks')
print('PASS')

print('TEST: nodes without ID use file:line as backlink source')
idx = index.create()
node = {
  type = 'list_item',
  text = 'Link to [[Page]]',
  line = 10,
  refs = {{ type = 'wikilink', target = 'Page' }},
}
index.add_node(idx, node, '/anon.md', 1000)
backlinks = index.get_backlinks('Page', idx)
assert_equal(#backlinks, 1, 'one backlink')
assert_equal(backlinks[1].source_id, '/anon.md:10', 'file:line as source_id')
print('PASS')

vim.fn.delete(test_dir, 'rf')
index._reset_state()

print('\nAll tests passed')
vim.cmd('quit')
