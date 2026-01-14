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

  -- Add example content for testing
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# Example LifeMode View',
    '',
    '- [ ] Task 1: First task',
    '- [ ] Task 2: Second task',
    '- [x] Task 3: Completed task',
    '',
    'Some additional text',
  })

  -- Set example span metadata for testing
  local extmarks = require('lifemode.extmarks')

  extmarks.set_span_metadata(bufnr, 0, 0, {
    instance_id = 'inst-heading',
    node_id = 'node-heading-1',
    lens = 'node/raw',
    span_start = 0,
    span_end = 0,
  })

  extmarks.set_span_metadata(bufnr, 2, 2, {
    instance_id = 'inst-task-1',
    node_id = 'node-task-1',
    lens = 'task/brief',
    span_start = 2,
    span_end = 2,
  })

  extmarks.set_span_metadata(bufnr, 3, 4, {
    instance_id = 'inst-task-group',
    node_id = 'node-task-2-3',
    lens = 'task/detail',
    span_start = 3,
    span_end = 4,
  })

  -- Set up keymaps for view buffer
  local opts = { buffer = bufnr, noremap = true, silent = true }

  -- gr: Find references for link/node under cursor
  vim.keymap.set('n', 'gr', function()
    local references = require('lifemode.references')
    references.find_references_at_cursor()
  end, vim.tbl_extend('force', opts, { desc = 'Find references' }))

  -- gd: Go to definition for wikilink/Bible ref under cursor
  vim.keymap.set('n', 'gd', function()
    local navigation = require('lifemode.navigation')
    navigation.goto_definition()
  end, vim.tbl_extend('force', opts, { desc = 'Go to definition' }))

  -- Open buffer in current window
  vim.api.nvim_set_current_buf(bufnr)

  return bufnr
end

return M
