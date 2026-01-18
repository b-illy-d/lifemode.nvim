local success, lens = pcall(require, 'lifemode.lens')
if not success then
  print('FAIL: Could not load lifemode.lens module')
  print('Error: ' .. tostring(lens))
  vim.cmd('cq 1')
end

local function assert_equal(actual, expected, label)
  if actual ~= expected then
    print('FAIL: ' .. label)
    print('  expected: ' .. tostring(expected))
    print('  got: ' .. tostring(actual))
    vim.cmd('cq 1')
  end
end

local function assert_table_equal(actual, expected, label)
  if type(actual) ~= 'table' or type(expected) ~= 'table' then
    print('FAIL: ' .. label .. ' - not both tables')
    vim.cmd('cq 1')
  end
  if #actual ~= #expected then
    print('FAIL: ' .. label .. ' - length mismatch')
    print('  expected: ' .. #expected)
    print('  got: ' .. #actual)
    vim.cmd('cq 1')
  end
  for i = 1, #expected do
    if actual[i] ~= expected[i] then
      print('FAIL: ' .. label .. ' - element ' .. i .. ' mismatch')
      print('  expected: ' .. tostring(expected[i]))
      print('  got: ' .. tostring(actual[i]))
      vim.cmd('cq 1')
    end
  end
end

print('TEST: task/brief lens renders todo task with metadata')
local task_node = {
  type = 'task',
  id = 'task-1',
  state = 'todo',
  text = 'Write spec',
  priority = 2,
  due = '2026-01-20',
}
local result = lens.render(task_node, 'task/brief')
assert_equal(#result.lines, 1, 'task/brief should produce 1 line')
assert_equal(result.lines[1], '[ ] Write spec !2 @due(2026-01-20)', 'task/brief line content')
print('PASS')

print('TEST: task/brief lens renders done task')
local done_task = {
  type = 'task',
  id = 'task-2',
  state = 'done',
  text = 'Finished task',
}
result = lens.render(done_task, 'task/brief')
assert_equal(result.lines[1], '[x] Finished task', 'done task renders with [x]')
print('PASS')

print('TEST: task/brief highlights done tasks')
result = lens.render(done_task, 'task/brief')
assert_equal(#result.highlights, 1, 'done task should have 1 highlight')
local hl = result.highlights[1]
assert_equal(hl.line, 0, 'highlight line number')
assert_equal(hl.col_start, 0, 'highlight col_start')
assert_equal(hl.col_end, #result.lines[1], 'highlight col_end')
assert_equal(hl.hl_group, 'LifeModeDone', 'highlight group')
print('PASS')

print('TEST: task/brief highlights high priority')
local high_priority_task = {
  type = 'task',
  id = 'task-3',
  state = 'todo',
  text = 'Urgent task',
  priority = 1,
}
result = lens.render(high_priority_task, 'task/brief')
local found_priority_hl = false
for _, hl in ipairs(result.highlights) do
  if hl.hl_group == 'LifeModePriorityHigh' then
    found_priority_hl = true
    break
  end
end
if not found_priority_hl then
  print('FAIL: high priority task should have LifeModePriorityHigh highlight')
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: task/brief highlights low priority')
local low_priority_task = {
  type = 'task',
  id = 'task-4',
  state = 'todo',
  text = 'Low priority task',
  priority = 5,
}
result = lens.render(low_priority_task, 'task/brief')
local found_low_hl = false
for _, hl in ipairs(result.highlights) do
  if hl.hl_group == 'LifeModePriorityLow' then
    found_low_hl = true
    break
  end
end
if not found_low_hl then
  print('FAIL: low priority task should have LifeModePriorityLow highlight')
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: task/brief highlights due date')
local task_with_due = {
  type = 'task',
  id = 'task-5',
  state = 'todo',
  text = 'Task with deadline',
  due = '2026-01-20',
}
result = lens.render(task_with_due, 'task/brief')
local found_due_hl = false
for _, hl in ipairs(result.highlights) do
  if hl.hl_group == 'LifeModeDue' then
    found_due_hl = true
    break
  end
end
if not found_due_hl then
  print('FAIL: task with due date should have LifeModeDue highlight')
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: node/brief lens for notes')
local note_node = {
  type = 'note',
  id = 'note-1',
  content = '# My Thoughts\n\nSome content here.',
}
result = lens.render(note_node, 'node/brief')
assert_equal(#result.lines, 1, 'node/brief should produce 1 line')
if not result.lines[1]:match('My Thoughts') then
  print('FAIL: node/brief should extract title')
  print('  got: ' .. result.lines[1])
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: quote/brief lens')
local quote_node = {
  type = 'quote',
  id = 'quote-1',
  content = '"The greatest challenge of the day..."',
  props = { author = 'Dorothy Day' },
}
result = lens.render(quote_node, 'quote/brief')
assert_equal(#result.lines, 1, 'quote/brief should produce 1 line')
if not result.lines[1]:match('Dorothy Day') then
  print('FAIL: quote/brief should include author')
  print('  got: ' .. result.lines[1])
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: project/brief lens')
local project_node = {
  type = 'project',
  id = 'project-1',
  props = { title = 'Easter Sermon' },
  references = {'note-1', 'quote-1'},
}
result = lens.render(project_node, 'project/brief')
assert_equal(#result.lines, 1, 'project/brief should produce 1 line')
if not result.lines[1]:match('Easter Sermon') then
  print('FAIL: project/brief should show title')
  print('  got: ' .. result.lines[1])
  vim.cmd('cq 1')
end
if not result.lines[1]:match('2 items') then
  print('FAIL: project/brief should show item count')
  print('  got: ' .. result.lines[1])
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: get_available_lenses for task')
local lenses = lens.get_available_lenses('task')
assert_table_equal(lenses, {'task/brief', 'task/detail', 'node/raw'}, 'task lenses')
print('PASS')

print('TEST: get_available_lenses for note')
lenses = lens.get_available_lenses('note')
assert_table_equal(lenses, {'node/brief', 'node/full', 'node/raw'}, 'note lenses')
print('PASS')

print('TEST: get_available_lenses for quote')
lenses = lens.get_available_lenses('quote')
assert_table_equal(lenses, {'quote/brief', 'quote/full', 'node/raw'}, 'quote lenses')
print('PASS')

print('TEST: get_available_lenses for project')
lenses = lens.get_available_lenses('project')
assert_table_equal(lenses, {'project/brief', 'project/expanded', 'node/raw'}, 'project lenses')
print('PASS')

print('\nAll lens tests passed')
vim.cmd('quit')
