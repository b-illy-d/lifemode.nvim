local M = {}
local vault = require('lifemode.vault')
local parser = require('lifemode.parser')

local _index = nil
local _vault_root = nil
local _autocmd_id = nil

function M.create()
  return {
    node_locations = {},
    tasks_by_state = {
      todo = {},
      done = {},
    },
    nodes_by_date = {},
    backlinks = {},
  }
end

function M.add_node(idx, node, file_path, mtime)
  if node.id then
    idx.node_locations[node.id] = {
      file = file_path,
      line = node.line,
      mtime = mtime,
    }
  end

  if node.type == 'task' then
    local state = node.state or 'todo'
    local task_entry = vim.tbl_extend('force', node, { _file = file_path })
    table.insert(idx.tasks_by_state[state], task_entry)
  end

  local date_str = os.date('%Y-%m-%d', mtime)
  if not idx.nodes_by_date[date_str] then
    idx.nodes_by_date[date_str] = {}
  end

  if node.id then
    table.insert(idx.nodes_by_date[date_str], { id = node.id, file = file_path })
  else
    table.insert(idx.nodes_by_date[date_str], { node = node, file = file_path })
  end

  if node.refs then
    local source_id = node.id or (file_path .. ':' .. node.line)
    local link_entry = {
      source_id = source_id,
      file = file_path,
      line = node.line,
    }

    for _, ref in ipairs(node.refs) do
      if ref.type == 'wikilink' and ref.target then
        if not idx.backlinks[ref.target] then
          idx.backlinks[ref.target] = {}
        end
        table.insert(idx.backlinks[ref.target], link_entry)
      elseif ref.type == 'bible' and ref.verse_ids then
        for _, verse_id in ipairs(ref.verse_ids) do
          if not idx.backlinks[verse_id] then
            idx.backlinks[verse_id] = {}
          end
          table.insert(idx.backlinks[verse_id], link_entry)
        end
      end
    end
  end

  return idx
end

function M.build(vault_root)
  if not vault_root or vault_root == '' then
    error('vault_root is required')
  end

  local idx = M.create()
  local files = vault.list_files(vault_root)

  for _, file_entry in ipairs(files) do
    local blocks = parser.parse_file(file_entry.path)

    for _, block in ipairs(blocks) do
      M.add_node(idx, block, file_entry.path, file_entry.mtime)
    end
  end

  return idx
end

function M.is_built()
  return _index ~= nil
end

function M.invalidate()
  _index = nil
  _vault_root = nil
end

function M.get_or_build(vault_root)
  if not vault_root or vault_root == '' then
    error('vault_root is required')
  end

  if _index and _vault_root == vault_root then
    return _index
  end

  _index = M.build(vault_root)
  _vault_root = vault_root

  return _index
end

function M.update_file(file_path, mtime)
  if not file_path or file_path == '' then
    error('file_path is required')
  end

  if not _index then
    return
  end

  local normalized_path = vim.fn.simplify(file_path)

  for node_id, loc in pairs(_index.node_locations) do
    local loc_normalized = vim.fn.simplify(loc.file)
    if loc_normalized == normalized_path then
      _index.node_locations[node_id] = nil
    end
  end

  for state, tasks in pairs(_index.tasks_by_state) do
    local new_tasks = {}
    for _, task in ipairs(tasks) do
      local task_normalized = vim.fn.simplify(task._file)
      if task_normalized ~= normalized_path then
        table.insert(new_tasks, task)
      end
    end
    _index.tasks_by_state[state] = new_tasks
  end

  for date_str, entries in pairs(_index.nodes_by_date) do
    local new_entries = {}
    for _, entry in ipairs(entries) do
      local entry_normalized = vim.fn.simplify(entry.file)
      if entry_normalized ~= normalized_path then
        table.insert(new_entries, entry)
      end
    end
    _index.nodes_by_date[date_str] = new_entries
  end

  for target, links in pairs(_index.backlinks) do
    local new_links = {}
    for _, link in ipairs(links) do
      local link_normalized = vim.fn.simplify(link.file)
      if link_normalized ~= normalized_path then
        table.insert(new_links, link)
      end
    end
    _index.backlinks[target] = new_links
  end

  local blocks = parser.parse_file(file_path)

  for _, block in ipairs(blocks) do
    M.add_node(_index, block, file_path, mtime)
  end
end

function M.setup_autocommands(vault_root)
  if not vault_root or vault_root == '' then
    error('vault_root is required')
  end

  if _autocmd_id then
    vim.api.nvim_del_autocmd(_autocmd_id)
    _autocmd_id = nil
  end

  local normalized_vault = vim.fn.simplify(vault_root)
  if not vim.endswith(normalized_vault, '/') then
    normalized_vault = normalized_vault .. '/'
  end

  _autocmd_id = vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = '*.md',
    callback = function(args)
      local file_path = vim.fn.simplify(args.file)

      if not vim.startswith(file_path, normalized_vault) then
        return
      end

      local stat = vim.loop.fs_stat(file_path)
      if stat and stat.type == 'file' then
        M.update_file(file_path, stat.mtime.sec)
      end
    end,
  })
end

function M.get_backlinks(target, idx)
  idx = idx or _index
  if not idx then return {} end
  return idx.backlinks[target] or {}
end

function M._reset_state()
  _index = nil
  _vault_root = nil
  if _autocmd_id then
    pcall(vim.api.nvim_del_autocmd, _autocmd_id)
    _autocmd_id = nil
  end
end

return M
