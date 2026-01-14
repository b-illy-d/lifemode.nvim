-- Multi-file vault index
-- Scans vault root for .md files and builds global node location and backlinks index

local node = require('lifemode.node')

local M = {}

--- Scan vault root for all .md files
--- @param vault_root string Path to vault root directory
--- @return table Array of absolute file paths
function M.scan_vault(vault_root)
  -- Check if vault_root exists
  local stat = vim.loop.fs_stat(vault_root)
  if not stat or stat.type ~= "directory" then
    return {}
  end

  -- Use find command to recursively find all .md files
  local cmd = string.format("find %s -type f -name '*.md' 2>/dev/null", vim.fn.shellescape(vault_root))
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return {}
  end

  -- Split result into lines and filter empty
  local files = {}
  for line in result:gmatch("[^\r\n]+") do
    if line and #line > 0 then
      table.insert(files, line)
    end
  end

  return files
end

--- Build vault-wide index from all markdown files
--- @param vault_root string Path to vault root directory
--- @return table Index with node_locations and backlinks maps
function M.build_vault_index(vault_root)
  local files = M.scan_vault(vault_root)

  local node_locations = {}  -- Map: node_id -> {file, line}
  local backlinks = {}       -- Map: target -> array of source node_ids

  for _, file_path in ipairs(files) do
    -- Read file content into a buffer
    local lines = {}
    local f = io.open(file_path, "r")
    if f then
      for line in f:lines() do
        table.insert(lines, line)
      end
      f:close()

      -- Create a temporary buffer to parse
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

      -- Build nodes from buffer
      local result = node.build_nodes_from_buffer(bufnr)

      -- Process each node and store location
      for node_id, node_data in pairs(result.nodes_by_id) do
        -- Find line number for this node
        -- Match against node body_md to find the exact line
        local line_num = nil
        for i, line in ipairs(lines) do
          -- Check if this line contains the node ID
          if line:find("%^" .. vim.pesc(node_id), 1, false) then
            line_num = i
            break
          end
        end

        if line_num then
          node_locations[node_id] = {
            file = file_path,
            line = line_num,
          }
        end
      end

      -- Merge backlinks from this file
      for target, source_ids in pairs(result.backlinks) do
        if not backlinks[target] then
          backlinks[target] = {}
        end

        -- Add all source IDs from this file
        for _, source_id in ipairs(source_ids) do
          table.insert(backlinks[target], source_id)
        end
      end

      -- Delete temporary buffer
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end

  return {
    node_locations = node_locations,
    backlinks = backlinks,
  }
end

--- Get location for a node by ID
--- @param idx table Vault index
--- @param node_id string Node ID to lookup
--- @return table|nil Location with {file, line} or nil if not found
function M.get_node_location(idx, node_id)
  return idx.node_locations[node_id]
end

--- Get backlinks for a target
--- @param idx table Vault index
--- @param target string Target (wikilink page or Bible verse ID)
--- @return table Array of source node IDs that reference this target
function M.get_backlinks(idx, target)
  return idx.backlinks[target] or {}
end

return M
