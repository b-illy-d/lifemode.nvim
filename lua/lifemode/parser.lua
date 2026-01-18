local M = {}

function M.parse_buffer(bufnr)
  if bufnr == 0 or not bufnr then
    error('Invalid buffer number')
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return M._parse_node(lines)
end

function M.parse_file(path)
  if not path or path == '' then
    error('path is required')
  end

  local lines = vim.fn.readfile(path)
  return M._parse_node(lines)
end

function M._parse_node(lines)
  local props, content_start = M._extract_properties(lines)

  local node_type = props.type or 'note'
  local node_id = props.id
  local created = props.created

  local content_lines = {}
  for i = content_start, #lines do
    table.insert(content_lines, lines[i])
  end
  local content = table.concat(content_lines, '\n')

  local node = {
    type = node_type,
    id = node_id,
    created = created,
    props = props,
    content = content,
    refs = M._extract_all_refs(content),
  }

  if node_type == 'task' then
    M._enrich_task_node(node, content)
  elseif node_type == 'project' then
    node.references = M._extract_project_refs(content)
  end

  return node
end

function M._extract_properties(lines)
  local props = {}
  local content_start = 1

  for i, line in ipairs(lines) do
    local key, value = line:match('^([%w_]+)::%s*(.*)$')
    if key and value then
      props[key] = value
      content_start = i + 1
    elseif line:match('^%s*$') and next(props) then
      content_start = i + 1
      break
    elseif next(props) then
      break
    else
      break
    end
  end

  return props, content_start
end

function M._enrich_task_node(node, content)
  local task_line = content:match('^%s*%-%s+%[([%sxX])%]%s+(.*)$')
  if not task_line then
    for line in content:gmatch('[^\n]+') do
      local state_char, rest = line:match('^%s*%-%s+%[([%sxX])%]%s+(.*)$')
      if state_char then
        node.state = (state_char == 'x' or state_char == 'X') and 'done' or 'todo'
        node.text = M._strip_metadata(rest)
        node.priority = M._extract_priority(rest)
        node.due = M._extract_due(rest)
        node.tags = M._extract_tags(rest)
        return
      end
    end
    node.state = 'todo'
    node.text = ''
    return
  end

  local state_char, rest = content:match('^%s*%-%s+%[([%sxX])%]%s+(.*)$')
  if state_char then
    node.state = (state_char == 'x' or state_char == 'X') and 'done' or 'todo'
    node.text = M._strip_metadata(rest:match('^([^\n]*)'))
    node.priority = M._extract_priority(rest)
    node.due = M._extract_due(rest)
    node.tags = M._extract_tags(rest)
  end
end

function M._extract_project_refs(content)
  local refs = {}

  for line in content:gmatch('[^\n]+') do
    local target = line:match('^%[%[([^%]]+)%]%]%s*$')
    if target then
      table.insert(refs, target)
    end
  end

  return refs
end

function M._extract_priority(text)
  local priorities = {}

  for i = 1, #text do
    local char = text:sub(i, i)
    if char == '!' then
      local digit = text:sub(i+1, i+1)
      if digit:match('[1-5]') then
        local after = i + 2 <= #text and text:sub(i+2, i+2) or ' '
        if not after:match('%w') then
          table.insert(priorities, tonumber(digit))
        end
      end
    end
  end

  if #priorities > 0 then
    return priorities[#priorities]
  end
  return nil
end

function M._extract_due(text)
  local due = text:match('@due%((%d%d%d%d%-%d%d%-%d%d)%)')
  return due
end

function M._extract_tags(text)
  local tags = {}
  local seen = {}

  for i = 1, #text do
    local char = text:sub(i, i)
    if char == '#' then
      local before = i > 1 and text:sub(i-1, i-1) or ' '
      if before:match('[%s%p]') or before == '' then
        local tag_match = text:sub(i+1):match('^([%w_/%-]+)')
        if tag_match and not tag_match:match('^[%d]+$') and not seen[tag_match] then
          table.insert(tags, tag_match)
          seen[tag_match] = true
        end
      end
    end
  end

  if #tags > 0 then
    return tags
  end
  return nil
end

function M._strip_metadata(text)
  if not text then return '' end
  text = text:gsub('!%d+%s*', '')
  text = text:gsub('@due%([^)]+%)%s*', '')
  text = text:gsub('%s*#[%w_/%-]+', '')
  text = vim.trim(text)
  text = text:gsub('%s+', ' ')
  return text
end

function M._extract_wikilinks(text)
  local refs = {}
  local pos = 1

  while pos <= #text do
    local start_pos = text:find('%[%[', pos)
    if not start_pos then break end

    local end_pos = text:find('%]%]', start_pos + 2)
    if not end_pos then break end

    local content = text:sub(start_pos + 2, end_pos - 1)
    local target, display = content:match('^([^|]+)|(.+)$')

    if not target then
      target = content
      display = nil
    end

    table.insert(refs, {
      type = 'wikilink',
      target = target,
      display = display,
    })

    pos = end_pos + 2
  end

  return refs
end

function M._extract_bible_refs(text)
  local bible = require('lifemode.bible')
  local bible_refs = bible.extract_refs(text)
  if not bible_refs then return {} end

  local refs = {}
  for _, br in ipairs(bible_refs) do
    table.insert(refs, {
      type = 'bible',
      book = br.book,
      chapter = br.chapter,
      verse_start = br.verse_start,
      verse_end = br.verse_end,
      verse_ids = br.verse_ids,
    })
  end
  return refs
end

function M._extract_all_refs(text)
  local refs = {}

  local wikilinks = M._extract_wikilinks(text)
  for _, ref in ipairs(wikilinks) do
    table.insert(refs, ref)
  end

  local bible_refs = M._extract_bible_refs(text)
  for _, ref in ipairs(bible_refs) do
    table.insert(refs, ref)
  end

  if #refs > 0 then
    return refs
  end
  return nil
end

function M._parse_lines(lines)
  local node = M._parse_node(lines)
  return { node }
end

return M
