# lifemode.nvim

A Markdown-native productivity and wiki system for Neovim, inspired by Orgmode, LogSeq, Todoist, and wikis.

## Status

**MVP Development** - T00 (Repo skeleton + plugin bootstrap) complete.

See [TODO.md](TODO.md) for implementation roadmap and [SPEC.md](SPEC.md) for full specification.

## Installation

### lazy.nvim

```lua
{
  'billy/lifemode.nvim',
  config = function()
    require('lifemode').setup({
      vault_root = vim.fn.expand('~/notes'),
    })
  end,
}
```

### packer.nvim

```lua
use {
  'billy/lifemode.nvim',
  config = function()
    require('lifemode').setup({
      vault_root = vim.fn.expand('~/notes'),
    })
  end,
}
```

## Configuration

### Required Settings

- `vault_root`: Absolute path to your vault directory (e.g., `"/Users/billy/notes"`)

### Optional Settings

```lua
require('lifemode').setup({
  vault_root = vim.fn.expand('~/notes'),

  leader = '<Space>',
  max_depth = 10,
  max_nodes_per_action = 100,
  bible_version = 'ESV',
  default_view = 'daily',
  daily_view_expanded_depth = 3,
  tasks_default_grouping = 'due_date',
  auto_index_on_startup = false,
})
```

| Option | Default | Description |
|--------|---------|-------------|
| `leader` | `<Space>` | LifeMode leader key |
| `max_depth` | `10` | Default expansion depth limit |
| `max_nodes_per_action` | `100` | Expansion budget |
| `bible_version` | `ESV` | Default Bible version for providers |
| `default_view` | `daily` | Default view when running `:LifeMode` |
| `daily_view_expanded_depth` | `3` | How many date levels to expand (3 = expand to day level) |
| `tasks_default_grouping` | `due_date` | Default grouping for All Tasks view |
| `auto_index_on_startup` | `false` | Whether to build index on Neovim startup |

## Commands

### `:LifeModeHello`

Validate plugin loading and display current configuration.

### `:LifeMode`

Open default view (currently empty scaffold for Daily view).

## Development

### Running Tests

```bash
make test
```

### Manual Testing

```lua
require('lifemode').setup({ vault_root = '/tmp/test_vault' })
:LifeModeHello
:LifeMode
```

## License

MIT
