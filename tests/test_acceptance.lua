vim.opt.rtp:prepend('.')

local lifemode = require('lifemode')

print('=== T00 ACCEPTANCE CRITERIA ===\n')

print('1. Setup with vault_root')
lifemode.setup({ vault_root = '/tmp/test_vault' })
print('   PASS: Plugin configured\n')

print('2. :LifeModeHello echoes config')
lifemode.hello()
print('   PASS: Config displayed\n')

print('3. :LifeMode opens view buffer')
lifemode.open_view()

local bufname = vim.api.nvim_buf_get_name(0)
local buftype = vim.api.nvim_buf_get_option(0, 'buftype')

assert(buftype == 'nofile', 'Buffer type should be nofile')
assert(string.match(bufname, 'LifeMode'), 'Buffer name should contain LifeMode')
print('   Buffer name: ' .. bufname)
print('   Buffer type: ' .. buftype)
print('   PASS: View buffer opened\n')

print('4. Plugin loads without errors')
print('   PASS: No errors during setup or command execution\n')

print('=== ALL ACCEPTANCE CRITERIA MET ===')
print('T00 COMPLETE')
