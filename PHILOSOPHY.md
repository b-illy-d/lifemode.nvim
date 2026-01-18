# LifeMode Philosophy

This document defines the core mental model for LifeMode. Code and specs derive from these concepts.

## The Vault

The vault is a **portable database** that happens to be human-readable markdown.

Key principles:
- Users NEVER directly edit vault files - all interaction is through LifeMode views
- Folder structure (`tasks/`, `notes/`, `quotes/`) is an optimization for the app, not a user mental model
- Any tool can read the markdown; LifeMode isn't required to access your data
- The vault is the source of truth; all views and indexes are derived and disposable

## Nodes

**1 file = 1 node.** Each markdown file in the vault is exactly one node.

### Node Properties

Every node has:
- `type::` - The node type (note, task, quote, source, citation, project)
- `id::` - Unique identifier (UUID)
- `created::` - Creation date (YYYY-MM-DD)
- Content - The markdown body below the properties

### Node Types

| Type | Purpose | Storage Path |
|------|---------|--------------|
| `note` | General notes, thoughts, ideas | `notes/note-{uuid}.md` |
| `task` | Actionable items with state | `tasks/task-{uuid}.md` |
| `quote` | Quotations from sources | `quotes/quote-{slug}.md` |
| `source` | Books, articles, blogs (entities) | `sources/source-{slug}.md` |
| `citation` | Specific references to sources | `citations/citation-{uuid}.md` |
| `project` | Ordered collection of node references | `projects/project-{slug}.md` |

### Default Type

When type is omitted, a node defaults to `note`. Users can retype nodes later by changing the `type::` property.

### Node Lifecycle

- Nodes are created via LifeMode commands (`:LifeModeNew`, `:LifeModeNewTask`)
- Each node is independent - no nesting within files
- Timestamps (created, modified) tracked via file properties or mtime

## Views

A view is one or more nodes presented in relation to one another.

### View Definition

Every view is defined by three components:
1. **Query** - Which nodes to include (filter by type, tags, dates, etc.)
2. **Grouping** - How to organize results (by date, priority, tag, project)
3. **Lens** - How to render each node (brief, detail, full)

### View Examples

| View | Query | Grouping | Use Case |
|------|-------|----------|----------|
| Daily | all nodes | by created date (Year > Month > Day) | Browse chronologically |
| Tasks | type == task | by due date or priority | Task management |
| Project | nodes in project X | by project order | Focused work |
| Backlinks | nodes referencing X | by type | Discover connections |

### Views are Computed

Views are NOT stored - they're dynamically generated queries. The same node can appear in multiple views with different lenses.

## Projects

A project is a node that **references** other nodes in a specific order.

### Project Structure

```markdown
type:: project
id:: xyz789
title:: Easter Sermon 2026

[[note-abc123]]
[[quote-dorothy-day]]
[[task-def456]]
[[note-ghi789]]
```

### Project Principles

- **References only** - No inline content; all content lives in its own node file
- **Ordered** - The reference list defines the presentation order
- **Shared nodes** - A node can be referenced by multiple projects
- **Nestable** - Projects can reference other projects (Sermon > Chapters > Sections)

### Project Use Cases

- Sermons as ordered collections of notes, quotes, and tasks
- Research papers referencing source materials
- Weekly reviews aggregating relevant tasks and notes
- A "tweet" could be a tiny project of two combined note nodes

## Lenses

A lens transforms a single node's data into a presentation format.

### Lens Properties

- Lenses presuppose a node type (TaskNode lenses differ from QuoteNode lenses)
- Multiple lenses exist per type: `brief`, `detail`, `full`, `raw`, custom
- Lens selection is per-node and can vary within a view
- Pure presentation - changing lens never modifies the node data

### Standard Lenses

| Type | Lens | Output |
|------|------|--------|
| task | `brief` | `[ ] Text !priority @due(...)` |
| task | `detail` | Multi-line with context |
| note | `brief` | Title + first line |
| note | `full` | Complete content |
| quote | `brief` | Quote text (truncated) |
| quote | `full` | Quote + attribution |
| project | `brief` | Title + node count |
| project | `expanded` | Title + rendered nodes |

### Lens Cycling

Users can cycle through available lenses for any node in a view using `<Space>l` / `<Space>L`.

## File Format Examples

### NoteNode (`notes/note-abc123.md`)

```markdown
type:: note
id:: abc123
created:: 2026-01-18

# My Thought

Some content with **formatting** and [[wikilinks]].
Maybe a Bible reference like John 3:16.
```

### TaskNode (`tasks/task-def456.md`)

```markdown
type:: task
id:: def456
created:: 2026-01-15

- [ ] Write the sermon intro !2 @due(2026-01-20) #work

## Context

This task came from my meeting with John.
See [[note-abc123]] for background.
```

### QuoteNode (`quotes/quote-dorothy-day-01.md`)

```markdown
type:: quote
id:: dorothy-day-01
created:: 2026-01-05
author:: Dorothy Day

"The greatest challenge of the day is: how to bring about a revolution of the heart."
```

### SourceNode (`sources/source-smith2019.md`)

```markdown
type:: source
id:: smith2019
title:: Theological Arguments in Romans
author:: John Smith
year:: 2019
kind:: book
```

### ProjectNode (`projects/project-easter-sermon.md`)

```markdown
type:: project
id:: easter-sermon
created:: 2026-01-10
title:: Easter Sermon 2026

[[note-intro-thoughts]]
[[quote-dorothy-day-01]]
[[note-main-argument]]
[[task-def456]]
[[note-conclusion]]
```

## What Changed from Previous Model

| Before | After |
|--------|-------|
| 1 file = many nodes (parser extracts blocks) | 1 file = 1 node |
| Headings/list items are node types | Headings/lists are markdown within a node |
| Implicit types from parsing | Explicit `type::` property |
| No project concept | Projects as meta-nodes with references |
| Hardcoded views | Views as query + grouping + lens |

## Implementation Notes

### Vault Organization

```
vault/
├── notes/
│   └── note-{uuid}.md
├── tasks/
│   └── task-{uuid}.md
├── quotes/
│   └── quote-{slug}.md
├── sources/
│   └── source-{slug}.md
├── citations/
│   └── citation-{uuid}.md
└── projects/
    └── project-{slug}.md
```

### ID Generation

- Most nodes use UUID v4 for `id::`
- Sources, quotes, and projects can use slugs for readability
- File naming: `{type}-{id}.md`

### Property Parsing

Properties use LogSeq-style `key:: value` format:
- First contiguous block of `key::` lines = node properties
- Everything after = node content/body
