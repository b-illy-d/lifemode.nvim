if vim.g.loaded_lifemode then return end
vim.g.loaded_lifemode = true

local function open_cmd(opts)
  local lifemode = require('lifemode')
  local view_type = opts.args and opts.args ~= '' and opts.args or 'daily'
  lifemode.open_view(view_type)
end

vim.api.nvim_create_user_command('LifeModeOpen', open_cmd, { nargs = '?' })
vim.api.nvim_create_user_command('LM', open_cmd, { nargs = '?' })
vim.api.nvim_create_user_command('LifeModeHello', function() require('lifemode').hello() end, {})
vim.api.nvim_create_user_command('LifeModeDebugSpan', function() require('lifemode').debug_span() end, {})
vim.api.nvim_create_user_command('LifeModeParse', function() require('lifemode').parse_current_buffer() end, {})
