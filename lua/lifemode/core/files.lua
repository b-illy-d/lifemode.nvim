local M = {}

function M.read_lines(path)
  if not path or vim.fn.filereadable(path) == 0 then
    return nil
  end
  local lines = vim.fn.readfile(path)
  if not lines or #lines == 0 then return nil end
  return lines
end

function M.write_lines(path, lines)
  vim.fn.writefile(lines, path)
end

return M
