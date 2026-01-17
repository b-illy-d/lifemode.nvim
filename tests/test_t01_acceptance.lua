vim.opt.rtp:prepend('.')

local view = require('lifemode.view')
local lifemode = require('lifemode')

lifemode.setup({ vault_root = '/tmp/test_vault' })

print('\n=== T01 ACCEPTANCE CRITERIA ===')

local test_passed = true

print('\n1. lifemode.view.create_buffer() creates buffer with correct settings')
local bufnr = view.create_buffer()
if bufnr and bufnr > 0 then
  local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
  local swapfile = vim.api.nvim_buf_get_option(bufnr, 'swapfile')
  local bufhidden = vim.api.nvim_buf_get_option(bufnr, 'bufhidden')
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')

  if buftype == 'nofile' and not swapfile and bufhidden == 'hide' and filetype == 'lifemode' then
    print('   PASS: Buffer created with correct settings')
    print('     - buftype: nofile ✓')
    print('     - swapfile: false ✓')
    print('     - bufhidden: hide ✓')
    print('     - filetype: lifemode ✓')
  else
    print('   FAIL: Buffer settings incorrect')
    test_passed = false
  end
else
  print('   FAIL: create_buffer() did not return valid buffer')
  test_passed = false
end

print('\n2. :LifeMode command exists and opens view buffer')
local has_command = vim.fn.exists(':LifeMode') == 2
if has_command then
  print('   PASS: :LifeMode command exists')

  vim.cmd('LifeMode')
  local current_bufnr = vim.api.nvim_get_current_buf()
  local current_buftype = vim.api.nvim_buf_get_option(current_bufnr, 'buftype')
  local current_filetype = vim.api.nvim_buf_get_option(current_bufnr, 'filetype')
  local bufname = vim.api.nvim_buf_get_name(current_bufnr)

  if current_buftype == 'nofile' and current_filetype == 'lifemode' and bufname:match('LifeMode') then
    print('   PASS: :LifeMode opened view buffer correctly')
    print('     - Buffer is nofile ✓')
    print('     - Filetype is lifemode ✓')
    print('     - Name contains "LifeMode" ✓')
  else
    print('   FAIL: :LifeMode did not open correct buffer')
    test_passed = false
  end
else
  print('   FAIL: :LifeMode command does not exist')
  test_passed = false
end

print('\n3. Buffer is clearly marked as LifeMode view')
local test_bufnr = view.create_buffer()
local test_filetype = vim.api.nvim_buf_get_option(test_bufnr, 'filetype')
local test_bufname = vim.api.nvim_buf_get_name(test_bufnr)

if test_filetype == 'lifemode' and test_bufname:match('LifeMode') then
  print('   PASS: Buffer clearly marked as LifeMode view')
  print('     - Filetype: ' .. test_filetype .. ' ✓')
  print('     - Name: ' .. test_bufname .. ' ✓')
else
  print('   FAIL: Buffer not clearly marked')
  test_passed = false
end

if test_passed then
  print('\n=== ALL ACCEPTANCE CRITERIA MET ===')
  print('T01 COMPLETE')
  os.exit(0)
else
  print('\n=== SOME ACCEPTANCE CRITERIA FAILED ===')
  os.exit(1)
end
