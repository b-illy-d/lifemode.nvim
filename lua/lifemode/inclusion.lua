-- Node inclusion/transclusion functionality
-- Allows embedding nodes from anywhere in the vault into other notes

local M = {}

--- Get all indexable nodes from the vault index
--- @return table Array of {id, type, preview, file, line}
local function get_all_indexable_nodes()
  local lifemode = require('lifemode')
  local config = lifemode.get_config()

  if not config.vault_index then
    vim.api.nvim_echo({{'Vault index not built. Run :LifeModeRebuildIndex first.', 'WarningMsg'}}, true, {})
    return {}
  end

  local nodes = {}
  local index = config.vault_index

  -- Collect all nodes from the index
  for node_id, location in pairs(index.node_locations) do
    -- Read the node content for preview
    local file_path = location.file
    local line_num = location.line

    -- Read the line from file (if file exists)
    local preview = ""
    local file = io.open(file_path, "r")
    if file then
      local current_line = 0
      for line in file:lines() do
        current_line = current_line + 1
        if current_line == line_num then
          preview = line
          break
        end
      end
      file:close()
    end

    -- Extract type from node_id or content
    local node_type = "text"
    if preview:match("^%s*%--%s*%[.%]") then
      node_type = "task"
    elseif preview:match("^#+%s+") then
      node_type = "heading"
    end

    table.insert(nodes, {
      id = node_id,
      type = node_type,
      preview = preview,
      file = file_path,
      line = line_num,
    })
  end

  return nodes
end

--- Show node picker using Telescope or vim.ui.select fallback
--- @param callback function Function to call with selected node_id
local function show_node_picker(callback)
  local nodes = get_all_indexable_nodes()

  if #nodes == 0 then
    vim.api.nvim_echo({{'No indexable nodes found', 'WarningMsg'}}, true, {})
    return
  end

  -- Try to use Telescope if available
  local has_telescope, telescope = pcall(require, 'telescope')
  if has_telescope then
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')

    pickers.new({}, {
      prompt_title = 'Include Node',
      finder = finders.new_table({
        results = nodes,
        entry_maker = function(node)
          return {
            value = node,
            display = string.format("[%s] %s", node.type, node.preview:sub(1, 80)),
            ordinal = node.preview,
          }
        end
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            callback(selection.value.id)
          end
        end)
        return true
      end,
    }):find()
  else
    -- Fallback to vim.ui.select
    local items = {}
    local node_map = {}

    for i, node in ipairs(nodes) do
      local display = string.format("[%s] %s", node.type, node.preview:sub(1, 80))
      table.insert(items, display)
      node_map[i] = node
    end

    vim.ui.select(items, {
      prompt = 'Select node to include:',
    }, function(choice, idx)
      if idx then
        callback(node_map[idx].id)
      end
    end)
  end
end

--- Insert inclusion at cursor position
--- @param node_id string Node ID to include
local function insert_inclusion(node_id)
  local inclusion_text = string.format("![[%s]]", node_id)

  -- Get current buffer and cursor position
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1  -- Convert to 0-indexed
  local col = cursor[2]

  -- Get current line
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]

  -- Insert inclusion at cursor position
  local new_line = line:sub(1, col) .. inclusion_text .. line:sub(col + 1)
  vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, {new_line})

  -- Move cursor after insertion
  vim.api.nvim_win_set_cursor(0, {row + 1, col + #inclusion_text})

  vim.api.nvim_echo({{'Inclusion inserted: ' .. node_id, 'Normal'}}, false, {})
end

--- Show picker and insert selected node inclusion
function M.include_node_interactive()
  show_node_picker(function(node_id)
    insert_inclusion(node_id)
  end)
end

return M
