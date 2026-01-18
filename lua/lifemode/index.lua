local M = {}
local vault = require('lifemode.vault')
local parser = require('lifemode.parser')

local _index = nil
local _vault_root = nil
local _autocmd_id = nil

function M.create()
  return {
    nodes = {},
    nodes_by_type = {},
    nodes_by_date = {},
    tasks_by_state = {
      todo = {},
      done = {},
    },
    backlinks = {},
  }
end

function M.add_node(idx, node, file_path, mtime)
  if not node.id then
    local filename = vim.fn.fnamemodify(file_path, ':t:r')
    node.id = filename
  end

  node._file = file_path
  node._mtime = mtime

  idx.nodes[node.id] = node

  local node_type = node.type or 'note'
  if not idx.nodes_by_type[node_type] then
    idx.nodes_by_type[node_type] = {}
  end
  table.insert(idx.nodes_by_type[node_type], node)

  if node_type == 'task' then
    local state = node.state or 'todo'
    if not idx.tasks_by_state[state] then
      idx.tasks_by_state[state] = {}
    end
    table.insert(idx.tasks_by_state[state], node)
  end

  local date_str = node.created or os.date('%Y-%m-%d', mtime)
  if not idx.nodes_by_date[date_str] then
    idx.nodes_by_date[date_str] = {}
  end
  table.insert(idx.nodes_by_date[date_str], node)

  if node.refs then
    local link_entry = {
      source_id = node.id,
      file = file_path,
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
    local ok, node = pcall(parser.parse_file, file_entry.path)
    if ok and node then
      M.add_node(idx, node, file_entry.path, file_entry.mtime)
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

function M._remove_node_from_index(idx, node_id, file_path)
  local normalized_path = vim.fn.simplify(file_path)

  if idx.nodes[node_id] then
    idx.nodes[node_id] = nil
  end

  for node_type, nodes in pairs(idx.nodes_by_type) do
    local new_nodes = {}
    for _, n in ipairs(nodes) do
      if vim.fn.simplify(n._file) ~= normalized_path then
        table.insert(new_nodes, n)
      end
    end
    idx.nodes_by_type[node_type] = new_nodes
  end

  for state, tasks in pairs(idx.tasks_by_state) do
    local new_tasks = {}
    for _, task in ipairs(tasks) do
      if vim.fn.simplify(task._file) ~= normalized_path then
        table.insert(new_tasks, task)
      end
    end
    idx.tasks_by_state[state] = new_tasks
  end

  for date_str, nodes in pairs(idx.nodes_by_date) do
    local new_nodes = {}
    for _, n in ipairs(nodes) do
      if vim.fn.simplify(n._file) ~= normalized_path then
        table.insert(new_nodes, n)
      end
    end
    idx.nodes_by_date[date_str] = new_nodes
  end

  for target, links in pairs(idx.backlinks) do
    local new_links = {}
    for _, link in ipairs(links) do
      if vim.fn.simplify(link.file) ~= normalized_path then
        table.insert(new_links, link)
      end
    end
    idx.backlinks[target] = new_links
  end
end

function M.update_file(file_path, mtime)
  if not file_path or file_path == '' then
    error('file_path is required')
  end

  if not _index then
    return
  end

  local normalized_path = vim.fn.simplify(file_path)

  for node_id, node in pairs(_index.nodes) do
    if vim.fn.simplify(node._file) == normalized_path then
      M._remove_node_from_index(_index, node_id, file_path)
      break
    end
  end

  local ok, node = pcall(parser.parse_file, file_path)
  if ok and node then
    M.add_node(_index, node, file_path, mtime)
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

function M.get_node(node_id, idx)
  idx = idx or _index
  if not idx then return nil end
  return idx.nodes[node_id]
end

function M.get_nodes_by_type(node_type, idx)
  idx = idx or _index
  if not idx then return {} end
  return idx.nodes_by_type[node_type] or {}
end

function M.get_all_nodes(idx)
  idx = idx or _index
  if not idx then return {} end

  local result = {}
  for _, node in pairs(idx.nodes) do
    table.insert(result, node)
  end
  return result
end

function M._reset_state()
  _index = nil
  _vault_root = nil
  if _autocmd_id then
    pcall(vim.api.nvim_del_autocmd, _autocmd_id)
    _autocmd_id = nil
  end
end

function M._get_cached_index()
  return _index
end

return M
