local index = require('lifemode.index')

vim.fn.mkdir('test_vault_t09_auto', 'p')
local vault_root = vim.fn.fnamemodify('test_vault_t09_auto', ':p')
local test_file = vault_root .. 'file.md'

vim.fn.writefile({
  '- [ ] Task one ^task-1',
}, test_file)

index.invalidate()

local idx = index.get_or_build(vault_root)

if idx.node_locations['task-1'] == nil then
  print('FAIL: initial index should contain task-1')
  vim.fn.delete('test_vault_t09_auto', 'rf')
  vim.cmd('cq 1')
end

local success, err = pcall(index.setup_autocommands, vault_root)

if not success then
  print('FAIL: setup_autocommands errored: ' .. err)
  vim.fn.delete('test_vault_t09_auto', 'rf')
  vim.cmd('cq 1')
end

local bufnr = vim.fn.bufadd(test_file)
vim.fn.bufload(bufnr)

vim.fn.setbufline(bufnr, 1, {
  '- [ ] Task one ^task-1',
  '- [x] Task two ^task-2',
})

vim.cmd('buffer ' .. bufnr)
vim.cmd('write')

vim.wait(100)

if idx.node_locations['task-2'] == nil then
  print('FAIL: autocommand should have updated index with task-2')
  vim.fn.delete('test_vault_t09_auto', 'rf')
  vim.cmd('cq 1')
end

if #idx.tasks_by_state.done ~= 1 then
  print('FAIL: autocommand should have updated tasks_by_state.done')
  vim.fn.delete('test_vault_t09_auto', 'rf')
  vim.cmd('cq 1')
end

vim.fn.delete('test_vault_t09_auto', 'rf')
print('PASS: Autocommand setup and incremental updates work')
vim.cmd('quit!')
