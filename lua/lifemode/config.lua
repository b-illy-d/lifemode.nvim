local M = {}

local DEFAULTS = {
  leader = '<Space>',
  max_depth = 10,
  max_nodes_per_action = 100,
  bible_version = 'ESV',
  default_view = 'daily',
  daily_view_expanded_depth = 3,
  tasks_default_grouping = 'due_date',
  auto_index_on_startup = false,
}

local VALIDATORS = {
  vault_root = function(v)
    if not v or v == '' then return false, 'vault_root is required' end
    if type(v) ~= 'string' then return false, 'vault_root must be a string' end
    if vim.trim(v) == '' then return false, 'vault_root cannot be whitespace only' end
    return true
  end,

  leader = function(v)
    if type(v) ~= 'string' then return false, 'leader must be a string' end
    return true
  end,

  max_depth = function(v)
    if type(v) ~= 'number' or v <= 0 then return false, 'max_depth must be a positive number' end
    return true
  end,

  max_nodes_per_action = function(v)
    if type(v) ~= 'number' or v <= 0 then return false, 'max_nodes_per_action must be a positive number' end
    return true
  end,

  bible_version = function(v)
    if type(v) ~= 'string' then return false, 'bible_version must be a string' end
    return true
  end,

  default_view = function(v)
    if type(v) ~= 'string' then return false, 'default_view must be a string' end
    return true
  end,

  daily_view_expanded_depth = function(v)
    if type(v) ~= 'number' or v < 0 then return false, 'daily_view_expanded_depth must be a non-negative number' end
    return true
  end,

  tasks_default_grouping = function(v)
    if type(v) ~= 'string' then return false, 'tasks_default_grouping must be a string' end
    return true
  end,

  auto_index_on_startup = function(v)
    if type(v) ~= 'boolean' then return false, 'auto_index_on_startup must be a boolean' end
    return true
  end,
}

function M.validate(opts)
  local ok, err = VALIDATORS.vault_root(opts.vault_root)
  if not ok then error(err) end

  local merged = vim.tbl_deep_extend('force', DEFAULTS, opts)

  for key, validator in pairs(VALIDATORS) do
    if merged[key] ~= nil then
      ok, err = validator(merged[key])
      if not ok then error(err) end
    end
  end

  return merged
end

function M.defaults()
  return vim.deepcopy(DEFAULTS)
end

return M
