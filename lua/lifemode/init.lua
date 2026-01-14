-- LifeMode: Markdown-native productivity + wiki system for Neovim
-- Main entry point

local M = {}

-- Internal state
local config = nil

-- Default configuration
local defaults = {
  leader = '<Space>',
  max_depth = 10,
  bible_version = 'ESV',
}

-- Setup function - entry point for plugin configuration
function M.setup(user_config)
  user_config = user_config or {}

  -- Validate required config
  if not user_config.vault_root then
    error('vault_root is required')
  end

  if type(user_config.vault_root) ~= 'string' then
    error('vault_root must be a string')
  end

  -- Merge user config with defaults
  config = vim.tbl_extend('force', defaults, user_config)

  -- Create :LifeModeHello command
  vim.api.nvim_create_user_command('LifeModeHello', function()
    local lines = {
      'LifeMode Configuration:',
      '  vault_root: ' .. config.vault_root,
      '  leader: ' .. config.leader,
      '  max_depth: ' .. config.max_depth,
      '  bible_version: ' .. config.bible_version,
    }
    for _, line in ipairs(lines) do
      vim.api.nvim_echo({{line, 'Normal'}}, true, {})
    end
  end, {
    desc = 'Show LifeMode configuration'
  })
end

-- Get current configuration (for testing and internal use)
function M.get_config()
  if not config then
    error('LifeMode is not configured. Call setup() first.')
  end
  return config
end

-- Reset config for testing
function M._reset_for_testing()
  config = nil
  -- Remove command if it exists
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeHello')
  end)
end

return M
