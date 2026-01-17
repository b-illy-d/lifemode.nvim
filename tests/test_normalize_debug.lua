local path1 = '/Users/billy/lifemode.nvim/test_vault_t09_debug//file.md'
local path2 = '/Users/billy/lifemode.nvim/test_vault_t09_debug/file.md'

local norm1 = vim.fn.fnamemodify(path1, ':p')
local norm2 = vim.fn.fnamemodify(path2, ':p')

print('path1: ' .. path1)
print('norm1: ' .. norm1)
print('path2: ' .. path2)
print('norm2: ' .. norm2)
print('equal: ' .. tostring(norm1 == norm2))

local simplified1 = vim.fn.simplify(path1)
local simplified2 = vim.fn.simplify(path2)

print('\nsimplified1: ' .. simplified1)
print('simplified2: ' .. simplified2)
print('equal: ' .. tostring(simplified1 == simplified2))

vim.cmd('quit')
