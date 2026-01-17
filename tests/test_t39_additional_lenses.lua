local function reset_modules()
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

local lens = require('lifemode.lens')

print('TEST: task/detail lens renders full metadata')
local node = {
  type = 'task',
  state = 'todo',
  text = 'Important task',
  priority = 1,
  due = '2026-01-20',
  tags = {'work', 'urgent'},
}

local result = lens.render(node, 'task/detail')
assert_truthy(result.lines, 'has lines')
assert_truthy(#result.lines >= 1, 'at least one line')

local full_text = table.concat(result.lines, '\n')
assert_truthy(full_text:match('Important task'), 'contains text')
assert_truthy(full_text:match('!1'), 'contains priority')
assert_truthy(full_text:match('2026%-01%-20'), 'contains due date')
assert_truthy(full_text:match('#work'), 'contains work tag')
assert_truthy(full_text:match('#urgent'), 'contains urgent tag')
print('PASS')

print('TEST: task/detail lens handles task without metadata')
node = {
  type = 'task',
  state = 'todo',
  text = 'Simple task',
}

result = lens.render(node, 'task/detail')
assert_truthy(result.lines, 'has lines')
local text = table.concat(result.lines, '\n')
assert_truthy(text:match('Simple task'), 'contains text')
print('PASS')

print('TEST: task/detail shows done state clearly')
node = {
  type = 'task',
  state = 'done',
  text = 'Completed task',
}

result = lens.render(node, 'task/detail')
local text = table.concat(result.lines, '\n')
assert_truthy(text:match('%[x%]') or text:match('done'), 'shows done state')
print('PASS')

print('TEST: task/detail lens is in available lenses')
local available = lens.get_available_lenses('task')
assert_truthy(vim.tbl_contains(available, 'task/detail'), 'task/detail available')
print('PASS')

print('\nAll tests passed')
vim.cmd('quit')
