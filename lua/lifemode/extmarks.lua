local M = {}

local ns_id = nil
local autocmd_registered = false

function M.create_namespace()
  if not ns_id then
    ns_id = vim.api.nvim_create_namespace('lifemode_spans')
  end
  return ns_id
end

local function register_cleanup_autocmd()
  if autocmd_registered then
    return
  end

  vim.api.nvim_create_autocmd({'BufDelete', 'BufWipeout'}, {
    callback = function(args)
      if M._metadata_store and M._metadata_store[args.buf] then
        M._metadata_store[args.buf] = nil
      end
    end,
  })

  autocmd_registered = true
end

function M.set_instance_span(bufnr, start_line, end_line, metadata)
  if bufnr == 0 or not bufnr then
    error('Invalid buffer number')
  end

  local ns = M.create_namespace()

  local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns, start_line, 0, {
    end_line = end_line,
    end_col = 0,
    right_gravity = false,
    end_right_gravity = true,
  })

  if not mark_id then
    error('Failed to create extmark')
  end

  if not M._metadata_store then
    M._metadata_store = {}
    register_cleanup_autocmd()
  end

  if not M._metadata_store[bufnr] then
    M._metadata_store[bufnr] = {}
  end

  M._metadata_store[bufnr][mark_id] = metadata
end

function M.get_instance_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1

  if not M._metadata_store or not M._metadata_store[bufnr] then
    return nil
  end

  local ns = M.create_namespace()
  local extmarks = vim.api.nvim_buf_get_extmarks(
    bufnr,
    ns,
    0,
    -1,
    {details = true}
  )

  for _, mark in ipairs(extmarks) do
    local mark_id = mark[1]
    local mark_line = mark[2]
    local details = mark[4]

    if details and details.end_row then
      if line >= mark_line and line <= details.end_row then
        return M._metadata_store[bufnr][mark_id]
      end
    end
  end

  return nil
end

return M
