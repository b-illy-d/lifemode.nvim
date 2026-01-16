vim.env.XDG_CONFIG_HOME = vim.fn.tempname()
vim.env.XDG_DATA_HOME = vim.fn.tempname()
vim.env.XDG_CACHE_HOME = vim.fn.tempname()

local plenary_dir = vim.fn.stdpath('data') .. '/lazy/plenary.nvim'
vim.opt.rtp:append('.')
vim.opt.rtp:append(plenary_dir)
vim.cmd('runtime plugin/plenary.vim')
