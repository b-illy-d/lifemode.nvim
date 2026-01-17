local index = require('lifemode.index')

local idx = index.create()

if type(idx) ~= 'table' then
  print('FAIL: create() should return table, got ' .. type(idx))
  vim.cmd('cq 1')
end

if type(idx.node_locations) ~= 'table' then
  print('FAIL: node_locations should be table')
  vim.cmd('cq 1')
end

if type(idx.tasks_by_state) ~= 'table' then
  print('FAIL: tasks_by_state should be table')
  vim.cmd('cq 1')
end

if type(idx.tasks_by_state.todo) ~= 'table' then
  print('FAIL: tasks_by_state.todo should be table')
  vim.cmd('cq 1')
end

if type(idx.tasks_by_state.done) ~= 'table' then
  print('FAIL: tasks_by_state.done should be table')
  vim.cmd('cq 1')
end

if type(idx.nodes_by_date) ~= 'table' then
  print('FAIL: nodes_by_date should be table')
  vim.cmd('cq 1')
end

local test_node = {
  type = 'task',
  line = 0,
  text = 'Test task',
  state = 'todo',
  id = 'test-id-123',
  priority = 2,
  due = '2026-01-20',
  tags = {'work'}
}

local result = index.add_node(idx, test_node, '/test/file.md', 1705363200)

if result ~= idx then
  print('FAIL: add_node should return index')
  vim.cmd('cq 1')
end

if idx.node_locations['test-id-123'] == nil then
  print('FAIL: node_locations should contain added node')
  vim.cmd('cq 1')
end

local loc = idx.node_locations['test-id-123']
if loc.file ~= '/test/file.md' then
  print('FAIL: node location file incorrect')
  vim.cmd('cq 1')
end

if loc.line ~= 0 then
  print('FAIL: node location line incorrect')
  vim.cmd('cq 1')
end

if loc.mtime ~= 1705363200 then
  print('FAIL: node location mtime incorrect')
  vim.cmd('cq 1')
end

local found_in_todo = false
for _, task in ipairs(idx.tasks_by_state.todo) do
  if task.id == 'test-id-123' then
    found_in_todo = true
    break
  end
end

if not found_in_todo then
  print('FAIL: task should be in tasks_by_state.todo')
  vim.cmd('cq 1')
end

local date_str = os.date('%Y-%m-%d', 1705363200)
if idx.nodes_by_date[date_str] == nil then
  print('FAIL: nodes_by_date should have entry for date')
  vim.cmd('cq 1')
end

local found_in_date = false
for _, entry in ipairs(idx.nodes_by_date[date_str]) do
  if entry.id == 'test-id-123' then
    found_in_date = true
    break
  end
end

if not found_in_date then
  print('FAIL: node should be in nodes_by_date for its mtime date')
  vim.cmd('cq 1')
end

local heading_node = {
  type = 'heading',
  line = 5,
  level = 1,
  text = 'Test heading',
  id = 'heading-id-456'
}

index.add_node(idx, heading_node, '/test/file.md', 1705363200)

if #idx.nodes_by_date[date_str] ~= 2 then
  print('FAIL: nodes_by_date should contain both nodes for same date')
  vim.cmd('cq 1')
end

if #idx.tasks_by_state.todo ~= 1 then
  print('FAIL: tasks_by_state.todo should only contain tasks')
  vim.cmd('cq 1')
end

local node_without_id = {
  type = 'list_item',
  line = 10,
  text = 'No ID item'
}

index.add_node(idx, node_without_id, '/test/file.md', 1705363200)

if #idx.nodes_by_date[date_str] ~= 3 then
  print('FAIL: nodes_by_date should contain all nodes (with or without IDs)')
  vim.cmd('cq 1')
end

print('PASS: Index structure and add_node work correctly')
vim.cmd('quit')
