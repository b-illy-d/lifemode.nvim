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

  -- <Space><Space>: Toggle task state at cursor
  vim.keymap.set('n', '<Space><Space>', function()
    local tasks = require('lifemode.tasks')
    local node_id, buf = tasks.get_task_at_cursor()
    if node_id then
      local success = tasks.toggle_task_state(buf, node_id)
      if success then
        vim.api.nvim_echo({{'Task state toggled', 'Normal'}}, false, {})
      else
        vim.api.nvim_echo({{'Failed to toggle task state', 'WarningMsg'}}, false, {})
      end
    else
      vim.api.nvim_echo({{'No task at cursor', 'WarningMsg'}}, false, {})
    end
  end, vim.tbl_extend('force', opts, { desc = 'Toggle task state' }))

  -- <Space>tp: Increase task priority
  vim.keymap.set('n', '<Space>tp', function()
    local tasks = require('lifemode.tasks')
    local node_id, buf = tasks.get_task_at_cursor()
    if node_id then
      local success = tasks.inc_priority(buf, node_id)
      if success then
        vim.api.nvim_echo({{'Priority increased', 'Normal'}}, false, {})
      else
        vim.api.nvim_echo({{'Failed to increase priority', 'WarningMsg'}}, false, {})
      end
    else
      vim.api.nvim_echo({{'No task at cursor', 'WarningMsg'}}, false, {})
    end
  end, vim.tbl_extend('force', opts, { desc = 'Increase task priority' }))

  -- <Space>tP: Decrease task priority
  vim.keymap.set('n', '<Space>tP', function()
    local tasks = require('lifemode.tasks')
    local node_id, buf = tasks.get_task_at_cursor()
    if node_id then
      local success = tasks.dec_priority(buf, node_id)
      if success then
        vim.api.nvim_echo({{'Priority decreased', 'Normal'}}, false, {})
      else
        vim.api.nvim_echo({{'Failed to decrease priority', 'WarningMsg'}}, false, {})
      end
    else
      vim.api.nvim_echo({{'No task at cursor', 'WarningMsg'}}, false, {})
    end
  end, vim.tbl_extend('force', opts, { desc = 'Decrease task priority' }))

  -- <Space>tt: Add tag to task
  vim.keymap.set('n', '<Space>tt', function()
    local tasks = require('lifemode.tasks')
    tasks.add_tag_interactive()
  end, vim.tbl_extend('force', opts, { desc = 'Add tag to task' }))

  -- <Space>td: Set due date
  vim.keymap.set('n', '<Space>td', function()
    local tasks = require('lifemode.tasks')
    tasks.set_due_interactive()
  end, vim.tbl_extend('force', opts, { desc = 'Set due date on task' }))

  -- <Space>ml: Cycle to next lens
  vim.keymap.set('n', '<Space>ml', function()
    local lens = require('lifemode.lens')
    -- For MVP, just show message about lens cycling
    -- In future: get current lens from active instance, cycle, re-render
    local current = "task/brief"  -- default for MVP
    local next_lens = lens.cycle_lens(current, 1)
    vim.api.nvim_echo({{'Next lens: ' .. next_lens, 'Normal'}}, false, {})
  end, vim.tbl_extend('force', opts, { desc = 'Cycle to next lens' }))

  -- <Space>mL: Cycle to previous lens
  vim.keymap.set('n', '<Space>mL', function()
    local lens = require('lifemode.lens')
    -- For MVP, just show message about lens cycling
    -- In future: get current lens from active instance, cycle, re-render
    local current = "task/brief"  -- default for MVP
    local prev_lens = lens.cycle_lens(current, -1)
    vim.api.nvim_echo({{'Previous lens: ' .. prev_lens, 'Normal'}}, false, {})
  end, vim.tbl_extend('force', opts, { desc = 'Cycle to previous lens' }))

  -- Open buffer in current window
  vim.api.nvim_set_current_buf(bufnr)

  -- Enable active node tracking
  local activenode = require('lifemode.activenode')
  activenode.track_cursor_movement(bufnr)

  return bufnr
end

return M
