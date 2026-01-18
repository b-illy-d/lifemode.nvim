local success, lens = pcall(require, 'lifemode.lens')
if not success then
  print('FAIL: Could not load lifemode.lens module')
  print('Error: ' .. tostring(lens))
  vim.cmd('cq 1')
end

local function test_error(description, fn, expected_error_pattern)
  local success, err = pcall(fn)
  if success then
    print('FAIL: ' .. description .. ' - expected error but succeeded')
    vim.cmd('cq 1')
  end
  if not string.match(err, expected_error_pattern) then
    print('FAIL: ' .. description .. ' - wrong error message')
    print('  expected pattern: ' .. expected_error_pattern)
    print('  got: ' .. err)
    vim.cmd('cq 1')
  end
  print('PASS: ' .. description)
end

print('TEST: render requires node parameter')
test_error('missing node', function()
  lens.render(nil, 'task/brief')
end, 'node is required')

print('TEST: render requires lens_name parameter')
test_error('missing lens_name', function()
  lens.render({type = 'task'}, nil)
end, 'lens_name is required')

print('TEST: render rejects unknown lens')
test_error('unknown lens', function()
  lens.render({type = 'task', text = 'Test'}, 'unknown/lens')
end, 'Unknown lens')

print('TEST: task/brief handles nil priority')
local node = {
  type = 'task',
  id = 'task-1',
  state = 'todo',
  text = 'Task without priority',
}
local result = lens.render(node, 'task/brief')
if result.lines[1] ~= '[ ] Task without priority' then
  print('FAIL: task without priority')
  print('  expected: [ ] Task without priority')
  print('  got: ' .. result.lines[1])
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: task/brief handles nil due date')
node = {
  type = 'task',
  id = 'task-2',
  state = 'todo',
  text = 'Task without due',
}
result = lens.render(node, 'task/brief')
if result.lines[1] ~= '[ ] Task without due' then
  print('FAIL: task without due')
  print('  got: ' .. result.lines[1])
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: task/brief handles priority 3 (no highlight)')
node = {
  type = 'task',
  id = 'task-3',
  state = 'todo',
  text = 'Normal priority',
  priority = 3,
}
result = lens.render(node, 'task/brief')
if result.lines[1] ~= '[ ] Normal priority !3' then
  print('FAIL: priority 3 line')
  print('  got: ' .. result.lines[1])
  vim.cmd('cq 1')
end
local has_priority_hl = false
for _, hl in ipairs(result.highlights) do
  if hl.hl_group == 'LifeModePriorityHigh' or hl.hl_group == 'LifeModePriorityLow' then
    has_priority_hl = true
    break
  end
end
if has_priority_hl then
  print('FAIL: priority 3 should not have high/low highlight')
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: done task overrides all other highlights')
node = {
  type = 'task',
  id = 'task-4',
  state = 'done',
  text = 'Completed',
  priority = 1,
  due = '2026-01-20',
}
result = lens.render(node, 'task/brief')
if #result.highlights ~= 1 then
  print('FAIL: done task should have exactly 1 highlight')
  print('  got: ' .. #result.highlights)
  vim.cmd('cq 1')
end
if result.highlights[1].hl_group ~= 'LifeModeDone' then
  print('FAIL: done task should only have LifeModeDone highlight')
  print('  got: ' .. result.highlights[1].hl_group)
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: node/brief handles note without title')
node = {
  type = 'note',
  id = 'note-1',
  content = 'Just some text without a heading',
}
result = lens.render(node, 'node/brief')
if #result.lines ~= 1 then
  print('FAIL: node/brief should produce 1 line')
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: node/brief handles empty content')
node = {
  type = 'note',
  id = 'note-2',
  content = '',
}
result = lens.render(node, 'node/brief')
if #result.lines ~= 1 then
  print('FAIL: node/brief with empty content should produce 1 line')
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: node/full handles multiline content')
node = {
  type = 'note',
  id = 'note-3',
  content = 'Line 1\nLine 2\nLine 3',
}
result = lens.render(node, 'node/full')
if #result.lines ~= 3 then
  print('FAIL: node/full should have 3 lines')
  print('  got: ' .. #result.lines)
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: quote/brief handles quote without author')
node = {
  type = 'quote',
  id = 'quote-1',
  content = '"Some wisdom here"',
  props = {},
}
result = lens.render(node, 'quote/brief')
if #result.lines ~= 1 then
  print('FAIL: quote/brief should produce 1 line')
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: project/brief handles empty references')
node = {
  type = 'project',
  id = 'project-1',
  props = { title = 'Empty Project' },
  references = {},
}
result = lens.render(node, 'project/brief')
if not result.lines[1]:match('0 items') then
  print('FAIL: project/brief should show 0 items')
  print('  got: ' .. result.lines[1])
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: project/brief handles nil references')
node = {
  type = 'project',
  id = 'project-2',
  props = { title = 'No Refs Project' },
}
result = lens.render(node, 'project/brief')
if not result.lines[1]:match('0 items') then
  print('FAIL: project/brief should handle nil references')
  print('  got: ' .. result.lines[1])
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: get_available_lenses handles unknown node type')
local lenses = lens.get_available_lenses('unknown_type')
if #lenses ~= 2 then
  print('FAIL: unknown node type should return default lenses')
  print('  got: ' .. vim.inspect(lenses))
  vim.cmd('cq 1')
end
print('PASS')

print('\nAll edge case tests passed')
vim.cmd('quit')
