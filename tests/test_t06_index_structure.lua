local index = require('lifemode.index')

local idx = index.create()

if type(idx) ~= 'table' then
  print('FAIL: create() should return table, got ' .. type(idx))
  vim.cmd('cq 1')
end

if type(idx.nodes) ~= 'table' then
  print('FAIL: nodes should be table')
  vim.cmd('cq 1')
end

if type(idx.nodes_by_type) ~= 'table' then
  print('FAIL: nodes_by_type should be table')
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

if type(idx.backlinks) ~= 'table' then
  print('FAIL: backlinks should be table')
  vim.cmd('cq 1')
end

local test_node = {
  type = 'task',
  text = 'Test task',
  state = 'todo',
  id = 'test-id-123',
  priority = 2,
  due = '2026-01-20',
  tags = {'work'},
  created = '2026-01-15',
}

local result = index.add_node(idx, test_node, '/test/file.md', 1705363200)

if result ~= idx then
  print('FAIL: add_node should return index')
  vim.cmd('cq 1')
end

if idx.nodes['test-id-123'] == nil then
  print('FAIL: nodes should contain added node')
  vim.cmd('cq 1')
end

local node = idx.nodes['test-id-123']
if node._file ~= '/test/file.md' then
  print('FAIL: node _file incorrect')
  vim.cmd('cq 1')
end

if node._mtime ~= 1705363200 then
  print('FAIL: node _mtime incorrect')
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

local date_str = '2026-01-15'
if idx.nodes_by_date[date_str] == nil then
  print('FAIL: nodes_by_date should have entry for created date')
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
  print('FAIL: node should be in nodes_by_date for its created date')
  vim.cmd('cq 1')
end

local note_node = {
  type = 'note',
  id = 'note-id-456',
  content = '# Test note',
  created = '2026-01-15',
}

index.add_node(idx, note_node, '/test/note.md', 1705363200)

if #idx.nodes_by_date[date_str] ~= 2 then
  print('FAIL: nodes_by_date should contain both nodes for same date')
  vim.cmd('cq 1')
end

if #idx.tasks_by_state.todo ~= 1 then
  print('FAIL: tasks_by_state.todo should only contain tasks')
  vim.cmd('cq 1')
end

if #(idx.nodes_by_type['task'] or {}) ~= 1 then
  print('FAIL: nodes_by_type should have 1 task')
  vim.cmd('cq 1')
end

if #(idx.nodes_by_type['note'] or {}) ~= 1 then
  print('FAIL: nodes_by_type should have 1 note')
  vim.cmd('cq 1')
end

print('PASS: Index structure and add_node work correctly')
vim.cmd('quit')
