local index = require('lifemode.index')

vim.fn.mkdir('test_vault_t08', 'p')

vim.fn.writefile({
  '- [ ] Test task ^task-1',
}, 'test_vault_t08/file.md')

index.invalidate()

if index.is_built() then
  print('FAIL: index should not be built after invalidate')
  vim.fn.delete('test_vault_t08', 'rf')
  vim.cmd('cq 1')
end

local success, idx1 = pcall(index.get_or_build, 'test_vault_t08')

if not success then
  print('FAIL: get_or_build errored: ' .. idx1)
  vim.fn.delete('test_vault_t08', 'rf')
  vim.cmd('cq 1')
end

if not index.is_built() then
  print('FAIL: index should be built after get_or_build')
  vim.fn.delete('test_vault_t08', 'rf')
  vim.cmd('cq 1')
end

if idx1.node_locations['task-1'] == nil then
  print('FAIL: index should contain task-1')
  vim.fn.delete('test_vault_t08', 'rf')
  vim.cmd('cq 1')
end

local idx2 = index.get_or_build('test_vault_t08')

if idx2 ~= idx1 then
  print('FAIL: get_or_build should return same index instance')
  vim.fn.delete('test_vault_t08', 'rf')
  vim.cmd('cq 1')
end

index.invalidate()

if index.is_built() then
  print('FAIL: index should not be built after second invalidate')
  vim.fn.delete('test_vault_t08', 'rf')
  vim.cmd('cq 1')
end

local idx3 = index.get_or_build('test_vault_t08')

if idx3 == idx1 then
  print('FAIL: get_or_build should return new index after invalidate')
  vim.fn.delete('test_vault_t08', 'rf')
  vim.cmd('cq 1')
end

vim.fn.delete('test_vault_t08', 'rf')
print('PASS: Lazy index initialization works correctly')
vim.cmd('quit')
