# LifeMode.nvim Quickstart Guide

Get started with LifeMode in 5 minutes. This guide walks you through the core workflows for managing your life with Markdown, Bible references, and tasks.

## Installation

### Using lazy.nvim

```lua
{
  'billy/lifemode.nvim',
  config = function()
    require('lifemode').setup({
      vault_root = vim.fn.expand("~/notes"),  -- REQUIRED: Your notes directory
      leader = '<Space>',                      -- Optional: LifeMode leader key (default)
      max_depth = 10,                          -- Optional: Max expansion depth (default)
      bible_version = 'ESV',                   -- Optional: Bible version (default)
    })
  end,
}
```

### Manual Installation

```bash
cd ~/.local/share/nvim/site/pack/plugins/start
git clone https://github.com/billy/lifemode.nvim.git
```

Add to your `init.lua`:

```lua
require('lifemode').setup({
  vault_root = vim.fn.expand("~/notes"),
})
```

## Quick Start: Your First Note

### 1. Create a Note Directory

```bash
mkdir -p ~/notes
cd ~/notes
```

### 2. Create Your First Note

Create `~/notes/daily.md`:

```markdown
# Daily Tasks

- [ ] Review sermon notes on Rom 8:28
- [ ] Study John 17:20-23 for Bible study
- [ ] Write blog post about grace

## Project Ideas

- Build a scripture memory system
- Create a topical Bible index
```

### 3. Open in Neovim

```bash
nvim ~/notes/daily.md
```

## Core Workflow 1: Task Management

### Adding IDs to Tasks

Tasks need stable IDs for tracking. Add them automatically:

```vim
:LifeModeEnsureIDs
```

Your tasks now look like:

```markdown
- [ ] Review sermon notes on Rom 8:28 ^a1b2c3d4-e5f6-7890-abcd-ef1234567890
- [ ] Study John 17:20-23 for Bible study ^b2c3d4e5-f6a7-8901-bcde-f12345678901
```

### Managing Tasks

Put cursor on a task and use these keymaps:

- `<Space><Space>` - Toggle task state: `[ ]` ↔ `[x]`
- `<Space>tp` - Increase priority (add `!1` for highest)
- `<Space>tP` - Decrease priority
- `<Space>tt` - Add tags (e.g., `#urgent`, `#project/lifemode`)
- `<Space>td` - Set due date (e.g., `@due(2026-01-20)`)

Example after editing:

```markdown
- [x] Review sermon notes on Rom 8:28 !1 #sermon @due(2026-01-15) ^a1b2c3d4-...
- [ ] Study John 17:20-23 for Bible study !2 #bible-study @due(2026-01-18) ^b2c3d4e5-...
```

## Core Workflow 2: Bible References

### Navigate to Bible Verses

LifeMode understands Bible references out of the box. Put your cursor on any reference:

```markdown
Rom 8:28
John 17:20-23
Genesis 1:1
```

Press `gd` (go to definition) to see the verse. Press `gr` (find references) to see all places you've mentioned this verse.

### Find All References to a Verse

Put cursor on `Rom 8:28` and press `gr`. LifeMode shows a quickfix list of every note mentioning this verse.

### See All Bible References in Current File

```vim
:LifeModeBibleRefs
```

## Core Workflow 3: Wikilinks & Navigation

### Create Links Between Notes

Create `~/notes/bible-study.md`:

```markdown
# Bible Study Notes

## Romans 8

See my [[daily]] notes for tasks.

Key verse: Rom 8:28 - God works all things for good.

Related: [[grace]], [[sovereignty]]
```

### Navigate Links

- Put cursor on `[[daily]]` and press `gd` - jumps to daily.md
- Press `gr` on `[[daily]]` - shows all notes linking to daily.md

### Link to Headings or Blocks

```markdown
See [[daily#Project Ideas]] for related projects.
See [[daily^a1b2c3d4-e5f6-7890-abcd-ef1234567890]] for the specific task.
```

## Core Workflow 4: View Mode

### Open a Compiled View

View mode shows your notes as an interactive outline:

```vim
:LifeModePageView
```

This creates a compiled view with:
- Clean rendering (IDs hidden)
- Task priorities visible
- Active node highlighting (gray background)
- Metadata in winbar (Type | ID | Lens)

### Navigate the View

In view mode:

- `j/k` - Move cursor (active node highlights automatically)
- `<Space>e` - Expand node to show children
- `<Space>E` - Collapse expanded node
- `gd` - Jump to link target
- `gr` - Find references to current item
- `<Space><Space>` - Toggle task state
- `<Space>tp/tP` - Adjust priority
- `<Space>tt` - Add/remove tags
- `<Space>td` - Set due date
- `q` - Close view

### Understanding Lenses

Lenses control how nodes are displayed. Cycle through them:

- `<Space>ml` - Next lens (brief → detail → raw)
- `<Space>mL` - Previous lens

Lens types:
- **task/brief**: Clean task view (IDs hidden, priorities shown)
- **task/detail**: Full metadata (all properties visible)
- **node/raw**: Raw markdown (exactly as in source file)

## Core Workflow 5: Backlinks

### See What Links Here

Want to see all notes that reference your current note?

```vim
:LifeModeBacklinks
```

Or press `<Space>vb` (view backlinks).

This shows:
- Every note that links to current page
- Context around each reference
- Click `gd` on any entry to jump there

### Example Backlinks View

```
Backlinks to: daily

From notes/bible-study.md:3
  See my [[daily]] notes for tasks.

From notes/projects.md:12
  Check [[daily]] for today's priorities.
```

## Core Workflow 6: Multi-File Navigation

### Build the Vault Index

For cross-file references to work, build the index:

```vim
:LifeModeRebuildIndex
```

This scans all `.md` files in your vault and builds:
- Node locations (which file/line each ID is on)
- Backlinks map (what references what)

Now `gr` and backlinks work across your entire vault!

### When to Rebuild

Rebuild after:
- Creating new notes
- Adding new wikilinks
- Moving content between files

## Quick Reference: All Commands

### File Operations
- `:LifeModeEnsureIDs` - Add UUIDs to tasks
- `:LifeModeParse` - Parse current buffer (debug)
- `:LifeModeShowNodes` - Show node tree (debug)

### Navigation
- `:LifeModeRefs` - Show refs for node under cursor
- `:LifeModeBibleRefs` - Show all Bible refs in file
- `:LifeModeGotoDef` - Go to definition (same as `gd`)

### Task Management
- `:LifeModeToggleTask` - Toggle task state
- `:LifeModeIncPriority` - Increase priority
- `:LifeModeDecPriority` - Decrease priority
- `:LifeModeAddTag` - Add tag
- `:LifeModeRemoveTag` - Remove tag
- `:LifeModeSetDue` - Set due date
- `:LifeModeClearDue` - Clear due date

### Views
- `:LifeModeOpen` - Open empty view buffer
- `:LifeModePageView` - Render current file as view
- `:LifeModeLensNext` - Cycle to next lens
- `:LifeModeLensPrev` - Cycle to previous lens
- `:LifeModeDebugSpan` - Debug extmark metadata

### Multi-File
- `:LifeModeRebuildIndex` - Scan vault and rebuild index
- `:LifeModeBacklinks` - Show backlinks to current target

## Quick Reference: Keymaps

All keymaps use `<Space>` as the LifeMode leader (configurable).

### In Markdown Files (Vault)

**Navigation:**
- `gd` - Go to definition (wikilink or Bible verse)
- `gr` - Find references (show in quickfix)

**Tasks:**
- `<Space><Space>` - Toggle task state
- `<Space>tp` - Increase priority
- `<Space>tP` - Decrease priority
- `<Space>tt` - Add tag
- `<Space>td` - Set due date

**Views:**
- `<Space>vb` - Show backlinks

### In View Buffers

**Navigation:**
- `gd` - Go to definition
- `gr` - Find references

**Tasks:**
- `<Space><Space>` - Toggle task state
- `<Space>tp` - Increase priority
- `<Space>tP` - Decrease priority
- `<Space>tt` - Add tag
- `<Space>td` - Set due date

**View Control:**
- `<Space>e` - Expand node (show children)
- `<Space>E` - Collapse node (hide children)
- `<Space>ml` - Next lens
- `<Space>mL` - Previous lens
- `q` - Close view

## Example: Daily Workflow

### Morning: Plan Your Day

1. Open your daily note: `nvim ~/notes/daily.md`
2. Add tasks for today:
   ```markdown
   - [ ] Study John 17:20-23 for small group
   - [ ] Review notes on Rom 8:28
   - [ ] Write blog post on grace
   ```
3. Add IDs: `:LifeModeEnsureIDs`
4. Set priorities:
   - Cursor on first task → `<Space>tp` → `!1` (highest)
   - Second task → `<Space>tp` twice → `!2`
5. Add due dates:
   - First task → `<Space>td` → Enter `2026-01-15`
6. Add tags:
   - First task → `<Space>tt` → Enter `bible-study`

Your tasks now look like:
```markdown
- [ ] Study John 17:20-23 for small group !1 #bible-study @due(2026-01-15) ^abc...
- [ ] Review notes on Rom 8:28 !2 @due(2026-01-15) ^def...
- [ ] Write blog post on grace !3 #writing ^ghi...
```

### During Day: Use View Mode

1. Open view: `:LifeModePageView`
2. Navigate with `j/k` - active task highlights
3. Toggle tasks as complete: `<Space><Space>`
4. Expand project sections: `<Space>e`
5. Jump to references: `gd` on any link

### Study: Bible References

1. Create study note: `~/notes/john-17.md`
2. Add references naturally:
   ```markdown
   # John 17 - High Priestly Prayer

   Key verse: John 17:20 - Jesus prays for future believers

   Context: John 17:18-23 shows the complete prayer

   Compare with: Rom 8:28 (God's sovereign plan)
   ```
3. Put cursor on `John 17:20` → Press `gr`
4. See every note mentioning this verse!
5. Press `<Space>vb` to see all notes linking to this study

### Evening: Review Backlinks

1. Open any note
2. Press `<Space>vb` (view backlinks)
3. See what connected to today's work
4. Discover unexpected connections
5. Press `gd` on backlinks to explore

## Tips & Tricks

### 1. Use Hierarchical Tags

Organize with slash-separated tags:

```markdown
- [ ] Fix auth bug #project/lifemode #bug #urgent
- [ ] Write docs #project/lifemode #documentation
```

### 2. Link to Specific Tasks

Use block IDs to link to exact tasks:

```markdown
Blocked by: [[daily^abc123...]]
```

### 3. Bible Study Pattern

Create topical indexes:

```markdown
# Topic: Faith

Key verses:
- Heb 11:1 - Definition of faith
- Rom 10:17 - Faith comes by hearing
- Jas 2:17 - Faith without works is dead

See also: [[grace]], [[justification]]
```

### 4. Daily Note Pattern

Keep a daily note with:
- Today's tasks (with priorities and due dates)
- Bible reading notes (with references)
- Links to active projects
- Quick journal entries

### 5. Project Note Pattern

For each project:
- Overview heading with wikilinks to related notes
- Task list with priorities
- Bible verses for motivation/guidance
- Links to resources and references

## What's Next?

You now know the core LifeMode workflows! Here's what to explore:

1. **Experiment with views** - Try different lenses, expand/collapse
2. **Build your vault** - Add more notes, link them together
3. **Track Bible references** - See where verses appear across your notes
4. **Use backlinks** - Discover connections you didn't know existed
5. **Develop your system** - Find workflows that work for you

## Getting Help

- Check `:help lifemode` (coming soon)
- Read `SPEC.md` for architecture details
- Report issues on GitHub

## Common Issues

### "vault_root is required"

Add to your config:
```lua
require('lifemode').setup({
  vault_root = vim.fn.expand("~/notes"),  -- Must be absolute path
})
```

### "References don't work across files"

Build the index:
```vim
:LifeModeRebuildIndex
```

### "Bible references not recognized"

Supported formats:
- `John 17:20` (single verse)
- `John 17:18-23` (range)
- `Rom 8:28` (abbreviated books)
- All 66 Bible books + common abbreviations

### "Tasks don't have IDs"

Run once per file:
```vim
:LifeModeEnsureIDs
```

IDs are added automatically to the end of each task line.

---

**You're ready to start!** Create your first note, add some tasks and Bible references, and explore the system. Happy note-taking! 📝✨
