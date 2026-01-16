vim.opt.rtp:prepend('.')

local lifemode = require('lifemode')

lifemode.setup({ vault_root = '/tmp/test_vault' })

print('\n=== Testing :LifeModeHello ===')
lifemode.hello()

print('\n=== Testing :LifeMode ===')
lifemode.open_view()

local bufname = vim.api.nvim_buf_get_name(0)
print('Current buffer name: ' .. bufname)

local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
print('Buffer content:')
for i, line in ipairs(lines) do
  print('  ' .. i .. ': ' .. line)
end

local buftype = vim.api.nvim_buf_get_option(0, 'buftype')
print('Buffer type: ' .. buftype)

if buftype == 'nofile' and #lines > 0 then
  print('\nSUCCESS: :LifeMode opened empty view buffer')
else
  print('\nFAIL: Buffer not configured correctly')
end
