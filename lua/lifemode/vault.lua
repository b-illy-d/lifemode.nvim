local M = {}

function M.list_files(vault_root)
  if not vault_root or vault_root == '' then
    error('vault_root is required')
  end

  if vim.fn.isdirectory(vault_root) == 0 then
    return {}
  end

  local files = {}
  local pattern = vault_root .. '/**/*.md'
  local paths = vim.fn.glob(pattern, true, true)

  for _, path in ipairs(paths) do
    local stat = vim.loop.fs_stat(path)
    if stat and stat.type == 'file' then
      table.insert(files, {
        path = path,
        mtime = stat.mtime.sec,
      })
    end
  end

  return files
end

return M
