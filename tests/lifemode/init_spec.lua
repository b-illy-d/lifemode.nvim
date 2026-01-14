local lifemode = require('lifemode')

describe('lifemode.setup', function()
  before_each(function()
    -- Reset config between tests
    lifemode._reset_for_testing()
  end)

  it('requires vault_root to be provided', function()
    assert.has_error(function()
      lifemode.setup({})
    end, 'vault_root is required')
  end)

  it('requires vault_root to be a string', function()
    assert.has_error(function()
      lifemode.setup({ vault_root = 123 })
    end, 'vault_root must be a string')
  end)

  it('accepts valid vault_root', function()
    assert.has_no.errors(function()
      lifemode.setup({ vault_root = '/path/to/vault' })
    end)
  end)

  it('sets default values for optional config', function()
    lifemode.setup({ vault_root = '/path/to/vault' })
    local config = lifemode.get_config()

    assert.equals('/path/to/vault', config.vault_root)
    assert.equals('<Space>', config.leader)
    assert.equals(10, config.max_depth)
    assert.equals('ESV', config.bible_version)
  end)

  it('allows overriding optional config', function()
    lifemode.setup({
      vault_root = '/path/to/vault',
      leader = '<leader>m',
      max_depth = 5,
      bible_version = 'NIV'
    })
    local config = lifemode.get_config()

    assert.equals('<leader>m', config.leader)
    assert.equals(5, config.max_depth)
    assert.equals('NIV', config.bible_version)
  end)

  it('updates config when setup called multiple times', function()
    lifemode.setup({ vault_root = '/first' })
    lifemode.setup({ vault_root = '/second', leader = '<leader>x' })
    local config = lifemode.get_config()

    assert.equals('/second', config.vault_root)
    assert.equals('<leader>x', config.leader)
  end)
end)

describe(':LifeModeHello command', function()
  before_each(function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '/test/vault' })
  end)

  it('is defined after setup', function()
    -- Check command exists
    local cmd = vim.api.nvim_get_commands({})['LifeModeHello']
    assert.is_not_nil(cmd)
  end)
end)
