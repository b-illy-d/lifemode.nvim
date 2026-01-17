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
  line = 5,
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
  line = 10,
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
  line = 0,
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
  line = 0,
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
  line = 0,
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

print('TEST: node/raw lens returns raw markdown')
local heading_node = {
  type = 'heading',
  line = 0,
  level = 2,
  text = 'Section Title',
}
result = lens.render(heading_node, 'node/raw')
assert_equal(result.lines[1], '## Section Title', 'raw heading preserves format')
assert_equal(#result.highlights, 0, 'raw lens has no highlights')
print('PASS')

print('TEST: node/raw lens for tasks')
local task_for_raw = {
  type = 'task',
  line = 0,
  state = 'todo',
  text = 'Original task',
}
result = lens.render(task_for_raw, 'node/raw')
assert_equal(result.lines[1], '- [ ] Original task', 'raw task format')
print('PASS')

print('TEST: heading/brief lens')
result = lens.render(heading_node, 'heading/brief')
assert_equal(result.lines[1], '## Section Title', 'heading/brief preserves format')
assert_equal(#result.highlights, 1, 'heading should have 1 highlight')
assert_equal(result.highlights[1].hl_group, 'LifeModeHeading', 'heading highlight group')
print('PASS')

print('TEST: get_available_lenses for task')
local lenses = lens.get_available_lenses('task')
assert_table_equal(lenses, {'task/brief', 'node/raw'}, 'task lenses')
print('PASS')

print('TEST: get_available_lenses for heading')
lenses = lens.get_available_lenses('heading')
assert_table_equal(lenses, {'heading/brief', 'node/raw'}, 'heading lenses')
print('PASS')

print('TEST: get_available_lenses for list_item')
lenses = lens.get_available_lenses('list_item')
assert_table_equal(lenses, {'node/raw'}, 'list_item lenses')
print('PASS')

print('\nAll tests passed')
vim.cmd('quit')
