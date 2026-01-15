-- In-memory Node model for LifeMode
-- Converts parsed blocks into a tree structure with parent/child relationships

local parser = require('lifemode.parser')
local bible = require('lifemode.bible')

local M = {}

--- Generate a synthetic ID for nodes without explicit IDs
--- @return string Synthetic ID in format "node_NNNN"
local function generate_synthetic_id()
  -- Use timestamp + random for uniqueness
  return string.format("node_%d_%d", os.time(), math.random(1000, 9999))
end

--- Get heading level from heading text
--- @param text string Heading text (e.g., "# Heading" or "### Sub")
--- @return number Level (1 for #, 2 for ##, etc.)
local function get_heading_level(text)
  local count = 0
  for _ in text:gmatch("#") do
    count = count + 1
    if text:sub(count + 1, count + 1) == " " then
      break
    end
  end
  return count
end

--- Get indentation level from list item text
--- @param text string Line text
--- @return number Indentation level (0 = no indent, 2 = one level, 4 = two levels, etc.)
local function get_indent_level(text)
  local spaces = text:match("^(%s*)")
  return #spaces
end

--- Extract inclusions from text
--- @param text string Text to search for inclusions
--- @return table Array of refs with format { target = "node-id", type = "inclusion" }
local function extract_inclusions(text)
  local refs = {}

  -- Pattern to match ![[...]] inclusions
  -- Captures content between ![[and ]]
  for target in text:gmatch("!%[%[([^%]]+)%]%]") do
    -- Skip empty targets
    if target and target:match("%S") then
      table.insert(refs, {
        target = target,
        type = "inclusion"
      })
    end
  end

  return refs
end

--- Extract wikilinks from text (excluding inclusions)
--- @param text string Text to search for wikilinks
--- @return table Array of refs with format { target = "Page", type = "wikilink" }
local function extract_wikilinks(text)
  local refs = {}

  -- Pattern to match [[...]] wikilinks that are NOT preceded by !
  -- First, remove all inclusions to avoid matching them
  local text_without_inclusions = text:gsub("!%[%[[^%]]+%]%]", "")

  -- Now match remaining [[...]] patterns
  for target in text_without_inclusions:gmatch("%[%[([^%]]+)%]%]") do
    -- Skip empty targets
    if target and target:match("%S") then
      table.insert(refs, {
        target = target,
        type = "wikilink"
      })
    end
  end

  return refs
end

--- Build nodes from buffer
--- Converts parsed blocks into Node records with tree structure
--- @param bufnr number Buffer handle
--- @return table Result with nodes_by_id (map), root_ids (array), and backlinks (map)
function M.build_nodes_from_buffer(bufnr)
  local blocks = parser.parse_buffer(bufnr)
  local nodes_by_id = {}
  local root_ids = {}
  local backlinks = {}  -- Map from target -> array of source node IDs

  -- Stack to track parent context for hierarchy
  -- For headings: stack of {id, level}
  -- For lists: stack of {id, indent_level}
  local heading_stack = {}
  local list_stack = {}
  local current_heading = nil  -- Current heading context for lists

  for _, block in ipairs(blocks) do
    -- Generate ID if not present
    local node_id = block.id or generate_synthetic_id()

    -- Extract wikilinks, inclusions, and Bible references from body
    local refs = extract_wikilinks(block.text)
    local inclusions = extract_inclusions(block.text)
    local bible_refs = bible.parse_bible_refs(block.text)

    -- Combine all refs
    for _, ref in ipairs(inclusions) do
      table.insert(refs, ref)
    end
    for _, ref in ipairs(bible_refs) do
      table.insert(refs, ref)
    end

    -- Create node record
    local node = {
      id = node_id,
      type = block.type,
      body_md = block.text,
      children = {},
      props = {},  -- Empty for now, will be populated later (task_state, etc.)
      refs = refs  -- Wikilinks extracted from body
    }

    -- Store task state in props if applicable
    if block.task_state then
      node.props.task_state = block.task_state
    end

    -- Build backlinks index
    for _, ref in ipairs(refs) do
      if not backlinks[ref.target] then
        backlinks[ref.target] = {}
      end
      table.insert(backlinks[ref.target], node_id)
    end

    nodes_by_id[node_id] = node

    -- Determine parent based on type and context
    if block.type == "heading" then
      local level = get_heading_level(block.text)

      -- Pop heading stack until we find a parent (lower level)
      while #heading_stack > 0 and heading_stack[#heading_stack].level >= level do
        table.remove(heading_stack)
      end

      -- If stack has entries, top is parent
      if #heading_stack > 0 then
        local parent_id = heading_stack[#heading_stack].id
        table.insert(nodes_by_id[parent_id].children, node_id)
      else
        -- No parent, this is a root node
        table.insert(root_ids, node_id)
      end

      -- Push this heading onto stack
      table.insert(heading_stack, { id = node_id, level = level })

      -- Heading becomes new context for lists
      current_heading = { id = node_id, level = level }
      list_stack = {}  -- Reset list context

    elseif block.type == "list_item" or block.type == "task" then
      local indent = get_indent_level(block.text)

      -- Pop list stack until we find a valid parent (less indented)
      while #list_stack > 0 and list_stack[#list_stack].indent >= indent do
        table.remove(list_stack)
      end

      -- Determine parent: top of list stack OR current heading
      local parent_id = nil
      if #list_stack > 0 then
        parent_id = list_stack[#list_stack].id
      elseif current_heading then
        parent_id = current_heading.id
      end

      if parent_id then
        table.insert(nodes_by_id[parent_id].children, node_id)
      else
        -- No parent, this is a root node
        table.insert(root_ids, node_id)
      end

      -- Push this list item onto stack
      table.insert(list_stack, { id = node_id, indent = indent })

    elseif block.type == "text" then
      -- Plain text nodes: children of current heading, or root if no heading
      local parent_id = nil
      if current_heading then
        parent_id = current_heading.id
      end

      if parent_id then
        table.insert(nodes_by_id[parent_id].children, node_id)
      else
        -- No parent, this is a root node
        table.insert(root_ids, node_id)
      end
    end
  end

  return {
    nodes_by_id = nodes_by_id,
    root_ids = root_ids,
    backlinks = backlinks,
  }
end

return M
