# LifeMode.nvim

**A Markdown-native productivity and wiki system for Neovim.**

LifeMode combines task management, wikilinks, Bible references, and backlinks into a unified personal knowledge system. Write in plain Markdown, navigate with LSP-style keymaps, and discover connections across your vault.

## Core Features

### Task Management
- **Stable IDs:** UUID-based tracking for tasks across your vault
- **Rich metadata:** Priorities (`!1`-`!5`), tags (`#project/name`), due dates (`@due(YYYY-MM-DD)`)
- **Quick operations:** Toggle state, adjust priority, add tags, set due dates - all from keymaps
- **Task queries:** Filter vault-wide by tag, due date, or state
- **Detail files:** Complex tasks get dedicated detail files with dependencies and notes

### Wikilinks & Navigation
- **Bidirectional links:** `[[Page]]`, `[[Page#Heading]]`, `[[Page^block-id]]`
- **LSP-style navigation:** `gd` (go to definition), `gr` (find references)
- **Backlinks:** See what links to any page, wikilink target, or Bible verse
- **Cross-vault search:** Reference tracking across all files after index rebuild

### Bible References
- **Native parsing:** Recognizes all 66 books + abbreviations (e.g., `Rom 8:28`, `John 17:20-23`)
- **Verse-level tracking:** Find every note mentioning a specific verse
- **Backlinks support:** See all references to any Bible verse
- **Reference queries:** List all Bible verses in a note

### Interactive Views
- **PageView rendering:** Compile notes into expandable outlines
- **Lens system:** Same content, multiple views (brief/detail/raw)
- **Active node tracking:** Visual highlighting and metadata display
- **Expand/collapse:** Show/hide child nodes interactively

### Node Inclusions
- **Transclusion:** Embed nodes from anywhere in vault via `![[node-id]]`
- **Live aggregation:** Inclusions render current content in views
- **Visual distinction:** Different backgrounds for tasks/headings/text

## Status: Core MVP Implemented

See [SPEC.md](./SPEC.md) for complete feature specification and roadmap.

**Completed milestones:**
- T00-T19: Core infrastructure, navigation, tasks, views, backlinks
- T19a: Node inclusions (transclusion)
- T19b: Task detail files
- T20: Task query system

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'b-illy-d/lifemode.nvim',
  config = function()
    require('lifemode').setup({
      vault_root = vim.fn.expand("~/notes"),  -- REQUIRED: Your notes directory
      leader = '<Space>',                      -- Optional: LifeMode leader key (default)
      max_depth = 10,                          -- Optional: Max expansion depth (default: 10)
      max_nodes_per_action = 100,              -- Optional: Expansion budget limit (default: 100)
      bible_version = 'ESV',                   -- Optional: Bible version (default: ESV)
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
      vault_root = vim.fn.expand("~/notes"),  -- REQUIRED
    })
  end
}
```

### Manual Installation

```bash
cd ~/.local/share/nvim/site/pack/plugins/start
git clone git@github.com:b-illy-d/lifemode.nvim.git
```

Then in your `init.lua`:

```lua
require('lifemode').setup({
  vault_root = vim.fn.expand("~/notes"),
})
```

## Configuration Options

| Option | Required | Type | Default | Description |
|--------|----------|------|---------|-------------|
| `vault_root` | **Yes** | string | - | Absolute path to your Markdown vault |
| `leader` | No | string | `"<Space>"` | Key prefix for LifeMode keymaps |
| `max_depth` | No | number | `10` | Maximum node expansion depth |
| `max_nodes_per_action` | No | number | `100` | Budget limit per expand operation |
| `bible_version` | No | string | `"ESV"` | Default Bible translation |

**Validation:**
- `vault_root`: Must be non-empty string, absolute path
- `leader`: Must be non-empty string
- `max_depth`: Must be 1-100
- `max_nodes_per_action`: Must be 1-10000
- `bible_version`: Must be non-empty string

## Quick Start

1. **Verify installation:**
   ```vim
   :LifeModeHello
   ```

2. **Create your first note:**
   ```bash
   mkdir -p ~/notes
   nvim ~/notes/daily.md
   ```

3. **Add some tasks:**
   ```markdown
   # Daily Tasks
   - [ ] Review Rom 8:28 notes
   - [ ] Study John 17:20-23
   ```

4. **Add task IDs:**
   ```vim
   :LifeModeEnsureIDs
   ```

5. **Open PageView:**
   ```vim
   :LifeModePageView
   ```

6. **Explore features:**
   - Press `gd` on `Rom 8:28` to see verse navigation
   - Press `gr` on any reference to find all mentions
   - Press `<Space><Space>` on a task to toggle its state
   - Press `<Space>vb` to see backlinks

**See [QUICKSTART.md](./QUICKSTART.md) for detailed workflows and examples.**

## Essential Keymaps

| Keymap | Action |
|--------|--------|
| `gd` | Go to definition (wikilink/Bible verse) |
| `gr` | Find references (opens quickfix) |
| `<Space><Space>` | Toggle task state |
| `<Space>tp` / `<Space>tP` | Adjust priority |
| `<Space>tt` | Add tag |
| `<Space>td` | Set due date |
| `<Space>vb` | Show backlinks |
| `<Space>vv` | Show all tasks |
| `<Space>e` / `<Space>E` | Expand/collapse (in views) |

**Full keymap reference:** See [QUICKSTART.md](./QUICKSTART.md#complete-keymap-reference)

## Core Workflows

### 1. Task Management
```markdown
- [ ] Task text !priority #tag @due(YYYY-MM-DD) ^task-id
```
- Toggle with `<Space><Space>`
- Manage priority with `<Space>tp` / `<Space>tP`
- Add tags with `<Space>tt`
- Set due dates with `<Space>td`

### 2. Wikilink Navigation
```markdown
[[Page]]                Link to page
[[Page#Heading]]        Link to heading
[[Page^block-id]]       Link to specific block
```
- Navigate with `gd`
- Find references with `gr`
- See backlinks with `<Space>vb`

### 3. Bible References
```markdown
Rom 8:28                Single verse
John 17:20-23           Verse range
Genesis 1:1             Full book names
```
- Navigate with `gd` (shows message; provider planned)
- Find references with `gr`
- See all verses in file: `:LifeModeBibleRefs`

### 4. Interactive Views
- Open with `:LifeModePageView`
- Expand with `<Space>e`
- Collapse with `<Space>E`
- Cycle lenses with `<Space>ml` / `<Space>mL`

### 5. Node Inclusions
- Insert with `<Space>mi` (opens picker)
- Syntax: `![[node-id]]`
- Renders inline in views with visual distinction

## Architecture

**Key modules:**

| Module | Purpose |
|--------|---------|
| `init.lua` | Plugin setup, commands, keymaps |
| `parser.lua` | Markdown block parser |
| `node.lua` | Node tree builder with refs/backlinks |
| `tasks.lua` | Task operations (toggle, priority, tags, due dates) |
| `navigation.lua` | Wikilink navigation (`gd`) |
| `references.lua` | Reference finding (`gr`) |
| `backlinks.lua` | Backlinks view |
| `index.lua` | Vault-wide indexing |
| `query.lua` | Task filtering and queries |
| `render.lua` | PageView compilation |
| `lens.lua` | Context-sensitive rendering |
| `inclusion.lua` | Node transclusion |
| `bible.lua` | Bible reference parsing |

**Design principles:**
- Markdown-native: Source files remain plain text
- Engine-ready: Pure Lua core, prepared for external process migration
- Test-driven: TDD cycle for all features
- LSP-like: Navigation follows familiar Neovim patterns

## Documentation

- **[QUICKSTART.md](./QUICKSTART.md)** - Complete guide with workflows and examples
- **[SPEC.md](./SPEC.md)** - Full feature specification and architecture
- **Plugin help** - `:help lifemode` (planned)

## Development

**Built with TDD:** Every feature follows RED → GREEN → REFACTOR cycle.

**Test structure:**
- `tests/*_spec.lua` - Unit tests (custom test runner)
- `tests/manual_*_test.lua` - Manual acceptance tests

**Run tests:**
```bash
nvim -l tests/run_tests.lua
nvim -l tests/<feature>_spec.lua
```

## Roadmap

**Core MVP (Complete):**
- [x] T00-T19: Infrastructure, navigation, tasks, views
- [x] T19a: Node inclusions
- [x] T19b: Task detail files
- [x] T20: Task queries

**Next milestones:**
- [ ] T21-T30: Performance, transclusion rendering, Bible providers
- [ ] Polish: Help docs, performance optimization
- [ ] External engine: Rust/Zig port for speed

See [SPEC.md](./SPEC.md) for complete roadmap.

## Contributing

Contributions welcome! Please:
1. Read [SPEC.md](./SPEC.md) to understand architecture
2. Follow TDD: write failing test first
3. Ensure all tests pass: `nvim -l tests/run_tests.lua`
4. Keep code consistent with existing patterns

## License

MIT License - See [LICENSE](./LICENSE) for details.

---

**Questions?** Open an issue on GitHub.
**Want to learn more?** Read the [QUICKSTART.md](./QUICKSTART.md).
