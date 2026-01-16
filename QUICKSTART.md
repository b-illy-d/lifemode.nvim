# LifeMode.nvim Quickstart Guide

Get started with LifeMode in 5 minutes. LifeMode is a Markdown-native productivity and wiki system for Neovim that combines task management, wikilink navigation, Bible references, and backlinks into a unified note-taking experience.

## Installation

### Using lazy.nvim

```lua
{
  'b-illy-d/lifemode.nvim',
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
git clone git@github.com:b-illy-d/lifemode.nvim.git
```

Add to your `init.lua`:

```lua
require('lifemode').setup({
  vault_root = vim.fn.expand("~/notes"),
})
```

> **⚠️ Important: Build Index Before Using Cross-File Features**
>
> LifeMode requires a vault index to use cross-file features like backlinks (`<Space>vb`), vault-wide task queries (`<Space>ta`), and references (`gr`).
>
> **After creating your notes, run this command once:**
> ```vim
> :LifeModeRebuildIndex
> ```
>
> This scans your vault and builds the index. You'll need to rebuild the index when:
> - Adding new notes with wikilinks or tasks
> - Renaming or moving files
> - Adding backlinks or references
>
> Without the index, these features will show a warning and return empty results.

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

### Adding Stable IDs to Tasks

Tasks use stable UUID v4 identifiers for tracking across your vault. Add them automatically to all tasks in the current file:

```vim
:LifeModeEnsureIDs
```

This generates UUIDs like:

```markdown
- [ ] Review sermon notes on Rom 8:28 ^a1b2c3d4-e5f6-7890-abcd-ef1234567890
- [ ] Study John 17:20-23 for Bible study ^b2c3d4e5-f6a7-8901-bcde-f12345678901
```

**Auto-ID on insert:** When you create a new task and leave insert mode, LifeMode automatically adds an ID if one is missing.

### Task Operations

Place your cursor on any task line and use these keymaps:

| Keymap | Command | Action |
|--------|---------|--------|
| `<Space><Space>` | `:LifeModeToggleTask` | Toggle task state: `[ ]` ↔ `[x]` |
| `<Space>tp` | `:LifeModeIncPriority` | Increase priority toward `!1` (highest) |
| `<Space>tP` | `:LifeModeDecPriority` | Decrease priority toward `!5` (lowest) |
| `<Space>tt` | `:LifeModeAddTag` | Add tag (prompts for input) |
| - | `:LifeModeRemoveTag` | Remove tag (prompts for input) |
| `<Space>td` | `:LifeModeSetDue` | Set due date in `YYYY-MM-DD` format |
| - | `:LifeModeClearDue` | Clear due date |
| `<Space>te` | `:LifeModeEditTaskDetails` | Open/create detail file in `tasks/` directory |

### Task Syntax Reference

LifeMode recognizes these inline markers on task lines:

```markdown
- [ ] Task text !priority #tag #tag/subtag @due(YYYY-MM-DD) ^task-id

Priority: !1 (highest) to !5 (lowest)
Tags: #single or #hierarchical/tags
Due date: @due(2026-01-20) - strict YYYY-MM-DD format (validates format only, not calendar date)
ID: ^uuid - automatically added
```

**Example task with all metadata:**

```markdown
- [x] Review sermon notes on Rom 8:28 !1 #sermon #study/bible @due(2026-01-15) ^a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

### Task Detail Files

Complex tasks can have dedicated detail files. Press `<Space>te` on a task to open/create `tasks/task-<id>.md`:

```markdown
# Task Details: a1b2c3d4-e5f6-7890-abcd-ef1234567890

## Summary
- [ ] Review sermon notes on Rom 8:28

## Details
Add detailed notes, context, and information here

## Dependencies
Link to prerequisite tasks:
depends:: [[other-task-id]]

## Notes
Additional notes and observations
```

## Core Workflow 2: Bible References

### First-Class Bible Reference Support

LifeMode natively understands Bible references anywhere in your notes. It parses 66 books plus common abbreviations and treats verses as referenceable nodes.

**Supported formats:**

```markdown
John 17:20        Single verse
John 17:20-23     Verse range
Rom 8:28          Abbreviated book names
1 Cor 13:4        Numbered books
Genesis 1:1       Full book names
Ps 23:1           Psalm/Psalms
```

**Verse ID format:** `bible:book:chapter:verse` (e.g., `bible:john:17:20`)

### Find All References to a Verse

1. Place cursor on any Bible reference: `Rom 8:28`
2. Press `gr` (find references) or `:LifeModeGotoDef`
3. LifeMode opens a quickfix list showing every note that mentions this verse

**Works vault-wide** after running `:LifeModeRebuildIndex`

### View All Bible References in Current File

```vim
:LifeModeBibleRefs
```

Shows a list of every Bible verse referenced in the current buffer, grouped by node.

### Bible Reference Integration

Bible references participate fully in LifeMode's reference system:

- **Backlinks:** Press `<Space>vb` on a verse to see all notes referencing it
- **Cross-file:** After rebuilding the index, `gr` works across all vault files
- **Navigation:** Use `gd` on a verse (currently shows message; provider integration planned)

## Core Workflow 3: Wikilinks & Navigation

### Bidirectional Linking

LifeMode supports Obsidian-style wikilinks with full navigation and backlinks.

**Wikilink formats:**

```markdown
[[Page]]                Link to page
[[Page#Heading]]        Link to heading in page
[[Page^block-id]]       Link to specific block ID
```

> **Note:** Wikilink matching is case-sensitive. `[[john]]` will not match `John.md`. Use exact filename casing.

### Creating Links

Create `~/notes/bible-study.md`:

```markdown
# Bible Study Notes

## Romans 8

See my [[daily]] notes for tasks.

Key verse: Rom 8:28 - God works all things for good.

Related concepts: [[grace]], [[sovereignty]]

Specific task: [[daily^a1b2c3d4-e5f6-7890-abcd-ef1234567890]]
```

### Navigating Links

| Action | Keymap | Result |
|--------|--------|--------|
| Go to definition | `gd` on `[[daily]]` | Opens `daily.md` |
| Go to heading | `gd` on `[[daily#Tasks]]` | Opens `daily.md` and jumps to heading |
| Go to block | `gd` on `[[page^id]]` | Opens file and jumps to block ID |
| Find references | `gr` on `[[daily]]` | Quickfix list of all links to `daily.md` |

### Link Discovery with Backlinks

Use `<Space>vb` or `:LifeModeBacklinks` to see all notes that link to:
- The current file (page-level backlinks)
- The wikilink under cursor (link-level backlinks)
- The Bible verse under cursor (verse-level backlinks)

**Example backlinks view:**

```
Backlinks to: daily.md

  notes/bible-study.md:5
    See my [[daily]] notes for tasks.

  notes/projects.md:12
    Current work: [[daily]]
```

## Core Workflow 4: PageView & Interactive Rendering

### Compiled View Rendering

PageView renders your markdown as an interactive, expandable outline:

```vim
:LifeModePageView
```

> **Note:** `:LifeModePageView` must be called from a markdown buffer (`.md` file). It creates an interactive view of the current file's content.

**Features:**
- **Clean rendering:** Node IDs hidden by default
- **Active node tracking:** Current node highlighted with subtle gray background
- **Winbar metadata:** Shows `Type: task | ID: abc123 | Lens: task/brief`
- **Lens-based rendering:** Same node displays differently based on lens
- **Expand/collapse:** Show/hide child nodes interactively
- **Manual refresh:** View is a snapshot - reopen `:LifeModePageView` to see source file changes

### View Navigation Keymaps

| Keymap | Action | Description |
|--------|--------|-------------|
| `j` / `k` | Move cursor | Active node highlights automatically |
| `<Space>e` | Expand node | Show immediate children (one level) |
| `<Space>E` | Collapse node | Hide expanded children |
| `gd` | Go to definition | Jump to wikilink/Bible verse target |
| `gr` | Find references | Show quickfix list of references |
| `<Space><Space>` | Toggle task | Mark task done/todo |
| `<Space>tp` / `<Space>tP` | Adjust priority | Increase/decrease task priority |
| `<Space>tt` | Add tag | Prompt to add tag to task |
| `<Space>td` | Set due date | Prompt to set due date |
| `<Space>ml` / `<Space>mL` | Cycle lens | Change rendering of current node |
| `q` | Close view | Close the view buffer |

### Lens System: Context-Sensitive Rendering

Lenses control how nodes are displayed without changing source content.

**Available lenses:**

| Lens | Use Case | Example Display |
|------|----------|-----------------|
| `task/brief` | Quick task scanning | `- [ ] Review notes !1 #urgent @due(2026-01-20)` |
| `task/detail` | Full task metadata | Multiline with tags list and all properties |
| `node/raw` | Raw markdown | Exact content from source file including IDs |

**Cycling lenses:**
- `<Space>ml` - Next lens (brief → detail → raw)
- `<Space>mL` - Previous lens (raw → detail → brief)
- `:LifeModeLensNext` / `:LifeModeLensPrev` - Command versions

**How lenses work:**
- Tasks default to `task/brief` (clean, scannable)
- Other nodes default to `node/raw` (exact markdown)
- Lens changes are per-node, allowing mixed rendering styles
- Source file is never modified by lens changes

### Expansion and Collapse

**Expand behavior:**
- Shows **immediate children only** (not grandchildren)
- Idempotent: repeated expand has no effect
- Respects `max_depth` config (default 10 levels)
- Cycle detection: nodes already in expansion path show "↩ already shown"
- Budget limit: respects `max_nodes_per_action` (default 100)

**Collapse behavior:**
- Removes all child nodes rendered by expand
- Extmarks automatically cleaned up
- Collapse parent collapses entire subtree

### Active Node Highlighting

As you move the cursor, LifeMode tracks which node you're on:

- **Visual highlight:** Subtle gray background (`LifeModeActiveNode` highlight group)
- **Winbar updates:** Shows current node type, ID, and active lens
- **Multi-line spans:** Entire node highlighted if it spans multiple lines
- **Window-local:** Winbar updates all windows showing the buffer

## Core Workflow 5: Backlinks & Cross-Vault Search

### What Are Backlinks?

Backlinks show you **what references what** in your vault. For any target (page, wikilink, or Bible verse), backlinks shows all source nodes that reference it.

**Access backlinks:**
- `<Space>vb` in any markdown file
- `:LifeModeBacklinks` command

### Target Detection Priority

When you invoke backlinks, LifeMode determines the target using this priority:

1. **Wikilink under cursor:** `[[daily]]` → shows backlinks to `daily.md`
2. **Bible verse under cursor:** `Rom 8:28` → shows backlinks to `bible:romans:8:28`
3. **Current filename:** No cursor target → shows page-level backlinks

### Backlinks View Format

```
# Backlinks to: daily.md

Found 3 backlink(s):

  bible-study.md:5
    See my [[daily]] notes for tasks.

  projects.md:12
    Current priorities: [[daily]]

  journal/2026-01-15.md:8
    Morning routine from [[daily]]
```

**View keymaps:**
- `gd` - Jump to referenced location
- `gr` - Find references to current line
- `q` - Close backlinks view

### Cross-Vault Index

For backlinks and references to work across all files, build the vault index:

```vim
:LifeModeRebuildIndex
```

**What the index does:**
- Scans all `.md` files in `vault_root` recursively
- Extracts node locations (file + line number)
- Builds backlinks map (target → sources)
- Enables cross-file `gr` and backlinks

**When to rebuild:**
- After creating new notes
- After adding new wikilinks or Bible references
- After moving content between files
- After file structure changes

**Index storage:** Stored in `config.vault_index` (in-memory; rebuilt on demand)

## Core Workflow 6: Task Queries & Filtering

### Query All Tasks Across Vault

LifeMode can filter and display tasks from your entire vault based on various criteria.

**Available task queries:**

| Command | Keymap | What It Shows |
|---------|--------|---------------|
| `:LifeModeTasksAll` | `<Space>vv` | All TODO tasks across vault |
| `:LifeModeTasksToday` | - | Tasks due today |
| `:LifeModeTasksOverdue` | - | Tasks past their due date |
| `:LifeModeTasksByTag <tag>` | `<Space>vt` | Tasks with specific tag (prompts) |

### Task Query Workflow

1. **Build the vault index first:**
   ```vim
   :LifeModeRebuildIndex
   ```

2. **Query tasks:**
   - Press `<Space>vv` for all tasks, OR
   - Press `<Space>vt` and enter a tag name, OR
   - Run `:LifeModeTasksToday` for today's tasks

3. **Navigate results:**
   - Quickfix list opens automatically
   - Press `Enter` on any task to jump to it
   - Press `gd` in task file to navigate wikilinks
   - Press `<Space><Space>` to toggle task state

### Task Query Format

Queries return tasks in quickfix format:

```
Tasks Tagged: #urgent

daily.md:5  - [ ] Review sermon notes !1 #urgent @due(2026-01-15)
projects.md:12  - [ ] Deploy update !2 #urgent #deploy
```

### Query Implementation Details

**Filter criteria:**
- **State:** `todo` vs `done` (checkbox state)
- **Tags:** Exact match or prefix match for hierarchical tags
- **Due date:** Today, overdue, or upcoming
- **Priority:** Extracted from `!N` inline marker

**Data source:** Vault index (requires `:LifeModeRebuildIndex` to be current)

## Core Workflow 7: Node Inclusions (Transclusion)

### Embedding Nodes from Anywhere

Node inclusions let you embed content from one note into another without duplication.

**Inclusion syntax:**

```markdown
![[node-id]]
```

### Creating Inclusions

1. **Build vault index** (so LifeMode knows where all nodes are):
   ```vim
   :LifeModeRebuildIndex
   ```

2. **Insert inclusion interactively:**
   - Press `<Space>mi` in insert or normal mode
   - Select node from picker (Telescope if available, vim.ui.select fallback)
   - Inclusion is inserted at cursor: `![[abc123-def456-...]]`

### How Inclusions Work

**At render time:**
- PageView detects `![[node-id]]` in refs
- Looks up node from buffer cache or vault index
- Renders included node inline with visual distinction
- Inclusion markers styled with `LifeModeInclusionMarker` highlight

**Inclusion types:**
- **Task inclusions:** Styled with `LifeModeInclusionTask` background
- **Heading inclusions:** Styled with `LifeModeInclusionHeading` background
- **Text inclusions:** Styled with `LifeModeInclusionText` background

**Important:** Inclusions are expanded in **views only**, not in source files.

### Example Workflow

Create `~/notes/meeting-notes.md`:

```markdown
# Weekly Standup - 2026-01-15

## Open Tasks

![[task-abc123]]
![[task-def456]]

## Discussion Points

![[idea-ghi789]]
```

When you open PageView, the included nodes render inline with their current content, providing a live aggregated view.

---

## Complete Command Reference

### Setup & Configuration

| Command | Description |
|---------|-------------|
| `:LifeModeHello` | Show current configuration |

### File Operations

| Command | Description |
|---------|-------------|
| `:LifeModeEnsureIDs` | Add UUIDs to all tasks in current file |
| `:LifeModeParse` | Parse current buffer and show block count (debug) |
| `:LifeModeShowNodes` | Show node tree structure (debug) |

### Navigation & References

| Command | Keymap | Description |
|---------|--------|-------------|
| `:LifeModeGotoDef` | `gd` | Go to wikilink/Bible verse definition |
| `:LifeModeRefs` | - | Show outbound refs and backlinks for node at cursor |
| `:LifeModeBibleRefs` | - | Show all Bible references in current file |

### Task Management

| Command | Keymap | Description |
|---------|--------|-------------|
| `:LifeModeToggleTask` | `<Space><Space>` | Toggle task state `[ ]` ↔ `[x]` |
| `:LifeModeIncPriority` | `<Space>tp` | Increase priority (toward `!1`) |
| `:LifeModeDecPriority` | `<Space>tP` | Decrease priority (toward `!5`) |
| `:LifeModeAddTag` | `<Space>tt` | Add tag (prompts for input) |
| `:LifeModeRemoveTag` | - | Remove tag (prompts for input) |
| `:LifeModeSetDue` | `<Space>td` | Set due date (prompts for `YYYY-MM-DD`) |
| `:LifeModeClearDue` | - | Clear due date from task |
| `:LifeModeEditTaskDetails` | `<Space>te` | Open/create task detail file |

### Task Queries

| Command | Keymap | Description |
|---------|--------|-------------|
| `:LifeModeTasksAll` | `<Space>vv` | Show all TODO tasks in quickfix |
| `:LifeModeTasksToday` | - | Show tasks due today |
| `:LifeModeTasksOverdue` | - | Show overdue tasks |
| `:LifeModeTasksByTag <tag>` | `<Space>vt` | Show tasks with specific tag |

### Views & Rendering

| Command | Keymap | Description |
|---------|--------|-------------|
| `:LifeModeOpen` | - | Open empty view buffer (test/debug) |
| `:LifeModePageView` | - | Render current file as interactive view |
| `:LifeModeLensNext` | `<Space>ml` | Cycle to next lens |
| `:LifeModeLensPrev` | `<Space>mL` | Cycle to previous lens |
| `:LifeModeDebugSpan` | - | Show extmark metadata at cursor (debug) |

### Multi-File & Index

| Command | Keymap | Description |
|---------|--------|-------------|
| `:LifeModeRebuildIndex` | - | Scan vault and rebuild node/backlinks index |
| `:LifeModeBacklinks` | `<Space>vb` | Show backlinks to current target |

### Inclusions

| Command | Keymap | Description |
|---------|--------|-------------|
| `:LifeModeIncludeNode` | `<Space>mi` | Insert node inclusion via picker |

---

## Complete Keymap Reference

**Note:** Leader key is configurable via `setup({ leader = '<Space>' })`. Default is `<Space>`.

### Navigation (Markdown Files & View Buffers)

| Keymap | Scope | Action |
|--------|-------|--------|
| `gd` | Both | Go to definition (wikilink/Bible verse) |
| `gr` | Both | Find references (opens quickfix) |

### Task Operations (Markdown Files & View Buffers)

| Keymap | Scope | Action |
|--------|-------|--------|
| `<Space><Space>` | Both | Toggle task state |
| `<Space>tp` | Both | Increase task priority |
| `<Space>tP` | Both | Decrease task priority |
| `<Space>tt` | Both | Add tag to task |
| `<Space>td` | Both | Set due date |
| `<Space>te` | Markdown files | Edit task details |

### Views & Display (Markdown Files & View Buffers)

| Keymap | Scope | Action |
|--------|-------|--------|
| `<Space>vb` | Markdown files | Show backlinks |
| `<Space>vt` | Markdown files | Show tasks by tag (prompts) |
| `<Space>vv` | Markdown files | Show all tasks |
| `<Space>mi` | Markdown files | Insert node inclusion |
| `<Space>ml` | View buffers | Next lens |
| `<Space>mL` | View buffers | Previous lens |

### Expansion & Collapse (View Buffers Only)

| Keymap | Scope | Action |
|--------|-------|--------|
| `<Space>e` | View buffers | Expand node (show children) |
| `<Space>E` | View buffers | Collapse node (hide children) |
| `q` | View buffers | Close view |

### Automatic Features

| Trigger | Scope | Action |
|---------|-------|--------|
| `InsertLeave` on task line | Markdown files | Auto-add UUID if missing |
| Cursor movement | View buffers | Active node highlighting updates |
| Cursor movement | View buffers | Winbar metadata updates |

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
7. Rebuild index to enable cross-file features: `:LifeModeRebuildIndex`
   - This lets you query all tasks across your vault
   - Required for `<Space>ta` (all tasks), `<Space>tt` (tasks by tag), etc.

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
3. Rebuild index: `:LifeModeRebuildIndex` (enables `gr` references and `<Space>vb` backlinks)
4. Put cursor on `John 17:20` → Press `gr`
5. See every note mentioning this verse!
6. Press `<Space>vb` to see all notes linking to this study

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

### "Query commands return no results"

This is normal when:
- Your vault has no tasks yet (create some with `- [ ] Task text`)
- The index is outdated (run `:LifeModeRebuildIndex`)
- No tasks match your query (try `:LifeModeTasksAll` to see all tasks)

Empty result lists show "No tasks found" in the quickfix window.

---

**You're ready to start!** Create your first note, add some tasks and Bible references, and explore the system. Happy note-taking! 📝✨
