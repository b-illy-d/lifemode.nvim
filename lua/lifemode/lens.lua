-- Lens system: deterministic context-sensitive renderers for nodes
-- A lens controls how a node is displayed in a view

local M = {}

-- Lens registry: defines available lenses in order
local lens_order = {
  "task/brief",
  "task/detail",
  "node/raw",
}

-- Get list of available lenses
function M.get_available_lenses()
  return vim.deepcopy(lens_order)
end

-- Render functions for each lens
local renderers = {}

-- task/brief: state + title + priority summary (no ID)
renderers["task/brief"] = function(node)
  local body = node.body_md or ""

  -- Extract the visible parts (remove ID)
  local line = body:gsub("%s*%^[%w%-_]+%s*$", "")  -- Remove trailing ^id

  return line
end

-- task/detail: full metadata (includes ID, tags, all props)
renderers["task/detail"] = function(node)
  local body = node.body_md or ""

  -- For detail lens, include everything
  local lines = { body }

  -- Add tags if present
  if node.props and node.props.tags and #node.props.tags > 0 then
    local tags_line = "  Tags: " .. table.concat(node.props.tags, " ")
    table.insert(lines, tags_line)
  end

  -- If we have multiple lines, return as table; otherwise as string
  if #lines > 1 then
    return lines
  else
    return body
  end
end

-- node/raw: raw markdown snippet (exact body_md)
renderers["node/raw"] = function(node)
  return node.body_md or ""
end

-- Main render function
-- @param node: Node to render
-- @param lens_name: Name of lens to use
-- @return string or table of strings (lines)
function M.render(node, lens_name)
  -- Look up renderer
  local renderer = renderers[lens_name]

  -- Fall back to node/raw if lens not found
  if not renderer then
    renderer = renderers["node/raw"]
  end

  return renderer(node)
end

-- Cycle through lenses
-- @param current_lens: Current lens name
-- @param direction: 1 for next, -1 for previous, 0 defaults to next
-- @return string: Next lens name
function M.cycle_lens(current_lens, direction)
  direction = direction or 1

  -- Default to forward if direction is 0
  if direction == 0 then
    direction = 1
  end

  -- Find current lens index
  local current_idx = nil
  for i, lens_name in ipairs(lens_order) do
    if lens_name == current_lens then
      current_idx = i
      break
    end
  end

  -- If current lens not found, return first lens
  if not current_idx then
    return lens_order[1]
  end

  -- Calculate next index with wrapping
  local next_idx = current_idx + direction

  -- Wrap around
  if next_idx > #lens_order then
    next_idx = 1
  elseif next_idx < 1 then
    next_idx = #lens_order
  end

  return lens_order[next_idx]
end

return M
