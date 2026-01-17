local index = require('lifemode.index')

vim.fn.mkdir('test_vault_t09', 'p')
local test_file = vim.fn.fnamemodify('test_vault_t09/file.md', ':p')

vim.fn.writefile({
  '- [ ] Task one ^task-1',
}, test_file)

index.invalidate()

local idx = index.get_or_build(vim.fn.fnamemodify('test_vault_t09', ':p'))

if idx.node_locations['task-1'] == nil then
  print('FAIL: initial index should contain task-1')
  vim.fn.delete('test_vault_t09', 'rf')
  vim.cmd('cq 1')
end

if #idx.tasks_by_state.todo ~= 1 then
  print('FAIL: initial index should have 1 todo task')
  vim.fn.delete('test_vault_t09', 'rf')
  vim.cmd('cq 1')
end

vim.fn.writefile({
  '- [ ] Task one ^task-1',
  '- [x] Task two ^task-2',
  '## Heading ^heading-1',
}, test_file)

local stat = vim.loop.fs_stat(test_file)
if not stat then
  print('FAIL: could not stat test file')
  vim.fn.delete('test_vault_t09', 'rf')
  vim.cmd('cq 1')
end

local success, err = pcall(index.update_file, test_file, stat.mtime.sec)

if not success then
  print('FAIL: update_file errored: ' .. err)
  vim.fn.delete('test_vault_t09', 'rf')
  vim.cmd('cq 1')
end

if idx.node_locations['task-2'] == nil then
  print('FAIL: updated index should contain task-2')
  vim.fn.delete('test_vault_t09', 'rf')
  vim.cmd('cq 1')
end

if idx.node_locations['heading-1'] == nil then
  print('FAIL: updated index should contain heading-1')
  vim.fn.delete('test_vault_t09', 'rf')
  vim.cmd('cq 1')
end

if #idx.tasks_by_state.todo ~= 1 then
  print('FAIL: updated index should have 1 todo task, got ' .. #idx.tasks_by_state.todo)
  vim.fn.delete('test_vault_t09', 'rf')
  vim.cmd('cq 1')
end

if #idx.tasks_by_state.done ~= 1 then
  print('FAIL: updated index should have 1 done task, got ' .. #idx.tasks_by_state.done)
  vim.fn.delete('test_vault_t09', 'rf')
  vim.cmd('cq 1')
end

vim.fn.writefile({
  '- [ ] Task three ^task-3',
}, test_file)

stat = vim.loop.fs_stat(test_file)
index.update_file(test_file, stat.mtime.sec)

if idx.node_locations['task-1'] then
  print('FAIL: old task-1 should be removed from index')
  vim.fn.delete('test_vault_t09', 'rf')
  vim.cmd('cq 1')
end

if idx.node_locations['task-2'] then
  print('FAIL: old task-2 should be removed from index')
  vim.fn.delete('test_vault_t09', 'rf')
  vim.cmd('cq 1')
end

if idx.node_locations['task-3'] == nil then
  print('FAIL: new task-3 should be in index')
  vim.fn.delete('test_vault_t09', 'rf')
  vim.cmd('cq 1')
end

if #idx.tasks_by_state.todo ~= 1 then
  print('FAIL: final index should have 1 todo task')
  vim.fn.delete('test_vault_t09', 'rf')
  vim.cmd('cq 1')
end

if #idx.tasks_by_state.done ~= 0 then
  print('FAIL: final index should have 0 done tasks')
  vim.fn.delete('test_vault_t09', 'rf')
  vim.cmd('cq 1')
end

vim.fn.delete('test_vault_t09', 'rf')
print('PASS: Incremental index update works correctly')
vim.cmd('quit')
