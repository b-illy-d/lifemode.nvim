local M = {}

function M.get_at_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]

  local start_pos = nil
  local end_pos = nil

  local search_pos = 1
  while search_pos <= #line do
    local s, e = line:find('%[%[.-%]%]', search_pos)
    if not s then break end

    if col >= s - 1 and col <= e - 1 then
      start_pos = s
      end_pos = e
      break
    end

    search_pos = e + 1
  end

  if not start_pos then return nil end

  local content = line:sub(start_pos + 2, end_pos - 2)

  local target = content:match('^([^|]+)|') or content
  local display = content:match('|(.+)$')

  local page, heading, block_id

  local hash_pos = target:find('#')
  local caret_pos = target:find('%^')

  if hash_pos then
    page = target:sub(1, hash_pos - 1)
    heading = target:sub(hash_pos + 1)
  elseif caret_pos then
    page = target:sub(1, caret_pos - 1)
    block_id = target:sub(caret_pos + 1)
  else
    page = target
  end

  return {
    target = target,
    page = page,
    heading = heading,
    block_id = block_id,
    display = display,
    start_col = start_pos,
    end_col = end_pos,
  }
end

function M.resolve_file(page, vault_root)
  local path = vault_root .. '/' .. page .. '.md'
  if vim.fn.filereadable(path) == 1 then
    return path
  end

  local files = vim.fn.globpath(vault_root, '**/' .. page .. '.md', false, true)
  if #files > 0 then
    return files[1]
  end

  return nil
end

function M.find_heading_line(file_path, heading)
  local lines = vim.fn.readfile(file_path)
  for i, line in ipairs(lines) do
    local h = line:match('^#+%s+(.*)$')
    if h then
      h = h:gsub('%s*%^[%w%-_:]+%s*$', '')
      h = vim.trim(h)
      if h == heading then
        return i
      end
    end
  end
  return nil
end

function M.find_block_id_line(file_path, block_id)
  local lines = vim.fn.readfile(file_path)
  local pattern = '%^' .. vim.pesc(block_id) .. '%s*$'
  for i, line in ipairs(lines) do
    if line:match(pattern) then
      return i
    end
  end
  return nil
end

function M.goto_definition(vault_root)
  local wikilink = M.get_at_cursor()
  if not wikilink then return end

  local file = M.resolve_file(wikilink.page, vault_root)
  if not file then
    vim.notify('File not found: ' .. wikilink.page .. '.md', vim.log.levels.WARN)
    return
  end

  vim.cmd('edit ' .. vim.fn.fnameescape(file))

  local target_line = nil

  if wikilink.heading then
    target_line = M.find_heading_line(file, wikilink.heading)
  elseif wikilink.block_id then
    target_line = M.find_block_id_line(file, wikilink.block_id)
  end

  if target_line then
    vim.api.nvim_win_set_cursor(0, {target_line, 0})
  end
end

return M
