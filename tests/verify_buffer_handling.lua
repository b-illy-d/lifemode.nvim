local lifemode = require('lifemode')

print('=== VERIFYING BUFFER ERROR HANDLING ===\n')

lifemode._reset_state()
lifemode.setup({ vault_root = '/tmp/test' })

print('Test: Buffer creation and setup')
local ok, err = pcall(function()
  lifemode.open_view()
end)

if ok then
  print('  Buffer created successfully (normal path works)')
else
  print('  ERROR: ' .. tostring(err))
end

print('\nTest: nvim_buf_set_option with invalid buffer ID')
ok, err = pcall(function()
  vim.api.nvim_buf_set_option(999999, 'buftype', 'nofile')
end)

if ok then
  print('  UNEXPECTED: Invalid buffer ID accepted')
else
  print('  EXPECTED ERROR: ' .. tostring(err))
  print('  Current implementation has no pcall wrapper - errors bubble up to user')
end

print('\n=== VERIFICATION COMPLETE ===')
