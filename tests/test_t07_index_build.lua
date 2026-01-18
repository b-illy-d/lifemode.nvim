local index = require('lifemode.index')
local vault = require('lifemode.vault')

vim.fn.delete('test_vault_t07', 'rf')
vim.fn.mkdir('test_vault_t07/tasks', 'p')
vim.fn.mkdir('test_vault_t07/notes', 'p')

vim.fn.writefile({
  'type:: task',
  'id:: task-1',
  'created:: 2026-01-15',
  '',
  '- [ ] Task one !2 @due(2026-01-20) #work',
}, 'test_vault_t07/tasks/task-1.md')

vim.fn.writefile({
  'type:: task',
  'id:: task-2',
  'created:: 2026-01-15',
  '',
  '- [x] Task two',
}, 'test_vault_t07/tasks/task-2.md')

vim.fn.writefile({
  'type:: task',
  'id:: task-3',
  'created:: 2026-01-16',
  '',
  '- [ ] Another task !3 #personal',
}, 'test_vault_t07/tasks/task-3.md')

vim.fn.writefile({
  'type:: note',
  'id:: note-1',
  'created:: 2026-01-15',
  '',
  '# My Notes',
  '',
  'Some content here.',
}, 'test_vault_t07/notes/note-1.md')

local success, idx = pcall(index.build, 'test_vault_t07')

if not success then
  print('FAIL: index.build errored: ' .. idx)
  vim.fn.delete('test_vault_t07', 'rf')
  vim.cmd('cq 1')
end

if type(idx) ~= 'table' then
  print('FAIL: build should return index table')
  vim.fn.delete('test_vault_t07', 'rf')
  vim.cmd('cq 1')
end

if idx.nodes['task-1'] == nil then
  print('FAIL: task-1 should be in nodes')
  vim.fn.delete('test_vault_t07', 'rf')
  vim.cmd('cq 1')
end

if not idx.nodes['task-1']._file:match('task%-1%.md$') then
  print('FAIL: task-1 file path incorrect')
  vim.fn.delete('test_vault_t07', 'rf')
  vim.cmd('cq 1')
end

if idx.nodes['task-2'] == nil then
  print('FAIL: task-2 should be in nodes')
  vim.fn.delete('test_vault_t07', 'rf')
  vim.cmd('cq 1')
end

if idx.nodes['note-1'] == nil then
  print('FAIL: note-1 should be in nodes')
  vim.fn.delete('test_vault_t07', 'rf')
  vim.cmd('cq 1')
end

if #idx.tasks_by_state.todo ~= 2 then
  print('FAIL: tasks_by_state.todo should have 2 tasks, got ' .. #idx.tasks_by_state.todo)
  vim.fn.delete('test_vault_t07', 'rf')
  vim.cmd('cq 1')
end

if #idx.tasks_by_state.done ~= 1 then
  print('FAIL: tasks_by_state.done should have 1 task, got ' .. #idx.tasks_by_state.done)
  vim.fn.delete('test_vault_t07', 'rf')
  vim.cmd('cq 1')
end

local has_dates = false
for date_str, nodes in pairs(idx.nodes_by_date) do
  if #nodes > 0 then
    has_dates = true
    break
  end
end

if not has_dates then
  print('FAIL: nodes_by_date should have entries')
  vim.fn.delete('test_vault_t07', 'rf')
  vim.cmd('cq 1')
end

if #(idx.nodes_by_type['task'] or {}) ~= 3 then
  print('FAIL: nodes_by_type should have 3 tasks, got ' .. #(idx.nodes_by_type['task'] or {}))
  vim.fn.delete('test_vault_t07', 'rf')
  vim.cmd('cq 1')
end

if #(idx.nodes_by_type['note'] or {}) ~= 1 then
  print('FAIL: nodes_by_type should have 1 note, got ' .. #(idx.nodes_by_type['note'] or {}))
  vim.fn.delete('test_vault_t07', 'rf')
  vim.cmd('cq 1')
end

vim.fn.delete('test_vault_t07', 'rf')
print('PASS: Index build from vault works correctly')
vim.cmd('quit')
