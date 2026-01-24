# LifeMode Tutorial: Actually Working Features

This tutorial shows you what **actually works** in LifeMode right now. No bullshit about features that don't exist yet.

---

## Prerequisites

1. **Install LifeMode** (Neovim plugin)
2. **Configure vault path** in your Neovim config:

```lua
require('lifemode').setup({
  vault_path = "~/test_vault",
  sidebar = { width_percent = 30 },
  keymaps = {
    new_node = "<leader>nc",
    narrow = "<leader>nn",
    widen = "<leader>nw",
    jump_context = "<leader>nj",
    toggle_sidebar = "<leader>ns",
  }
})
```

3. **Create test vault directory**:

```bash
mkdir -p ~/test_vault
```

---

## Part 1: Creating Nodes

### Create a New Node

From anywhere in Neovim:

Run: `:LifeModeNewNode` or press `<leader>nc`

**What happens:**
- Creates a new markdown file with:
  - Generated UUID as filename
  - YAML frontmatter with id, created, modified timestamps
  - Today's date path: `~/test_vault/YYYY/MM-MMM/DD/`
- Opens the file in a buffer
- Cursor positioned after frontmatter

**Try it:**
Type some content:

```markdown
# My First Thought

This is a test node. I can write whatever I want here.
```

Save: `:w`

**What happens on save:**
- Index updates automatically (incremental)
- Node is now searchable (once search commands exist)

---

## Part 2: Narrowing Workflow

Narrowing lets you focus on a single node without distraction.

### Step 2.1: Narrow to a Node

With any `.md` file open:

Run: `:LifeModeNarrow` or press `<leader>nn`

**Expected:**
- New scratch buffer opens
- Contains only the current node's content
- Statusline shows `[NARROW: ...]`
- You can edit freely

**Try:**
- Add some text
- Modify existing content

---

### Step 2.2: Widen to Save Changes

While in the narrow buffer:

Run: `:LifeModeWiden` or press `<leader>nw`

**Expected:**
- Changes written back to source file
- Narrow buffer closes
- Back in source file at the node's location

**Verify:**
Check the source file - your changes should be there.

---

### Step 2.3: Jump Between Narrow and Context

Open a node and narrow to it: `<leader>nn`

Press: `<leader>nj` (jump context)

**Expected:**
- Switches to source file
- Cursor at node location

Press `<leader>nj` again:

**Expected:**
- Switches back to narrow buffer

Use this to quickly see surrounding nodes and return to focused editing.

---

## Part 3: Sidebar

### View Node Context

With a node open:

Run: `:LifeModeSidebar` or press `<leader>ns`

**Expected:**
A floating window on the right showing:
- Node metadata (type, tags, timestamps)
- Outgoing links
- Backlinks
- Citations

**Try:**
- Navigate with `j`/`k`
- Press `<CR>` on a link to jump to it
- Toggle sidebar with `<leader>ns`

---

## Part 4: Transclusions

Transclusions let you embed one node's content into another.

### Basic Transclusion

1. **Create two nodes:**

First node:
```markdown
---
id: node-a-uuid
created: 2026-01-24T12:00:00Z
modified: 2026-01-24T12:00:00Z
---

# Definition: Epistemology

Epistemology is the study of knowledge and justified belief.
```

Second node:
```markdown
---
id: node-b-uuid
created: 2026-01-24T12:00:00Z
modified: 2026-01-24T12:00:00Z
---

# My Essay

{{node-a-uuid}}

This is my essay about knowledge.
```

2. **Render transclusions:**

Run: `:LifeModeRefreshTransclusions`

**Expected:**
- The `{{node-a-uuid}}` token is replaced with node-a's content
- Visual indicators show the transcluded region
- Edit the source node to update all transclusions

---

## Part 5: Citations

### Jump to Citation Source

1. **Create a source file:**

Create: `~/test_vault/.lifemode/sources/hume1748.yaml`

```yaml
---
key: hume1748
type: book
author: David Hume
title: "An Enquiry Concerning Human Understanding"
year: 1748
publisher: A. Millar
location: London
---
```

2. **Cite it in a node:**

```markdown
---
id: my-node-uuid
created: 2026-01-24T12:00:00Z
modified: 2026-01-24T12:00:00Z
---

# Thoughts on Induction

@hume1748 argues that induction cannot be rationally justified.
```

3. **Jump to source:**

Place cursor on `@hume1748` and press `gd` (or run `:LifeModeEditSource`)

**Expected:**
- Opens `.lifemode/sources/hume1748.yaml`
- Shows full bibliographic info

---

## Part 6: Automatic Indexing

LifeMode automatically indexes your vault as you work.

**How it works:**
- On `BufWritePost` for `*.md` files
- Parses the buffer
- Updates SQLite index with:
  - Node metadata
  - Wikilinks
  - Citations
  - Transclusions
- Runs asynchronously (no blocking)

**Test it:**
1. Create a node with a wikilink
2. Save: `:w`
3. Open sidebar: `<leader>ns`
4. The link appears in "Outgoing Links"

No manual index rebuild needed!

---

## Current Limitations

**Not yet implemented:**
- `:LifeModeRebuildIndex` - full vault scanning
- `:LifeModeFindNode` - fuzzy finding nodes
- `:LifeModeSearch` - full-text search
- `:LifeModeQueryCitations` - find all nodes citing a source
- `:LifeModeExportBib` - export to BibTeX
- `:LifeModeQueryNodes` - complex queries

**Coming in future phases** - see ROADMAP.md for planned features.

---

## Appendix: Available Commands

| Command | Keymap | Description |
|---------|--------|-------------|
| `:LifeModeNewNode` | `<leader>nc` | Create new node |
| `:LifeModeNarrow` | `<leader>nn` | Narrow to current node |
| `:LifeModeWiden` | `<leader>nw` | Widen and save changes |
| `:LifeModeJumpContext` | `<leader>nj` | Toggle between narrow and source |
| `:LifeModeSidebar` | `<leader>ns` | Toggle sidebar |
| `:LifeModeRefreshTransclusions` | - | Re-render transclusions |
| `:LifeModeEditSource` | `gd` on citation | Jump to source file |

---

## Appendix: Node Frontmatter

```yaml
---
id: <uuid-v4>
created: <iso8601-timestamp>
modified: <iso8601-timestamp>
type: <string>           # optional
status: <string>         # optional
tags:                    # optional
  - tag1
  - tag2
---
```

---

## Questions or Issues?

Check `:messages` for errors. File bugs on GitHub if shit breaks.

**Now go build your knowledge graph, you beautiful bastard.**
