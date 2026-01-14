-- Backlinks view module
-- Shows backlinks for current node/page as a compiled navigable view

local references = require('lifemode.references')

local M = {}

--- Get target for backlinks view
--- Priority: 1) wikilink/Bible ref under cursor, 2) node_id at cursor, 3) filename
--- @param bufnr number Buffer handle
--- @param line number Line number (1-indexed)
--- @param col number Column number (0-indexed)
--- @return string|nil target The target to show backlinks for
--- @return string|nil target_type Type of target ("wikilink", "bible_verse", "page", "node")
function M.get_target_for_backlinks(bufnr, line, col)
  -- Try to extract target under cursor (wikilink or Bible ref)
  local target, target_type = references.extract_target_at_cursor(bufnr, line, col)
  if target then
    return target, target_type
  end

  -- Fall back to filename (page-level backlinks)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filename and #filename > 0 then
    -- Extract filename without path
    local name = filename:match("([^/]+)$")
    if name and #name > 0 then
      return name, "page"
    end
  end

  return nil, nil
end

--- Format a backlink entry for display
--- @param file string File path
--- @param line number Line number
--- @param content string Line content
--- @param vault_root string Vault root path for relative paths
--- @return table Array of lines to display
function M.format_backlink_entry(file, line, content, vault_root)
  -- Make file path relative to vault root if possible
  local display_path = file
  if vault_root and file:sub(1, #vault_root) == vault_root then
    display_path = file:sub(#vault_root + 2)  -- +2 to skip vault_root and slash
  end

  local entry = {}
  table.insert(entry, string.format("  %s:%d", display_path, line))
  table.insert(entry, string.format("    %s", content:gsub("^%s+", "")))  -- Trim leading whitespace
  table.insert(entry, "")

  return entry
end

--- Render backlinks view buffer
--- @param target string Target to show backlinks for
--- @param vault_index table Vault index with backlinks and node_locations
--- @return number View buffer number
function M.render_backlinks_view(target, vault_index)
  -- Create view buffer
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'lifemode')

  -- Set buffer name
  local bufname = string.format('[LifeMode: Backlinks to %s]', target)
  local existing = vim.fn.bufnr(bufname)
  if existing ~= -1 and existing ~= bufnr then
    bufname = string.format('[LifeMode: Backlinks to %s:%d]', target, bufnr)
  end
  vim.api.nvim_buf_set_name(bufnr, bufname)

  -- Get backlinks from index
  local backlink_source_ids = {}
  if vault_index and vault_index.backlinks then
    backlink_source_ids = vault_index.backlinks[target] or {}
  end

  -- Build content
  local lines = {}
  table.insert(lines, string.format("# Backlinks to: %s", target))
  table.insert(lines, "")

  if #backlink_source_ids == 0 then
    table.insert(lines, "No backlinks found.")
  else
    table.insert(lines, string.format("Found %d backlink(s):", #backlink_source_ids))
    table.insert(lines, "")

    -- Get vault root from config (if available)
    local vault_root = nil
    local ok, lifemode = pcall(require, 'lifemode')
    if ok then
      local config_ok, config = pcall(lifemode.get_config)
      if config_ok and config then
        vault_root = config.vault_root
      end
    end

    -- For each backlink, get location and read context
    for _, source_id in ipairs(backlink_source_ids) do
      local loc = vault_index.node_locations[source_id]
      if loc then
        -- Read line from file
        local f = io.open(loc.file, "r")
        if f then
          local line_num = 1
          for line in f:lines() do
            if line_num == loc.line then
              -- Format entry
              local entry_lines = M.format_backlink_entry(loc.file, loc.line, line, vault_root)
              for _, entry_line in ipairs(entry_lines) do
                table.insert(lines, entry_line)
              end
              break
            end
            line_num = line_num + 1
          end
          f:close()
        end
      end
    end
  end

  -- Set buffer content
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Make buffer read-only
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)

  -- Set up keymaps (same as standard view buffer)
  local opts = { buffer = bufnr, noremap = true, silent = true }

  -- gr: Find references
  vim.keymap.set('n', 'gr', function()
    require('lifemode.references').find_references_at_cursor()
  end, vim.tbl_extend('force', opts, { desc = 'Find references' }))

  -- gd: Go to definition
  vim.keymap.set('n', 'gd', function()
    require('lifemode.navigation').goto_definition()
  end, vim.tbl_extend('force', opts, { desc = 'Go to definition' }))

  -- q: Close window
  vim.keymap.set('n', 'q', '<cmd>close<CR>', vim.tbl_extend('force', opts, { desc = 'Close window' }))

  return bufnr
end

--- Show backlinks for target under cursor or current page
--- Main entry point for :LifeModeBacklinks and <Space>vb
function M.show_backlinks()
  -- Get current buffer and cursor position
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local col = cursor[2]

  -- Get target
  local target, target_type = M.get_target_for_backlinks(bufnr, line, col)

  if not target then
    vim.api.nvim_echo({{"No target found for backlinks", "WarningMsg"}}, true, {})
    return
  end

  -- Get vault index from config
  local vault_index = nil
  local ok, lifemode = pcall(require, 'lifemode')
  if ok then
    local config_ok, config = pcall(lifemode.get_config)
    if config_ok and config then
      vault_index = config.vault_index
    end
  end

  if not vault_index then
    vim.api.nvim_echo({{"No vault index found. Run :LifeModeRebuildIndex first.", "WarningMsg"}}, true, {})
    return
  end

  -- Render backlinks view
  local view_bufnr = M.render_backlinks_view(target, vault_index)

  -- Open in current window
  vim.api.nvim_set_current_buf(view_bufnr)

  -- Show message
  vim.api.nvim_echo({{
    string.format("Showing backlinks for: %s", target),
    "Normal"
  }}, true, {})
end

return M
