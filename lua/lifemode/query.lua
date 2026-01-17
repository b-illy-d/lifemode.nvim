local M = {}

function M.parse(query_string)
  local filter = {}

  if not query_string or query_string == '' then
    return filter
  end

  for part in query_string:gmatch('%S+') do
    local key, value = part:match('^([^:]+):(.+)$')
    if key and value then
      if key == 'tag' then
        value = value:gsub('^#', '')
      elseif key == 'priority' then
        value = tonumber(value)
      end
      filter[key] = value
    end
  end

  return filter
end

local function matches_filter(node, filter)
  for key, expected in pairs(filter) do
    if key == 'tag' then
      local found = false
      if node.tags then
        for _, tag in ipairs(node.tags) do
          if tag == expected then
            found = true
            break
          end
        end
      end
      if not found then return false end
    else
      if node[key] ~= expected then return false end
    end
  end
  return true
end

function M.execute(filter, nodes)
  if not filter or vim.tbl_isempty(filter) then
    return nodes
  end

  local results = {}
  for _, node in ipairs(nodes) do
    if matches_filter(node, filter) then
      table.insert(results, node)
    end
  end
  return results
end

return M
