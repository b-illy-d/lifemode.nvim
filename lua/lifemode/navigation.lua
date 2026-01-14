-- Navigation module - LSP-style "go to definition" for wikilinks and Bible refs
-- Provides `gd` functionality to navigate to link targets

local references = require('lifemode.references')

local M = {}

--- Parse wikilink target into components
--- @param target string Wikilink target (e.g., "Page", "Page#Heading", "Page^id")
--- @return string page Page name
--- @return string|nil heading Heading name (if present)
--- @return string|nil block_id Block ID (if present)
function M.parse_wikilink_target(target)
  if not target then
    return nil, nil, nil
  end

  -- Check for block reference: Page^id
  local page, block_id = target:match("^([^%^]+)%^(.+)$")
  if page and block_id then
    return page, nil, block_id
  end

  -- Check for heading reference: Page#Heading
  local page_with_heading, heading = target:match("^([^#]+)#(.+)$")
  if page_with_heading and heading then
    return page_with_heading, heading, nil
  end

  -- Simple page reference
  return target, nil, nil
end

--- Find file in vault by page name
--- Searches for PageName.md in vault_root recursively
--- @param page_name string Page name to find
--- @return string|nil path Absolute path to file, or nil if not found
function M.find_file_in_vault(page_name)
  local lifemode = require('lifemode')
  local config = lifemode.get_config()

  if not config or not config.vault_root then
    return nil
  end

  local vault_root = config.vault_root

  -- Construct expected filename
  local filename = page_name .. '.md'

  -- Use find command to search for file (case-sensitive)
  local cmd = string.format("find %s -type f -name %s 2>/dev/null | head -n 1",
    vim.fn.shellescape(vault_root),
    vim.fn.shellescape(filename))

  local result = vim.fn.system(cmd)

  -- Trim whitespace and check if file exists
  result = result:gsub('^%s+', ''):gsub('%s+$', '')

  if result and #result > 0 then
    return result
  end

  return nil
end

--- Jump to heading in buffer
--- @param bufnr number Buffer handle
--- @param heading string Heading text to find (without # prefix)
--- @return boolean found True if heading found and cursor moved
function M.jump_to_heading(bufnr, heading)
  if not heading then
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Search for heading (with any number of # prefix)
  for lnum, line in ipairs(lines) do
    -- Match heading pattern: one or more #, space, then heading text
    local heading_text = line:match("^#+%s+(.+)$")
    if heading_text and heading_text == heading then
      -- Found heading - set current buffer and move cursor
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, {lnum, 0})
      return true
    end
  end

  return false
end

--- Jump to block with ID in buffer
--- @param bufnr number Buffer handle
--- @param block_id string Block ID to find (without ^ prefix)
--- @return boolean found True if block ID found and cursor moved
function M.jump_to_block_id(bufnr, block_id)
  if not block_id then
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Escape special characters in block_id for pattern matching
  local escaped_id = block_id:gsub("([%-%.%+%[%]%(%)%$%^%%%?%*])", "%%%1")

  -- Search for block ID pattern: ^id at end of line or before space
  for lnum, line in ipairs(lines) do
    -- Match block ID: ^id-pattern (anywhere in line)
    if line:match("%^" .. escaped_id) then
      -- Found block ID - set current buffer and move cursor
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_win_set_cursor(0, {lnum, 0})
      return true
    end
  end

  return false
end

--- Go to definition for target under cursor
--- Main entry point for `gd` mapping
function M.goto_definition()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local col = cursor[2]

  -- Extract target at cursor
  local target, ref_type = references.extract_target_at_cursor(bufnr, line, col)

  if not target then
    vim.api.nvim_echo({{"No link or reference found under cursor", "WarningMsg"}}, true, {})
    return
  end

  -- Handle Bible references (provider stub for MVP)
  if ref_type == "bible_verse" then
    vim.api.nvim_echo({{
      string.format("Bible verse: %s (provider not yet implemented)", target),
      "Normal"
    }}, true, {})
    return
  end

  -- Handle wikilinks
  if ref_type == "wikilink" then
    -- Parse target into components
    local page, heading, block_id = M.parse_wikilink_target(target)

    -- Find file in vault
    local filepath = M.find_file_in_vault(page)

    if not filepath then
      vim.api.nvim_echo({{
        string.format("File not found: %s.md", page),
        "WarningMsg"
      }}, true, {})
      return
    end

    -- Open file
    vim.cmd('edit ' .. vim.fn.fnameescape(filepath))

    -- Jump to heading or block ID if specified
    if heading then
      local found = M.jump_to_heading(vim.api.nvim_get_current_buf(), heading)
      if not found then
        vim.api.nvim_echo({{
          string.format("Heading not found: %s", heading),
          "WarningMsg"
        }}, true, {})
      end
    elseif block_id then
      local found = M.jump_to_block_id(vim.api.nvim_get_current_buf(), block_id)
      if not found then
        vim.api.nvim_echo({{
          string.format("Block ID not found: ^%s", block_id),
          "WarningMsg"
        }}, true, {})
      end
    end

    return
  end
end

return M
