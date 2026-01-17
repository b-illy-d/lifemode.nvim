local index = require('lifemode.index')

vim.fn.mkdir('test_vault_t09_debug', 'p')
local test_file = vim.fn.fnamemodify('test_vault_t09_debug/file.md', ':p')

vim.fn.writefile({
  '- [ ] Task one ^task-1',
}, test_file)

index.invalidate()

local idx = index.get_or_build(vim.fn.fnamemodify('test_vault_t09_debug', ':p'))

print('Initial index:')
print('  todo tasks: ' .. #idx.tasks_by_state.todo)
for i, task in ipairs(idx.tasks_by_state.todo) do
  print('    ' .. i .. ': ' .. task.id .. ' from ' .. task._file)
end

vim.fn.writefile({
  '- [ ] Task one ^task-1',
  '- [x] Task two ^task-2',
  '## Heading ^heading-1',
}, test_file)

local stat = vim.loop.fs_stat(test_file)
index.update_file(test_file, stat.mtime.sec)

print('\nAfter update:')
print('  todo tasks: ' .. #idx.tasks_by_state.todo)
for i, task in ipairs(idx.tasks_by_state.todo) do
  print('    ' .. i .. ': ' .. task.id .. ' from ' .. task._file)
end
print('  done tasks: ' .. #idx.tasks_by_state.done)
for i, task in ipairs(idx.tasks_by_state.done) do
  print('    ' .. i .. ': ' .. task.id .. ' from ' .. task._file)
end

vim.fn.delete('test_vault_t09_debug', 'rf')
vim.cmd('quit')
