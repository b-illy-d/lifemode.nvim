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
  line = 0,
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
  line = 0,
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
  line = 0,
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
  line = 0,
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

print('TEST: node/raw handles heading with level 1')
node = {
  type = 'heading',
  line = 0,
  level = 1,
  text = 'Main Title',
}
result = lens.render(node, 'node/raw')
if result.lines[1] ~= '# Main Title' then
  print('FAIL: heading level 1')
  print('  got: ' .. result.lines[1])
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: node/raw handles heading with level 6')
node = {
  type = 'heading',
  line = 0,
  level = 6,
  text = 'Sub-sub-title',
}
result = lens.render(node, 'node/raw')
if result.lines[1] ~= '###### Sub-sub-title' then
  print('FAIL: heading level 6')
  print('  got: ' .. result.lines[1])
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: node/raw handles list_item')
node = {
  type = 'list_item',
  line = 0,
  text = 'List item text',
}
result = lens.render(node, 'node/raw')
if result.lines[1] ~= '- List item text' then
  print('FAIL: list_item')
  print('  got: ' .. result.lines[1])
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: node/raw handles unknown node type')
node = {
  type = 'unknown',
  line = 0,
  text = 'Unknown content',
}
result = lens.render(node, 'node/raw')
if result.lines[1] ~= 'Unknown content' then
  print('FAIL: unknown node type')
  print('  got: ' .. result.lines[1])
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: node/raw handles node with nil text')
node = {
  type = 'unknown',
  line = 0,
}
result = lens.render(node, 'node/raw')
if result.lines[1] ~= '' then
  print('FAIL: nil text should return empty string')
  print('  got: ' .. result.lines[1])
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: get_available_lenses handles unknown node type')
local lenses = lens.get_available_lenses('unknown_type')
if #lenses ~= 0 then
  print('FAIL: unknown node type should return empty array')
  print('  got: ' .. vim.inspect(lenses))
  vim.cmd('cq 1')
end
print('PASS')

print('TEST: heading/brief handles different heading levels')
for level = 1, 6 do
  node = {
    type = 'heading',
    line = 0,
    level = level,
    text = 'Heading',
  }
  result = lens.render(node, 'heading/brief')
  local expected_hashes = string.rep('#', level)
  local expected_line = expected_hashes .. ' Heading'
  if result.lines[1] ~= expected_line then
    print('FAIL: heading level ' .. level)
    print('  expected: ' .. expected_line)
    print('  got: ' .. result.lines[1])
    vim.cmd('cq 1')
  end
end
print('PASS')

print('\nAll edge case tests passed')
vim.cmd('quit')
