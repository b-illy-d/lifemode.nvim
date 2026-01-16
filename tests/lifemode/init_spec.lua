local lifemode = require('lifemode')

describe('lifemode.setup', function()
  before_each(function()
    lifemode._reset_state()
  end)

  it('fails when vault_root is missing', function()
    assert.has_error(function()
      lifemode.setup({})
    end, 'vault_root is required')
  end)

  it('fails when vault_root is empty string', function()
    assert.has_error(function()
      lifemode.setup({ vault_root = '' })
    end, 'vault_root is required')
  end)

  it('accepts valid vault_root and sets defaults', function()
    lifemode.setup({ vault_root = '/tmp/test_vault' })

    local config = lifemode.get_config()
    assert.equals('/tmp/test_vault', config.vault_root)
    assert.equals('<Space>', config.leader)
    assert.equals(10, config.max_depth)
    assert.equals('ESV', config.bible_version)
    assert.equals('daily', config.default_view)
    assert.equals(3, config.daily_view_expanded_depth)
    assert.equals('due_date', config.tasks_default_grouping)
    assert.equals(false, config.auto_index_on_startup)
    assert.equals(100, config.max_nodes_per_action)
  end)

  it('allows overriding default config', function()
    lifemode.setup({
      vault_root = '/tmp/test_vault',
      leader = '<leader>m',
      max_depth = 5,
      bible_version = 'RSVCE',
      default_view = 'tasks',
      max_nodes_per_action = 50,
    })

    local config = lifemode.get_config()
    assert.equals('/tmp/test_vault', config.vault_root)
    assert.equals('<leader>m', config.leader)
    assert.equals(5, config.max_depth)
    assert.equals('RSVCE', config.bible_version)
    assert.equals('tasks', config.default_view)
    assert.equals(50, config.max_nodes_per_action)
  end)
end)

describe('LifeMode commands', function()
  before_each(function()
    lifemode._reset_state()
    lifemode.setup({ vault_root = '/tmp/test_vault' })
  end)

  it('creates :LifeModeHello command', function()
    local has_command = vim.fn.exists(':LifeModeHello') == 2
    assert.is_true(has_command)
  end)

  it('creates :LifeMode command', function()
    local has_command = vim.fn.exists(':LifeMode') == 2
    assert.is_true(has_command)
  end)
end)
