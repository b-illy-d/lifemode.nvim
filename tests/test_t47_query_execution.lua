local function reset_modules()
  package.loaded['lifemode.query'] = nil
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

local query = require('lifemode.query')

local nodes = {
  { id = 'task1', type = 'task', state = 'todo', text = 'Buy milk', due = 'today', priority = 1, tags = {'shopping'} },
  { id = 'task2', type = 'task', state = 'done', text = 'Call mom', tags = {'family'} },
  { id = 'task3', type = 'task', state = 'todo', text = 'Write report', due = 'tomorrow', priority = 2, tags = {'work'} },
  { id = 'heading1', type = 'heading', text = 'Projects', level = 1 },
  { id = 'task4', type = 'task', state = 'todo', text = 'Review PR', tags = {'work'} },
}

print('TEST: filter by state')
local filter = { state = 'todo' }
local results = query.execute(filter, nodes)
assert_equal(#results, 3, 'found 3 todo tasks')
print('PASS')

print('TEST: filter by type')
filter = { type = 'task' }
results = query.execute(filter, nodes)
assert_equal(#results, 4, 'found 4 tasks')
print('PASS')

print('TEST: filter by due')
filter = { due = 'today' }
results = query.execute(filter, nodes)
assert_equal(#results, 1, 'found 1 task due today')
assert_equal(results[1].id, 'task1', 'correct task')
print('PASS')

print('TEST: filter by priority')
filter = { priority = 1 }
results = query.execute(filter, nodes)
assert_equal(#results, 1, 'found 1 priority 1 task')
assert_equal(results[1].id, 'task1', 'correct task')
print('PASS')

print('TEST: filter by tag')
filter = { tag = 'work' }
results = query.execute(filter, nodes)
assert_equal(#results, 2, 'found 2 work tasks')
print('PASS')

print('TEST: multiple filters (AND)')
filter = { state = 'todo', tag = 'work' }
results = query.execute(filter, nodes)
assert_equal(#results, 2, 'found 2 todo work tasks')
print('PASS')

print('TEST: empty filter returns all')
filter = {}
results = query.execute(filter, nodes)
assert_equal(#results, 5, 'returns all nodes')
print('PASS')

print('\nAll tests passed')
vim.cmd('quit')
