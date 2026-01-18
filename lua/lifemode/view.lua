local M = {}

local extmarks = require('lifemode.extmarks')

function M.apply_rendered_content(bufnr, rendered)
  local ns = extmarks.create_namespace()

  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].readonly = false
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, rendered.lines)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  for _, span in ipairs(rendered.spans) do
    extmarks.set_instance_span(bufnr, span.line_start, span.line_end, span)
  end

  for _, hl in ipairs(rendered.highlights) do
    pcall(vim.api.nvim_buf_add_highlight, bufnr, ns, hl.hl_group, hl.line, hl.col_start, hl.col_end)
  end

  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
end

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

function M.set_modifiable(bufnr, modifiable)
  vim.bo[bufnr].modifiable = modifiable
  vim.bo[bufnr].readonly = not modifiable
end

return M
