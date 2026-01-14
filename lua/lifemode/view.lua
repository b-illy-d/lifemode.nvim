-- LifeMode: View buffer creation and management

local M = {}

-- Create a new LifeMode view buffer
-- Returns: buffer number
function M.create_buffer()
  -- Create a scratch buffer (not listed, scratch)
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'lifemode')

  -- Set buffer name - handle duplicates by using buffer number
  local bufname = '[LifeMode]'
  -- Check if a buffer with this name already exists
  local existing = vim.fn.bufnr(bufname)
  if existing ~= -1 and existing ~= bufnr then
    -- Use unique name with buffer number
    bufname = string.format('[LifeMode:%d]', bufnr)
  end
  vim.api.nvim_buf_set_name(bufnr, bufname)

  -- Open buffer in current window
  vim.api.nvim_set_current_buf(bufnr)

  return bufnr
end

return M
