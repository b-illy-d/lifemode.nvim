local index = require('lifemode.index')
local vault = require('lifemode.vault')

vim.fn.mkdir('test_vault_t07', 'p')

vim.fn.writefile({
  '# My Notes',
  '',
  '- [ ] Task one !2 @due(2026-01-20) #work ^task-1',
  '- [x] Task two ^task-2',
  '- Regular item',
}, 'test_vault_t07/file1.md')

vim.fn.writefile({
  '## Heading Two ^heading-1',
  '',
  '- [ ] Another task !3 #personal ^task-3',
}, 'test_vault_t07/file2.md')

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

if idx.node_locations['task-1'] == nil then
  print('FAIL: task-1 should be in node_locations')
  vim.fn.delete('test_vault_t07', 'rf')
  vim.cmd('cq 1')
end

if not idx.node_locations['task-1'].file:match('file1%.md$') then
  print('FAIL: task-1 file path incorrect')
  vim.fn.delete('test_vault_t07', 'rf')
  vim.cmd('cq 1')
end

if idx.node_locations['task-1'].line ~= 2 then
  print('FAIL: task-1 line should be 2, got ' .. idx.node_locations['task-1'].line)
  vim.fn.delete('test_vault_t07', 'rf')
  vim.cmd('cq 1')
end

if idx.node_locations['task-2'] == nil then
  print('FAIL: task-2 should be in node_locations')
  vim.fn.delete('test_vault_t07', 'rf')
  vim.cmd('cq 1')
end

if idx.node_locations['heading-1'] == nil then
  print('FAIL: heading-1 should be in node_locations')
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

vim.fn.delete('test_vault_t07', 'rf')
print('PASS: Index build from vault works correctly')
vim.cmd('quit')
