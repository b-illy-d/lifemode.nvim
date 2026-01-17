local vault = require('lifemode.vault')

local tests_passed = 0
local tests_failed = 0

local function test(name, fn)
  local success, err = pcall(fn)
  if success then
    tests_passed = tests_passed + 1
    print('PASS: ' .. name)
  else
    tests_failed = tests_failed + 1
    print('FAIL: ' .. name .. ' - ' .. tostring(err))
  end
end

test('Empty vault returns empty list', function()
  vim.fn.mkdir('empty_vault', 'p')
  local result = vault.list_files('empty_vault')
  assert(type(result) == 'table', 'Expected table')
  assert(#result == 0, 'Expected empty list, got ' .. #result)
  vim.fn.delete('empty_vault', 'rf')
end)

test('Missing vault_root returns empty list', function()
  local result = vault.list_files('nonexistent_vault')
  assert(type(result) == 'table', 'Expected table')
  assert(#result == 0, 'Expected empty list')
end)

test('Nil vault_root errors', function()
  local success, err = pcall(vault.list_files, nil)
  assert(not success, 'Expected error')
  assert(err:match('vault_root is required'), 'Wrong error: ' .. err)
end)

test('Empty string vault_root errors', function()
  local success, err = pcall(vault.list_files, '')
  assert(not success, 'Expected error')
  assert(err:match('vault_root is required'), 'Wrong error: ' .. err)
end)

test('Ignores non-md files', function()
  vim.fn.mkdir('mixed_vault', 'p')
  vim.fn.writefile({'# Test'}, 'mixed_vault/file.md')
  vim.fn.writefile({'text'}, 'mixed_vault/file.txt')
  vim.fn.writefile({'code'}, 'mixed_vault/file.lua')

  local result = vault.list_files('mixed_vault')
  assert(#result == 1, 'Expected 1 file, got ' .. #result)
  assert(result[1].path:match('%.md$'), 'Expected .md file')

  vim.fn.delete('mixed_vault', 'rf')
end)

test('Handles nested directories', function()
  vim.fn.mkdir('nested_vault/a/b/c', 'p')
  vim.fn.writefile({'# L1'}, 'nested_vault/l1.md')
  vim.fn.writefile({'# L2'}, 'nested_vault/a/l2.md')
  vim.fn.writefile({'# L3'}, 'nested_vault/a/b/l3.md')
  vim.fn.writefile({'# L4'}, 'nested_vault/a/b/c/l4.md')

  local result = vault.list_files('nested_vault')
  assert(#result == 4, 'Expected 4 files, got ' .. #result)

  vim.fn.delete('nested_vault', 'rf')
end)

test('mtime is recent timestamp', function()
  vim.fn.mkdir('mtime_vault', 'p')
  vim.fn.writefile({'# Test'}, 'mtime_vault/file.md')

  local result = vault.list_files('mtime_vault')
  assert(#result == 1, 'Expected 1 file')

  local now = os.time()
  local mtime = result[1].mtime
  assert(type(mtime) == 'number', 'mtime should be number')
  assert(mtime > now - 60, 'mtime should be recent (within 60s)')
  assert(mtime <= now, 'mtime should not be in future')

  vim.fn.delete('mtime_vault', 'rf')
end)

if tests_failed > 0 then
  print(string.format('\nTotal: %d passed, %d failed', tests_passed, tests_failed))
  vim.cmd('cq 1')
else
  print(string.format('\nAll %d tests passed', tests_passed))
  vim.cmd('quit')
end
