local M = {}

local buffer_counter = 0

function M.create_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)

  if bufnr == 0 or not bufnr then
    error('Failed to create buffer')
  end

  vim.bo[bufnr].buftype = 'nofile'
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].bufhidden = 'wipe'
  vim.bo[bufnr].filetype = 'lifemode'

  buffer_counter = buffer_counter + 1
  vim.api.nvim_buf_set_name(bufnr, 'LifeMode View #' .. buffer_counter)

  return bufnr
end

return M
