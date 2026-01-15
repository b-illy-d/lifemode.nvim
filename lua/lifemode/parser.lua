-- Minimal Markdown block parser for LifeMode MVP
-- Parses headings, list items, and tasks from a buffer

local M = {}

--- Extract ID suffix from line (format: ^id-here)
--- @param line string Line content
--- @return string|nil ID or nil if not present
local function extract_id(line)
  -- Match ^id at the end of the line
  -- ID can contain alphanumeric, hyphens, underscores
  local id = line:match("%^([%w%-_]+)%s*$")
  return id
end

--- Parse a single line into a block or nil
--- @param line string Line content
--- @param line_num number Line number (1-indexed)
--- @return table|nil Block or nil if not a recognized block type
local function parse_line(line, line_num)
  -- Skip empty lines
  if line:match("^%s*$") then
    return nil
  end

  -- Check for heading (must start with #)
  if line:match("^#+ ") then
    return {
      type = "heading",
      line_num = line_num,
      text = line,
      id = extract_id(line),
    }
  end

  -- Check for list item or task (may have leading spaces for indentation)
  local list_prefix = line:match("^%s*([%-%*]) ")
  if list_prefix then
    -- Check if it's a task (has [ ] or [x] after prefix)
    local task_match = line:match("^%s*[%-%*] %[([%sxX])%]")
    if task_match then
      local state = (task_match:lower() == "x") and "done" or "todo"
      return {
        type = "task",
        line_num = line_num,
        text = line,
        task_state = state,
        id = extract_id(line),
      }
    else
      return {
        type = "list_item",
        line_num = line_num,
        text = line,
        id = extract_id(line),
      }
    end
  end

  -- Plain text line (non-empty, not a heading/list/task)
  -- This allows inclusions and other inline content to be parsed
  return {
    type = "text",
    line_num = line_num,
    text = line,
    id = extract_id(line),
  }
end

--- Parse a buffer into a list of blocks
--- @param bufnr number Buffer handle
--- @return table[] List of blocks with fields: type, line_num, text, task_state, id
function M.parse_buffer(bufnr)
  local blocks = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for line_num, line in ipairs(lines) do
    local block = parse_line(line, line_num)
    if block then
      table.insert(blocks, block)
    end
  end

  return blocks
end

return M
