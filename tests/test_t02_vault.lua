local vault = require('lifemode.vault')

vim.fn.mkdir('test_vault', 'p')
vim.fn.mkdir('test_vault/subdir', 'p')
vim.fn.writefile({'# Test'}, 'test_vault/file1.md')
vim.fn.writefile({'# Test2'}, 'test_vault/subdir/file2.md')
vim.fn.writefile({'text'}, 'test_vault/other.txt')

local success, result = pcall(vault.list_files, 'test_vault')

if not success then
  print('FAIL: vault.list_files errored: ' .. result)
  vim.fn.delete('test_vault', 'rf')
  vim.cmd('cq 1')
end

if type(result) ~= 'table' then
  print('FAIL: Expected table, got ' .. type(result))
  vim.fn.delete('test_vault', 'rf')
  vim.cmd('cq 1')
end

local md_files = {}
for _, entry in ipairs(result) do
  if entry.path:match('%.md$') then
    table.insert(md_files, entry.path)
  end
end

if #md_files ~= 2 then
  print('FAIL: Expected 2 .md files, got ' .. #md_files)
  for _, f in ipairs(md_files) do
    print('  - ' .. f)
  end
  vim.fn.delete('test_vault', 'rf')
  vim.cmd('cq 1')
end

local has_file1 = false
local has_file2 = false
for _, entry in ipairs(result) do
  if entry.path:match('file1%.md$') then
    has_file1 = true
    if not entry.mtime or type(entry.mtime) ~= 'number' then
      print('FAIL: file1.md missing or invalid mtime')
      vim.fn.delete('test_vault', 'rf')
      vim.cmd('cq 1')
    end
  end
  if entry.path:match('file2%.md$') then
    has_file2 = true
    if not entry.mtime or type(entry.mtime) ~= 'number' then
      print('FAIL: file2.md missing or invalid mtime')
      vim.fn.delete('test_vault', 'rf')
      vim.cmd('cq 1')
    end
  end
end

if not has_file1 or not has_file2 then
  print('FAIL: Missing expected files')
  print('  file1: ' .. tostring(has_file1))
  print('  file2: ' .. tostring(has_file2))
  vim.fn.delete('test_vault', 'rf')
  vim.cmd('cq 1')
end

vim.fn.delete('test_vault', 'rf')
print('PASS: Vault file discovery works')
vim.cmd('quit')
