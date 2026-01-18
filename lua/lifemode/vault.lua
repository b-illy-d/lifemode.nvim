local M = {}

local TYPE_FOLDERS = {
  note = 'notes',
  task = 'tasks',
  quote = 'quotes',
  source = 'sources',
  citation = 'citations',
  project = 'projects',
}

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

function M.generate_uuid()
  local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return string.gsub(template, '[xy]', function(c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', v)
  end)
end

function M.generate_short_id()
  local chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
  local id = ''
  for _ = 1, 8 do
    local idx = math.random(1, #chars)
    id = id .. chars:sub(idx, idx)
  end
  return id
end

function M.get_type_folder(node_type)
  return TYPE_FOLDERS[node_type] or (node_type .. 's')
end

function M.ensure_type_folder(vault_root, node_type)
  local folder = vault_root .. '/' .. M.get_type_folder(node_type)
  if vim.fn.isdirectory(folder) == 0 then
    vim.fn.mkdir(folder, 'p')
  end
  return folder
end

function M.create_node(vault_root, node_type, props, content)
  if not vault_root or vault_root == '' then
    error('vault_root is required')
  end

  node_type = node_type or 'note'
  props = props or {}
  content = content or ''

  local folder = M.ensure_type_folder(vault_root, node_type)

  local node_id = props.id or M.generate_short_id()
  local filename = node_type .. '-' .. node_id .. '.md'
  local filepath = folder .. '/' .. filename

  local lines = {}

  table.insert(lines, 'type:: ' .. node_type)
  table.insert(lines, 'id:: ' .. node_id)
  table.insert(lines, 'created:: ' .. os.date('%Y-%m-%d'))

  for key, value in pairs(props) do
    if key ~= 'type' and key ~= 'id' and key ~= 'created' then
      table.insert(lines, key .. ':: ' .. tostring(value))
    end
  end

  table.insert(lines, '')

  if content ~= '' then
    for line in (content .. '\n'):gmatch('([^\n]*)\n') do
      table.insert(lines, line)
    end
  end

  vim.fn.writefile(lines, filepath)

  return {
    id = node_id,
    type = node_type,
    path = filepath,
  }
end

function M.create_task(vault_root, text, props)
  props = props or {}
  local task_line = '- [ ] ' .. text

  if props.priority then
    task_line = task_line .. ' !' .. props.priority
  end
  if props.due then
    task_line = task_line .. ' @due(' .. props.due .. ')'
  end
  if props.tags then
    for _, tag in ipairs(props.tags) do
      task_line = task_line .. ' #' .. tag
    end
  end

  return M.create_node(vault_root, 'task', props, task_line)
end

function M.create_note(vault_root, title, content, props)
  props = props or {}
  local body = ''
  if title and title ~= '' then
    body = '# ' .. title .. '\n\n'
  end
  if content and content ~= '' then
    body = body .. content
  end

  return M.create_node(vault_root, 'note', props, body)
end

function M.create_project(vault_root, title, refs, props)
  props = props or {}
  props.title = title

  local body = ''
  if refs then
    for _, ref in ipairs(refs) do
      body = body .. '[[' .. ref .. ']]\n'
    end
  end

  return M.create_node(vault_root, 'project', props, body)
end

return M
