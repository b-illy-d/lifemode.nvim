vim.opt.rtp:prepend('.')
local lifemode = require('lifemode')

print('=== BUFFER CREATION EDGE CASES ===\n')

print('Test 1: Check if nvim_create_buf can fail')
local ok, result = pcall(vim.api.nvim_create_buf, false, true)
print('  nvim_create_buf result: ok=' .. tostring(ok) .. ', bufnr=' .. tostring(result))
print('  bufnr type: ' .. type(result))
print('  bufnr == 0 means invalid: ' .. tostring(result == 0))

print('\nTest 2: Check if nvim_buf_set_option can fail on invalid buffer')
ok, err = pcall(vim.api.nvim_buf_set_option, 999999, 'buftype', 'nofile')
print('  nvim_buf_set_option on invalid buffer: ok=' .. tostring(ok))
if not ok then
  print('  Error: ' .. tostring(err))
end

print('\nTest 3: Check if nvim_buf_set_name can fail')
local bufnr = vim.api.nvim_create_buf(false, true)
ok, err = pcall(vim.api.nvim_buf_set_name, bufnr, '')
print('  nvim_buf_set_name with empty string: ok=' .. tostring(ok))
if not ok then
  print('  Error: ' .. tostring(err))
end

print('\nTest 4: Check if nvim_buf_set_name can fail with duplicate name')
local buf1 = vim.api.nvim_create_buf(false, true)
local buf2 = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(buf1, 'TestBuffer')
ok, err = pcall(vim.api.nvim_buf_set_name, buf2, 'TestBuffer')
print('  nvim_buf_set_name with duplicate: ok=' .. tostring(ok))
if not ok then
  print('  Error: ' .. tostring(err))
end

print('\nTest 5: Check if nvim_buf_set_lines can fail')
ok, err = pcall(vim.api.nvim_buf_set_lines, bufnr, 0, -1, false, nil)
print('  nvim_buf_set_lines with nil: ok=' .. tostring(ok))
if not ok then
  print('  Error: ' .. tostring(err))
end

print('\nTest 6: Check if nvim_win_set_buf can fail')
ok, err = pcall(vim.api.nvim_win_set_buf, 0, 999999)
print('  nvim_win_set_buf with invalid buffer: ok=' .. tostring(ok))
if not ok then
  print('  Error: ' .. tostring(err))
end

print('\nTest 7: Test actual open_view() implementation')
lifemode.setup({ vault_root = '/tmp/test' })
ok, err = pcall(lifemode.open_view)
print('  open_view() result: ok=' .. tostring(ok))
if not ok then
  print('  Error: ' .. tostring(err))
else
  local current_buf = vim.api.nvim_get_current_buf()
  local buftype = vim.api.nvim_buf_get_option(current_buf, 'buftype')
  print('  Current buffer type: ' .. buftype)
end

print('\n=== END BUFFER CREATION EDGE CASES ===')
