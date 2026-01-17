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

local function assert_truthy(value, label)
  if not value then
    print('FAIL: ' .. label)
    vim.cmd('cq 1')
  end
end

local query = require('lifemode.query')

print('TEST: parse due:today filter')
local filter = query.parse('due:today')
assert_truthy(filter, 'filter parsed')
assert_equal(filter.due, 'today', 'due is today')
print('PASS')

print('TEST: parse state:todo filter')
filter = query.parse('state:todo')
assert_truthy(filter, 'filter parsed')
assert_equal(filter.state, 'todo', 'state is todo')
print('PASS')

print('TEST: parse tag filter')
filter = query.parse('tag:#work')
assert_truthy(filter, 'filter parsed')
assert_equal(filter.tag, 'work', 'tag is work')
print('PASS')

print('TEST: parse multiple filters')
filter = query.parse('state:todo due:today tag:#work')
assert_truthy(filter, 'filter parsed')
assert_equal(filter.state, 'todo', 'state parsed')
assert_equal(filter.due, 'today', 'due parsed')
assert_equal(filter.tag, 'work', 'tag parsed')
print('PASS')

print('TEST: parse priority filter')
filter = query.parse('priority:1')
assert_truthy(filter, 'filter parsed')
assert_equal(filter.priority, 1, 'priority is 1')
print('PASS')

print('TEST: parse type filter')
filter = query.parse('type:task')
assert_truthy(filter, 'filter parsed')
assert_equal(filter.type, 'task', 'type is task')
print('PASS')

print('TEST: empty string returns empty filter')
filter = query.parse('')
assert_truthy(filter, 'filter object returned')
print('PASS')

print('\nAll tests passed')
vim.cmd('quit')
