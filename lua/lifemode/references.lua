-- References module - find all occurrences of a link/node target
-- Provides LSP-style "find references" functionality for wikilinks and Bible verses

local bible = require('lifemode.bible')

local M = {}

--- Extract target under cursor from wikilink or Bible reference
--- @param bufnr number Buffer handle
--- @param line number Line number (1-indexed)
--- @param col number Column number (0-indexed)
--- @return string|nil target The extracted target (wikilink page or Bible verse ID)
--- @return string|nil ref_type Type of reference ("wikilink" or "bible_verse")
function M.extract_target_at_cursor(bufnr, line, col)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)
  if #lines == 0 then
    return nil, nil
  end

  local text = lines[1]
  if not text or #text == 0 then
    return nil, nil
  end

  -- Check for wikilink: [[...]]
  -- Find all wikilinks in the line and check if cursor is inside one
  for match_start, target, match_end in text:gmatch("()%[%[([^%]]+)%]%]()") do
    -- Convert to 0-indexed positions
    local start_col = match_start - 1
    local end_col = match_end - 1

    if col >= start_col and col < end_col then
      return target, "wikilink"
    end
  end

  -- Check for Bible reference
  -- Pattern: ([%d]?%s?[%a]+)%s+(%d+):(%d+)%-?(%d*)
  -- Find all Bible refs in the line and check if cursor is inside one
  for match_start, book, chapter, verse_start, verse_end in text:gmatch("()([%d]?%s?[%a]+)%s+(%d+):(%d+)%-?(%d*)") do
    -- Calculate match end position (rough estimate)
    local book_part = book .. " " .. chapter .. ":" .. verse_start
    if verse_end and #verse_end > 0 then
      book_part = book_part .. "-" .. verse_end
    end
    local match_len = #book_part
    local end_pos = match_start + match_len - 1

    -- Convert to 0-indexed
    local start_col = match_start - 1
    local end_col = end_pos - 1

    if col >= start_col and col < end_col then
      -- Parse the Bible reference to get normalized ID
      local refs = bible.parse_bible_refs(text)
      if #refs > 0 then
        -- Return first verse of range (primary target)
        return refs[1].target, "bible_verse"
      end
    end
  end

  return nil, nil
end

--- Find all references to a target in buffer
--- @param bufnr number Buffer handle
--- @param target string Target to find (wikilink page or Bible verse ID)
--- @param ref_type string Type of reference ("wikilink" or "bible_verse")
--- @return table Array of references with format { bufnr, lnum, col, text }
function M.find_references_in_buffer(bufnr, target, ref_type)
  local refs = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for lnum, line in ipairs(lines) do
    if ref_type == "wikilink" then
      -- Find all wikilinks in line that match target
      local search_pos = 1
      while true do
        local match_start, match_end, match_target = line:find("%[%[([^%]]+)%]%]", search_pos)
        if not match_start then break end

        if match_target == target then
          table.insert(refs, {
            bufnr = bufnr,
            lnum = lnum,
            col = match_start,
            text = line,
          })
        end

        search_pos = match_end + 1
      end

    elseif ref_type == "bible_verse" then
      -- Parse all Bible references in line and check if any match target
      local bible_refs = bible.parse_bible_refs(line)

      -- Track positions where refs were found
      local found_positions = {}

      for _, ref in ipairs(bible_refs) do
        if ref.target == target then
          -- Find position of this reference in the line
          -- We need to find the original text that generated this ref
          -- For simplicity, use pattern matching to find approximate position
          local search_pos = 1
          for match_start, book, chapter, verse in line:gmatch("()([%d]?%s?[%a]+)%s+(%d+):(%d+)") do
            -- Check if this pattern already recorded
            local already_found = false
            for _, pos in ipairs(found_positions) do
              if pos == match_start then
                already_found = true
                break
              end
            end

            if not already_found then
              table.insert(found_positions, match_start)
              table.insert(refs, {
                bufnr = bufnr,
                lnum = lnum,
                col = match_start,
                text = line,
              })
              break  -- Only add one entry per reference in line
            end
          end
        end
      end
    end
  end

  return refs
end

--- Populate quickfix list with references
--- @param refs table Array of reference locations
--- @param bufnr number Buffer handle
--- @param target string Target being referenced (for quickfix title)
function M.populate_quickfix(refs, bufnr, target)
  -- Convert refs to quickfix format
  local qf_items = {}
  for _, ref in ipairs(refs) do
    table.insert(qf_items, {
      bufnr = ref.bufnr,
      lnum = ref.lnum,
      col = ref.col,
      text = ref.text,
    })
  end

  -- Set quickfix list with title
  -- First set the items
  vim.fn.setqflist(qf_items, 'r')
  -- Then set the title separately
  local title = "References to: " .. (target or "unknown")
  vim.fn.setqflist({}, 'a', { title = title })
end

--- Find references for target under cursor and populate quickfix
--- Main entry point for `gr` mapping
function M.find_references_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local col = cursor[2]

  -- Extract target at cursor
  local target, ref_type = M.extract_target_at_cursor(bufnr, line, col)

  if not target then
    vim.api.nvim_echo({{"No reference found under cursor", "WarningMsg"}}, true, {})
    return
  end

  -- Find all references in buffer
  local refs = M.find_references_in_buffer(bufnr, target, ref_type)

  if #refs == 0 then
    vim.api.nvim_echo({{string.format("No references found for: %s", target), "WarningMsg"}}, true, {})
    return
  end

  -- Populate quickfix
  M.populate_quickfix(refs, bufnr, target)

  -- Open quickfix window
  vim.cmd('copen')

  -- Show message
  vim.api.nvim_echo({{
    string.format("Found %d reference(s) to: %s", #refs, target),
    "Normal"
  }}, true, {})
end

return M
