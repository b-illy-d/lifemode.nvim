# LifeMode.nvim

A Markdown-native productivity + wiki system for Neovim.

## Features (MVP in progress)

- Markdown-first note-taking with stable block IDs
- Wikilink navigation with LSP-like semantics
- First-class Bible reference support
- Task management with priorities and dependencies
- Backlinks and reference tracking
- Expandable views with lazy loading

See [SPEC.md](./SPEC.md) for full specification.

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'b-illy-d/lifemode.nvim',
  config = function()
    require('lifemode').setup({
      vault_root = vim.fn.expand("~/notes"), -- Required: path to your notes
      leader = '<Space>',                     -- Optional: leader key (default: <Space>)
      max_depth = 10,                         -- Optional: expansion depth (default: 10)
      bible_version = 'ESV',                  -- Optional: Bible version (default: ESV)
    })
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'b-illy-d/lifemode.nvim',
  config = function()
    require('lifemode').setup({
      vault_root = vim.fn.expand("~/notes"), -- Required
    })
  end
}
```

## Configuration

**Required:**
- `vault_root`: Absolute path to your Markdown notes directory

**Optional:**
- `leader`: Key prefix for LifeMode commands (default: `"<Space>"`)
- `max_depth`: Maximum expansion depth (default: `10`)
- `bible_version`: Default Bible translation (default: `"ESV"`)

## Quick Start

After installation, verify the plugin is working:

```vim
:LifeModeHello
```

This will display your current configuration.

## Development Status

Currently implementing Core MVP (T00-T19). See [SPEC.md](./SPEC.md) for roadmap.

- [x] T00: Repo skeleton + plugin bootstrap

## License

MIT
