-- Compiled view rendering for LifeMode
-- Renders page root nodes (single file) to a view buffer

local node = require('lifemode.node')
local lens = require('lifemode.lens')
local extmarks = require('lifemode.extmarks')

local M = {}

--- Generate a unique instance ID
--- @return string Unique instance ID
local function generate_instance_id()
  return string.format("inst_%d_%d", os.time(), math.random(10000, 99999))
end

--- Choose lens for a node based on its type
--- @param node_data table Node data
--- @return string Lens name
local function choose_lens(node_data)
  if node_data.type == "task" then
    return "task/brief"
  else
    return "node/raw"
  end
end

--- Render a page view from source buffer
--- Parses source buffer, extracts root nodes, renders each with appropriate lens
--- @param source_bufnr number Source buffer number
--- @return number View buffer number
function M.render_page_view(source_bufnr)
  -- Parse source buffer to get nodes
  local result = node.build_nodes_from_buffer(source_bufnr)
  local nodes_by_id = result.nodes_by_id
  local root_ids = result.root_ids

  -- Create view buffer
  local view_bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(view_bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(view_bufnr, 'swapfile', false)
  vim.api.nvim_buf_set_option(view_bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(view_bufnr, 'filetype', 'lifemode')
  vim.api.nvim_buf_set_option(view_bufnr, 'modifiable', true)  -- For MVP

  -- Set buffer name
  local bufname = '[LifeMode:PageView]'
  local existing = vim.fn.bufnr(bufname)
  if existing ~= -1 and existing ~= view_bufnr then
    bufname = string.format('[LifeMode:PageView:%d]', view_bufnr)
  end
  vim.api.nvim_buf_set_name(view_bufnr, bufname)

  -- Render root nodes
  local view_lines = {}
  local spans_to_mark = {}  -- Store span metadata to set after buffer is populated
  local current_line = 0

  for _, root_id in ipairs(root_ids) do
    local node_data = nodes_by_id[root_id]
    if node_data then
      -- Choose lens based on node type
      local lens_name = choose_lens(node_data)

      -- Render node with lens
      local rendered = lens.render(node_data, lens_name)

      -- Handle both string and table return types
      local lines_to_add = {}
      if type(rendered) == "table" then
        lines_to_add = rendered
      else
        lines_to_add = { rendered }
      end

      -- Calculate span
      local span_start = current_line
      local span_end = current_line + #lines_to_add - 1

      -- Add lines to view
      for _, line in ipairs(lines_to_add) do
        table.insert(view_lines, line)
      end

      -- Store span metadata to set later
      local instance_id = generate_instance_id()
      table.insert(spans_to_mark, {
        span_start = span_start,
        span_end = span_end,
        metadata = {
          instance_id = instance_id,
          node_id = root_id,
          lens = lens_name,
          span_start = span_start,
          span_end = span_end,
        }
      })

      current_line = span_end + 1
    end
  end

  -- If no root nodes, add empty line
  if #view_lines == 0 then
    view_lines = { "" }
  end

  -- Set buffer content
  vim.api.nvim_buf_set_lines(view_bufnr, 0, -1, false, view_lines)

  -- Now set extmark metadata after buffer is populated
  for _, span_info in ipairs(spans_to_mark) do
    extmarks.set_span_metadata(view_bufnr, span_info.span_start, span_info.span_end, span_info.metadata)
  end

  return view_bufnr
end

return M
