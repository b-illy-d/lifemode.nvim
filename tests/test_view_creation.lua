vim.opt.rtp:prepend('.')

local view = require('lifemode.view')
local lifemode = require('lifemode')

lifemode.setup({ vault_root = '/tmp/test_vault' })

print('\n=== Testing view.create_buffer() ===')

local bufnr = view.create_buffer()

if not bufnr or bufnr <= 0 then
  print('FAIL: create_buffer() did not return valid buffer number')
  os.exit(1)
end

print('Created buffer: ' .. bufnr)

local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
local swapfile = vim.api.nvim_buf_get_option(bufnr, 'swapfile')
local bufhidden = vim.api.nvim_buf_get_option(bufnr, 'bufhidden')
local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
local bufname = vim.api.nvim_buf_get_name(bufnr)

print('Buffer settings:')
print('  buftype: ' .. buftype)
print('  swapfile: ' .. tostring(swapfile))
print('  bufhidden: ' .. bufhidden)
print('  filetype: ' .. filetype)
print('  bufname: ' .. bufname)

local all_passed = true

if buftype ~= 'nofile' then
  print('FAIL: buftype should be "nofile", got "' .. buftype .. '"')
  all_passed = false
end

if swapfile then
  print('FAIL: swapfile should be false, got true')
  all_passed = false
end

if bufhidden ~= 'hide' then
  print('FAIL: bufhidden should be "hide", got "' .. bufhidden .. '"')
  all_passed = false
end

if filetype ~= 'lifemode' then
  print('FAIL: filetype should be "lifemode", got "' .. filetype .. '"')
  all_passed = false
end

if not bufname:match('LifeMode') then
  print('FAIL: buffer name should contain "LifeMode", got "' .. bufname .. '"')
  all_passed = false
end

print('\n=== Testing :LifeMode command ===')

local has_command = vim.fn.exists(':LifeMode') == 2
if not has_command then
  print('FAIL: :LifeMode command does not exist')
  all_passed = false
else
  print('SUCCESS: :LifeMode command exists')

  vim.cmd('LifeMode')

  local current_bufnr = vim.api.nvim_get_current_buf()
  local current_buftype = vim.api.nvim_buf_get_option(current_bufnr, 'buftype')
  local current_filetype = vim.api.nvim_buf_get_option(current_bufnr, 'filetype')

  if current_buftype ~= 'nofile' then
    print('FAIL: :LifeMode did not create nofile buffer')
    all_passed = false
  end

  if current_filetype ~= 'lifemode' then
    print('FAIL: :LifeMode buffer does not have lifemode filetype')
    all_passed = false
  end
end

if all_passed then
  print('\n=== ALL TESTS PASSED ===')
  os.exit(0)
else
  print('\n=== TESTS FAILED ===')
  os.exit(1)
end
