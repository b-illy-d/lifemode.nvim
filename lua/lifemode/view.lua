local M = {}

function M.create_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)

  if bufnr == 0 or not bufnr then
    error('Failed to create buffer')
  end

  vim.bo[bufnr].buftype = 'nofile'
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].bufhidden = 'hide'
  vim.bo[bufnr].filetype = 'lifemode'

  local name = string.format('LifeMode [%d]', bufnr)
  pcall(vim.api.nvim_buf_set_name, bufnr, name)

  return bufnr
end

return M
