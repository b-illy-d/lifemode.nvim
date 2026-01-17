local function reset_modules()
  package.loaded['lifemode.query'] = nil
  package.loaded['lifemode.views.tasks'] = nil
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

local function count_tasks_in_tree(tree)
  local count = 0
  for _, group in ipairs(tree.root_instances or {}) do
    if group.children then
      count = count + #group.children
    end
  end
  return count
end

local query = require('lifemode.query')
local tasks_view = require('lifemode.views.tasks')

local mock_index = {
  tasks_by_state = {
    todo = {
      { id = 'task1', type = 'task', state = 'todo', text = 'Buy milk', due = '2026-01-17', priority = 1, tags = {'shopping'}, _file = 'test.md' },
      { id = 'task2', type = 'task', state = 'todo', text = 'Write report', due = '2026-01-18', priority = 2, tags = {'work'}, _file = 'test.md' },
      { id = 'task3', type = 'task', state = 'todo', text = 'Review PR', priority = 3, tags = {'work'}, _file = 'test.md' },
      { id = 'task4', type = 'task', state = 'todo', text = 'Call mom', tags = {'family'}, _file = 'test.md' },
    },
    done = {},
  },
}

print('TEST: build_tree without filter returns all tasks')
tasks_view._reset_counter()
local tree = tasks_view.build_tree(mock_index)
assert_equal(count_tasks_in_tree(tree), 4, 'all 4 tasks included')
print('PASS')

print('TEST: build_tree with tag filter')
tasks_view._reset_counter()
local filter = query.parse('tag:#work')
tree = tasks_view.build_tree(mock_index, { filter = filter })
assert_equal(count_tasks_in_tree(tree), 2, 'only 2 work tasks')
print('PASS')

print('TEST: build_tree with priority filter')
tasks_view._reset_counter()
filter = query.parse('priority:1')
tree = tasks_view.build_tree(mock_index, { filter = filter })
assert_equal(count_tasks_in_tree(tree), 1, 'only 1 priority 1 task')
print('PASS')

print('TEST: filter combined with grouping')
tasks_view._reset_counter()
filter = query.parse('tag:#work')
tree = tasks_view.build_tree(mock_index, { filter = filter, grouping = 'by_priority' })
assert_equal(count_tasks_in_tree(tree), 2, 'still 2 work tasks')
assert_equal(tree.grouping, 'by_priority', 'grouping preserved')
print('PASS')

print('TEST: filter with no matches returns empty tree')
tasks_view._reset_counter()
filter = query.parse('tag:#nonexistent')
tree = tasks_view.build_tree(mock_index, { filter = filter })
assert_equal(count_tasks_in_tree(tree), 0, 'no tasks matched')
print('PASS')

print('\nAll tests passed')
vim.cmd('quit')
