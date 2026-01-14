-- Compiled view rendering for LifeMode
-- Renders page root nodes (single file) to a view buffer

local node = require('lifemode.node')
local lens = require('lifemode.lens')
local extmarks = require('lifemode.extmarks')
local lifemode = require('lifemode')

local M = {}

-- Track which instances are expanded
-- Format: {[bufnr] = {[instance_id] = {child_instance_ids = {...}, node_id = "...", depth = N, expansion_path = {...}}}}
local expanded_instances = {}

--- Check if an instance is expanded
--- @param bufnr number Buffer number
--- @param instance_id string Instance ID
--- @return boolean True if expanded
function M.is_expanded(bufnr, instance_id)
  if not expanded_instances[bufnr] then
    return false
  end
  return expanded_instances[bufnr][instance_id] ~= nil
end

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

--- Expand an instance to show its children
--- @param bufnr number View buffer number
--- @param line number Line number (0-indexed) where cursor is
function M.expand_instance(bufnr, line)
  local extmarks = require('lifemode.extmarks')
  local node_mod = require('lifemode.node')
  local config = lifemode.get_config()

  -- Get span at line
  local span = extmarks.get_span_at_line(bufnr, line)
  if not span then
    return
  end

  -- Check if already expanded
  if M.is_expanded(bufnr, span.instance_id) then
    return  -- Already expanded, do nothing
  end

  -- Get node data - we need to parse source buffer
  -- For MVP, retrieve from span metadata or re-parse
  -- Simplified: assume we have node_id in metadata
  local node_id = span.node_id
  if not node_id then
    return
  end

  -- Get node and its children from cached data
  -- For MVP, we'll need to re-parse or cache node data
  -- Let's use a module-level cache
  if not M._node_cache then
    M._node_cache = {}
  end

  local cache_key = string.format("%d:%s", bufnr, node_id)
  local node_data = M._node_cache[cache_key]

  if not node_data or not node_data.children or #node_data.children == 0 then
    return  -- No children to expand
  end

  -- Get expansion depth and path from parent (if expanding a child)
  local current_depth = 0
  local expansion_path = {}

  -- Find parent's expansion info to get depth and path
  if not expanded_instances[bufnr] then
    expanded_instances[bufnr] = {}
  end

  for parent_instance_id, parent_expansion in pairs(expanded_instances[bufnr]) do
    if parent_expansion.child_instance_ids then
      for _, child_id in ipairs(parent_expansion.child_instance_ids) do
        if child_id == span.instance_id then
          -- This span is a child of parent_instance_id
          current_depth = (parent_expansion.depth or 0) + 1
          expansion_path = vim.deepcopy(parent_expansion.expansion_path or {})
          break
        end
      end
    end
  end

  -- Check depth limit BEFORE expanding
  if current_depth >= config.max_depth then
    -- At or exceeding max depth - don't expand further
    return
  end

  -- Add current node to expansion path for tracking children
  table.insert(expansion_path, node_id)

  -- Render children
  local child_lines = {}
  local child_spans = {}
  local nodes_rendered = 0

  for _, child_id in ipairs(node_data.children) do
    -- Check node count limit
    if nodes_rendered >= config.max_nodes_per_action then
      break
    end

    -- Check for cycle: if child_id is already in expansion_path
    local cycle_detected = false
    for _, ancestor_id in ipairs(expansion_path) do
      if ancestor_id == child_id then
        cycle_detected = true
        break
      end
    end

    if cycle_detected then
      -- Render cycle stub for this child
      local stub_line = "  ↩ already shown"
      table.insert(child_lines, stub_line)

      -- Note: We don't create a span for the stub (it's not interactive)
      -- Just add the line to the child_lines
      nodes_rendered = nodes_rendered + 1
    else
      local child_node = M._node_cache[string.format("%d:%s", bufnr, child_id)]
      if child_node then
        -- Choose lens for child
        local child_lens = choose_lens(child_node)

        -- Render child
        local rendered = lens.render(child_node, child_lens)

        -- Handle both string and table return types
        local lines_to_add = {}
        if type(rendered) == "table" then
          lines_to_add = rendered
        else
          lines_to_add = { rendered }
        end

        -- Store child lines and metadata
        for _, child_line in ipairs(lines_to_add) do
          table.insert(child_lines, child_line)
        end

        -- Store span metadata for child
        local child_instance_id = generate_instance_id()
        table.insert(child_spans, {
          instance_id = child_instance_id,
          node_id = child_id,
          lens = child_lens,
          start_offset = #child_lines - #lines_to_add,
          line_count = #lines_to_add,
        })

        nodes_rendered = nodes_rendered + 1
      end
    end
  end

  -- Insert child lines after parent span
  local insert_line = span.span_end + 1
  vim.api.nvim_buf_set_lines(bufnr, insert_line, insert_line, false, child_lines)

  -- Set extmark metadata for children
  local current_line = insert_line
  for _, child_span_info in ipairs(child_spans) do
    local child_start = current_line
    local child_end = current_line + child_span_info.line_count - 1

    extmarks.set_span_metadata(bufnr, child_start, child_end, {
      instance_id = child_span_info.instance_id,
      node_id = child_span_info.node_id,
      lens = child_span_info.lens,
      span_start = child_start,
      span_end = child_end,
    })

    current_line = child_end + 1
  end

  -- Track expansion state
  if not expanded_instances[bufnr] then
    expanded_instances[bufnr] = {}
  end

  local child_instance_ids = {}
  for _, child_span_info in ipairs(child_spans) do
    table.insert(child_instance_ids, child_span_info.instance_id)
  end

  expanded_instances[bufnr][span.instance_id] = {
    child_instance_ids = child_instance_ids,
    node_id = node_id,
    insert_line = insert_line,
    line_count = #child_lines,
    depth = current_depth,
    expansion_path = expansion_path,
  }
end

--- Collapse an expanded instance (remove its children)
--- @param bufnr number View buffer number
--- @param line number Line number (0-indexed) where cursor is
function M.collapse_instance(bufnr, line)
  local extmarks = require('lifemode.extmarks')

  -- Get span at line
  local span = extmarks.get_span_at_line(bufnr, line)
  if not span then
    return
  end

  -- Check if expanded
  if not M.is_expanded(bufnr, span.instance_id) then
    return  -- Not expanded, nothing to collapse
  end

  -- Get expansion info
  local expansion = expanded_instances[bufnr][span.instance_id]

  -- Delete child lines
  local delete_start = expansion.insert_line
  local delete_end = expansion.insert_line + expansion.line_count
  vim.api.nvim_buf_set_lines(bufnr, delete_start, delete_end, false, {})

  -- Clear extmarks for children (they're automatically removed when lines are deleted)

  -- Clear expansion state
  expanded_instances[bufnr][span.instance_id] = nil
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

  -- Cache node data for expand/collapse
  if not M._node_cache then
    M._node_cache = {}
  end
  for node_id, node_data in pairs(nodes_by_id) do
    local cache_key = string.format("%d:%s", view_bufnr, node_id)
    M._node_cache[cache_key] = node_data
  end

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

  -- Set up keymaps for expand/collapse
  local opts = { buffer = view_bufnr, noremap = true, silent = true }

  -- <Space>e: Expand instance under cursor
  vim.keymap.set('n', '<Space>e', function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1] - 1  -- Convert to 0-indexed
    M.expand_instance(view_bufnr, line)
  end, vim.tbl_extend('force', opts, { desc = 'Expand instance' }))

  -- <Space>E: Collapse instance under cursor
  vim.keymap.set('n', '<Space>E', function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1] - 1  -- Convert to 0-indexed
    M.collapse_instance(view_bufnr, line)
  end, vim.tbl_extend('force', opts, { desc = 'Collapse instance' }))

  return view_bufnr
end

return M
