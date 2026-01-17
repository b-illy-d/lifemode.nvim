local function reset_modules()
  package.loaded['lifemode.views.daily'] = nil
  package.loaded['lifemode.views.tasks'] = nil
  package.loaded['lifemode.index'] = nil
  package.loaded['lifemode.lens'] = nil
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

local function assert_contains(lines, pattern, label)
  for _, line in ipairs(lines) do
    if line:match(pattern) then return end
  end
  print('FAIL: ' .. label)
  print('  expected pattern: ' .. pattern)
  print('  in lines: ' .. vim.inspect(lines))
  vim.cmd('cq 1')
end

local daily = require('lifemode.views.daily')
local tasks = require('lifemode.views.tasks')

print('TEST: daily view groups nodes by date')
daily._reset_counter()
local mock_index = {
  nodes_by_date = {
    ['2026-01-15'] = {
      { node = { type = 'task', id = 't1', text = 'Task 1', state = 'todo' }, file = 'a.md' },
    },
    ['2026-01-16'] = {
      { node = { type = 'task', id = 't2', text = 'Task 2', state = 'todo' }, file = 'b.md' },
    },
  },
  tasks_by_state = { todo = {}, done = {} },
}
local tree = daily.build_tree(mock_index)
assert_truthy(tree.root_instances, 'has root instances')
assert_truthy(#tree.root_instances > 0, 'has year groups')
print('PASS')

print('TEST: daily view renders to lines')
local output = daily.render(tree)
assert_truthy(output.lines, 'has lines')
assert_truthy(#output.lines > 0, 'rendered lines')
assert_truthy(output.spans, 'has spans')
assert_truthy(output.highlights, 'has highlights')
print('PASS')

print('TEST: tasks view builds tree with groupings')
tasks._reset_counter()
mock_index = {
  tasks_by_state = {
    todo = {
      { id = 't1', type = 'task', state = 'todo', text = 'Task 1', priority = 1, _file = 'a.md' },
      { id = 't2', type = 'task', state = 'todo', text = 'Task 2', priority = 2, _file = 'b.md' },
    },
    done = {},
  },
}
tree = tasks.build_tree(mock_index, { grouping = 'by_priority' })
assert_equal(tree.grouping, 'by_priority', 'grouping is by_priority')
print('PASS')

print('TEST: tasks view renders groups with children')
tasks._reset_counter()
tree = tasks.build_tree(mock_index, { grouping = 'by_priority' })
output = tasks.render(tree)
assert_truthy(#output.lines > 0, 'has lines')
assert_contains(output.lines, 'Priority', 'has priority group')
print('PASS')

print('TEST: tasks view filters with query')
tasks._reset_counter()
mock_index = {
  tasks_by_state = {
    todo = {
      { id = 't1', type = 'task', state = 'todo', text = 'Task 1', priority = 1, tags = {'work'}, _file = 'a.md' },
      { id = 't2', type = 'task', state = 'todo', text = 'Task 2', priority = 2, tags = {'home'}, _file = 'b.md' },
    },
    done = {},
  },
}
tree = tasks.build_tree(mock_index, { filter = { tag = 'work' } })
local task_count = 0
for _, group in ipairs(tree.root_instances) do
  task_count = task_count + (group.children and #group.children or 0)
end
assert_equal(task_count, 1, 'filtered to 1 task')
print('PASS')

print('TEST: lens renders task correctly')
local lens = require('lifemode.lens')
local node = { type = 'task', state = 'todo', text = 'Test task', priority = 2, due = '2026-01-20' }
local result = lens.render(node, 'task/brief')
assert_truthy(result.lines, 'has lines')
assert_contains(result.lines, '%[ %]', 'has checkbox')
assert_contains(result.lines, 'Test task', 'has text')
print('PASS')

print('TEST: lens cycles through available')
local available = lens.get_available_lenses('task')
assert_truthy(#available >= 2, 'task has multiple lenses')
local current = 'task/brief'
local next_lens = lens.cycle(current, 'task', 1)
assert_truthy(next_lens ~= current or #available == 1, 'cycled to different lens')
print('PASS')

print('\nAll tests passed')
vim.cmd('quit')
