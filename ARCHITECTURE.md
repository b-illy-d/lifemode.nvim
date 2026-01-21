# LifeMode Architecture — Beautiful Software Design

**Status:** Design specification for a deep API with immutable value objects and composable operations.

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [Domain Model — Value Objects](#2-domain-model--value-objects)
3. [The Deep API — Five Core Operations](#3-the-deep-api--five-core-operations)
4. [Layered Architecture](#4-layered-architecture)
5. [Extension Points](#5-extension-points)
6. [Directory Structure](#6-directory-structure)
7. [Composition Examples](#7-composition-examples)
8. [Why This Design is Beautiful](#8-why-this-design-is-beautiful)
9. [Implementation Guidance](#9-implementation-guidance)

---

## 1. Design Philosophy

### The Deep API Principle

This architecture embodies **deep APIs** — a small, composable interface surface with massive expressive power underneath. Think SQLite's `prepare()`, `step()`, `finalize()` cycle (3 functions, entire database), not jQuery's 300 methods.

**Core insight:** Instead of 50 specific functions, we have **5 core operations** that compose elegantly.

```
Small interface × Wide functionality = Deep API
```

### Architectural Pillars

1. **Immutable Value Objects** — Nodes and edges are immutable data structures. Transformations create new copies. No shared mutable state = no concurrency bugs.

2. **Composable Operations** — Operations return data, not side effects. Query results feed into render. Node transformations chain. Extensions plug in without core changes.

3. **Clear Boundaries** — Four layers with acyclic dependencies. Domain is pure. Infrastructure is swappable. Application orchestrates. UI is thin.

4. **Fail Fast, Fail Explicitly** — Every operation returns `Result<T, Error>`. No exceptions. Errors are data. Caller decides how to handle.

5. **Extensible Without Fragility** — Add node types, citation schemes, query operators, render strategies without touching core code.

### Visual Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer (thin)                          │
│  Commands, Keymaps, Slash Commands, Pickers                 │
└────────────────────┬────────────────────────────────────────┘
                     │ calls
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Application Layer (orchestration)              │
│  Use Cases: Capture, Narrow, Transclude, Query              │
└─────┬────────────────────────────────────────────┬──────────┘
      │ uses                                  uses │
      ▼                                            ▼
┌─────────────────────┐              ┌────────────────────────┐
│  Domain Layer       │              │  Infrastructure Layer  │
│  (pure logic)       │              │  (I/O adapters)        │
│  ─────────────      │              │  ───────────────       │
│  • Node ops         │              │  • Neovim API          │
│  • Edge ops         │              │  • Filesystem          │
│  • Citation ops     │              │  • SQLite              │
│  • Query ops        │              │  • Parsers             │
│  • Transclusion     │              │                        │
└─────────────────────┘              └────────────────────────┘

Dependencies flow downward only (acyclic).
Domain imports nothing. Infra imports domain. App imports both.
```

---

## 2. Domain Model — Value Objects

All domain objects are **immutable value objects** with validation. Creating a new version means creating a new object with the same ID.

### Node

```lua
Node = {
  id: UUID,              -- Immutable identity (UUID v4)
  content: string,       -- Markdown content (unparsed)
  meta: {                -- Metadata from frontmatter
    created: ISODate,    -- Required
    modified: ISODate,   -- Required
    type: string?,       -- Optional, inferred if missing
    [string]: any        -- Extensible user metadata
  },
  bounds: {              -- Physical location in vault
    file: Path,          -- Absolute path to source file
    lines: {start, end}  -- Line range in file
  }
}
```

**Key insight:** A Node is a **value object**. Creating a new version = new Node with same ID.

**Immutability enables:**
- Caching without invalidation complexity
- Concurrent reads without locks
- Clear change tracking (old vs new)
- Functional composition (map, filter, reduce)

### Edge

```lua
Edge = {
  from: UUID,            -- Source node
  to: UUID,              -- Target node
  kind: EdgeKind,        -- Enum: Link | Backlink | Transclusion | Citation | Child
  context: string?,      -- Surrounding text where edge originates (for backlink snippets)
  meta: {[string]: any}  -- Edge-specific metadata
}

EdgeKind = "link" | "backlink" | "transclusion" | "citation" | "child"
```

**Key insight:** Edges are **first-class**, not just "Node has links array."

**This enables:**
- Bidirectional queries (backlinks are reversed edge queries)
- Multiple edge types between same nodes
- Edge-specific metadata (e.g., transclusion depth)
- Graph algorithms without special-casing

### Citation

```lua
Citation = {
  scheme: string,        -- e.g., "bible", "bibtex"
  key: string,           -- Canonical form: "@bible:john.6.35"
  raw: string,           -- Original text: "John 6:35"
  source: Source?,       -- Resolved source object (if exists)
  location: Location     -- Where in node this citation appears
}

Source = {
  key: string,           -- Unique identifier (e.g., "smith2020")
  scheme: string,        -- Citation scheme (e.g., "bibtex")
  meta: {[string]: any}, -- Scheme-specific metadata (title, author, year, etc.)
  file: Path             -- Path to .yaml source file
}

Location = {
  node_id: UUID,         -- Which node contains this
  line: number,          -- Line number in node
  col: number            -- Column number
}
```

**Key insight:** Citations are **data**, not formatting instructions.

**This enables:**
- Multiple renderings (short, one-line, full)
- Cross-node citation queries ("all nodes citing Smith")
- Citation scheme extensions without code changes

### Query

```lua
Query = {
  filters: Filter[],     -- tag:value, type:value, -tag:value
  sort: {field, order}?, -- Optional sort specification
  limit: number?         -- Optional result limit
}

Filter = {
  field: string,         -- Field to filter on
  operator: Op,          -- eq, neq, contains, has
  value: any             -- Filter value
}

Op = "eq" | "neq" | "contains" | "has" | "gt" | "lt" | "gte" | "lte"
```

**Key insight:** Queries are **data**, not code.

**This enables:**
- Serialization (save queries as files)
- Composition (combine queries)
- Optimization (rewrite queries before execution)
- User-defined query operators via config

---

## 3. The Deep API — Five Core Operations

The magic of "deep APIs" is **composition**. Instead of 50 specific functions, we have **5 core operations** that combine infinitely.

### 3.1 `node(action, ...)`

**Signature:** `node(action: string, ...) -> Result<T, Error>`

**Actions:**
- `node("create", content, meta)` → Create new node with content and metadata
- `node("parse", text)` → Parse markdown text to node structure
- `node("get", id)` → Fetch node from index by UUID
- `node("update", id, changes)` → Update node (returns new node, immutable)
- `node("delete", id)` → Remove node from index
- `node("validate", node)` → Check node validity (returns errors or ok)
- `node("transform", node, fn)` → Apply transformation function to node content

**Why deep?**
- One function, many behaviors
- Extensible (add new actions without breaking existing code)
- Discoverable (all node ops in one place)
- Testable (action dispatch is pure logic)

**Example:**
```lua
local result = api.node("create", "# Research Notes", {
  type = "note",
  tags = {"research", "pkm"}
})

if result.ok then
  local new_node = result.value
  print("Created node:", new_node.id)
else
  print("Error:", result.error)
end
```

### 3.2 `relate(action, ...)`

**Signature:** `relate(action: string, ...) -> Result<T, Error>`

**Actions:**
- `relate("create", from, to, kind, context)` → Create edge between nodes
- `relate("query", id, direction, kind?)` → Find edges (direction: "in", "out", "both")
- `relate("backlinks", id)` → Find all edges pointing to node (sugar for query)
- `relate("path", from, to)` → Find path between nodes using graph traversal
- `relate("delete", from, to, kind)` → Remove specific edge
- `relate("neighbors", id, depth)` → Get N-hop neighborhood

**Why deep?**
- All relationship operations unified
- Direction is just a parameter, not separate functions
- Edge kind filtering is consistent
- Graph algorithms are operations, not special methods

**Example:**
```lua
-- Find all backlinks
local backlinks = api.relate("backlinks", current_node.id)

-- Find nodes within 2 hops
local neighborhood = api.relate("neighbors", current_node.id, 2)

-- Create citation edge
api.relate("create", node_id, source_id, "citation", "Mentions on line 42")
```

### 3.3 `query(dsl, context?)`

**Signature:** `query(dsl: string, context: Context?) -> Result<Node[], Error>`

**DSL Syntax:** Space-separated filters (AND), repeated operators (OR)

**Examples:**
```lua
-- Filter nodes by tag and status
query("tag:paper status:draft")

-- Date range query
query("created:2026-01-20..2026-01-25")

-- Backlinks as query
query("backlinks:" .. current_node.id)

-- Nodes citing a source
query("cites:@bible:john.6.35")

-- Complex composition
query("tag:paper cites:@smith2020 -tag:archived sort:-modified first:10")
```

**Why deep?**
- One function handles ALL queries
- DSL is composable (filters combine naturally)
- Extensible (add new operators via config)
- Serializable (save queries as strings)
- Optimizable (parse once, rewrite, execute)

**Context object:**
```lua
Context = {
  current_node: UUID?,   -- For relative queries
  config: Config,        -- User configuration
  index: Index           -- Index facade
}
```

### 3.4 `render(content, strategy, context)`

**Signature:** `render(content: any, strategy: Strategy, context: Context) -> Result<string, Error>`

**Strategies:**
- `render(node, "full", ctx)` → Full node with children expanded
- `render(node, "title", ctx)` → Just the title line
- `render(citation, "short", ctx)` → Short form: `[John 6:35]`
- `render(citation, "full", ctx)` → Full bibliographic entry
- `render(query_results, "list", ctx)` → Markdown list with links
- `render(transclusion, "inline", ctx)` → Expanded transcluded content
- `render(node, "latex_section", ctx)` → LaTeX export format

**Why deep?**
- One function for all rendering needs
- Strategy pattern = easy to add new formats
- Context provides metadata (current node, config, etc.)
- User-extensible via config
- Rendering is pure (content → string)

**Example:**
```lua
-- Render node as title only
local title = api.render(node, "title", {})

-- Render citation in multiple formats
local short = api.render(citation, "short", ctx)
local full = api.render(citation, "full", ctx)

-- Render query results as sidebar list
local list = api.render(query_results, "sidebar_list", {max = 10})
```

### 3.5 `sync(entity, direction)`

**Signature:** `sync(entity: any, direction: "read" | "write") -> Result<(), Error>`

**Operations:**
- `sync(node, "write")` → Persist node (update frontmatter + extmark + index)
- `sync(node, "read")` → Load node (read file + verify extmark + check index)
- `sync(buffer, "write")` → Persist entire buffer's nodes to disk
- `sync(vault, "read")` → Full index rebuild from filesystem

**Why deep?**
- One function handles triple redundancy (frontmatter + extmark + index)
- Direction parameter = bidirectional sync operations
- Unified consistency model across persistence layers
- Testable with mock infrastructure

**Example:**
```lua
-- Write node to all persistence layers
api.sync(modified_node, "write")

-- Read node and verify consistency
local result = api.sync(node, "read")
if result.ok then
  -- Node is consistent across all layers
else
  -- Inconsistency detected, result.error explains
end

-- Rebuild entire index
api.sync({type = "vault"}, "read")
```

---

## 4. Layered Architecture

Four layers with **acyclic dependencies**. Domain imports nothing. Infrastructure imports domain. Application imports both. UI imports application.

```
UI → Application → { Domain, Infrastructure }
                    Infrastructure → Domain
```

### Layer 1: Domain (Pure Logic)

**Responsibility:** Business rules, no I/O, no side effects, no dependencies on Neovim.

**Modules:**
```
domain/
├── types.lua           # Value object definitions (Node, Edge, Citation, Query)
├── node.lua            # Node operations (create, parse, validate, transform)
├── edge.lua            # Edge operations (create, invert, validate)
├── citation.lua        # Citation operations (parse, normalize, resolve)
├── query.lua           # Query operations (parse DSL, validate, optimize)
└── transclude.lua      # Transclusion operations (parse, expand, cycle detection)
```

**Key principles:**
- Every operation returns `Result<T, Error>`
- No dependencies on external systems (Neovim, filesystem, SQLite, config)
- **Testable in isolation** — pass in data, get data back
- Pure functions (same input → same output, no side effects)

**Example (domain/node.lua):**
```lua
local M = {}

function M.create(content, meta)
  if not content or content == "" then
    return Err("Content cannot be empty")
  end

  if not meta.created then
    return Err("Meta.created is required")
  end

  return Ok({
    id = uuid(),
    content = content,
    meta = meta,
    bounds = nil  -- Set by infrastructure layer
  })
end

function M.validate(node)
  local errors = {}
  if not node.id then table.insert(errors, "Missing id") end
  if not node.meta.created then table.insert(errors, "Missing created date") end

  if #errors > 0 then
    return Err(table.concat(errors, ", "))
  end
  return Ok(node)
end

return M
```

### Layer 2: Application (Orchestration)

**Responsibility:** Coordinate domain + infrastructure to implement use cases. Imperative workflows.

**Modules:**
```
app/
├── capture.lua         # CaptureNode use case
├── narrow.lua          # NarrowToNode, Widen, Jump use cases
├── transclude.lua      # RenderTransclusions use case
├── sidebar.lua         # RefreshSidebar use case
├── index.lua           # RebuildIndex, UpdateIndex use cases
└── query.lua           # ExecuteQuery use case
```

**Key principles:**
- Use cases are **imperative workflows**
- Glue pure domain logic with impure infrastructure
- Orchestrate multiple operations to fulfill user intent
- Handle errors and return user-facing messages

**Example (app/capture.lua):**
```lua
local M = {}

function M.capture_node()
  -- 1. Compute date path
  local date_path = infra.fs.date_path(os.date("%Y-%m-%d"))

  -- 2. Create node (domain)
  local node_result = domain.node.create("", {
    created = os.date("%Y-%m-%d"),
    type = "note"
  })

  if not node_result.ok then
    return ui.notify_error("Failed to create node: " .. node_result.error)
  end

  local node = node_result.value

  -- 3. Write to filesystem (infrastructure)
  local file_path = date_path .. "/" .. node.id .. ".md"
  local write_result = infra.fs.write(file_path, domain.node.to_markdown(node))

  if not write_result.ok then
    return ui.notify_error("Failed to write file: " .. write_result.error)
  end

  -- 4. Open in Neovim and narrow (infrastructure + app)
  infra.nvim.buf.open(file_path)
  M.narrow_to_node(node.id)

  return Ok(node)
end

return M
```

### Layer 3: Infrastructure (External Dependencies)

**Responsibility:** Talk to the outside world (I/O, APIs, systems). Swappable adapters.

**Modules:**
```
infra/
├── nvim/
│   ├── buf.lua         # Buffer operations (open, close, get_lines)
│   ├── extmark.lua     # Extmark operations (set, query, delete)
│   ├── win.lua         # Window operations (split, float, resize)
│   └── cmd.lua         # Command execution
├── fs/
│   ├── read.lua        # File reading (read, exists, mtime)
│   ├── write.lua       # File writing (write, mkdir, rm)
│   └── path.lua        # Path computation (date_path, resolve)
├── index/
│   ├── init.lua        # Index facade (query, insert, update, delete)
│   ├── sqlite.lua      # SQLite adapter (raw SQL execution)
│   ├── schema.lua      # Database schema (tables, indexes)
│   └── builder.lua     # Index builder (rebuild from vault)
└── parse/
    ├── frontmatter.lua # YAML parsing (parse, serialize)
    ├── markdown.lua    # Markdown parsing (extract structure)
    └── citation.lua    # Citation parsing (match schemes, normalize)
```

**Key principles:**
- Infrastructure is **swappable** (can replace SQLite with in-memory store for tests)
- Adapters isolate external dependencies
- Repository pattern for persistence
- Error handling with context (file paths, line numbers)

**Example (infra/index/init.lua):**
```lua
local M = {}

function M.insert_node(node)
  local sql = [[
    INSERT INTO nodes (id, file_path, created, modified, type, content_hash, metadata)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  ]]

  local params = {
    node.id,
    node.bounds.file,
    node.meta.created,
    node.meta.modified,
    node.meta.type,
    hash(node.content),
    json.encode(node.meta)
  }

  return sqlite.exec(sql, params)
end

function M.query_nodes(query)
  -- Parse query DSL (domain logic)
  local parsed = domain.query.parse(query)

  -- Build SQL from parsed query
  local sql = build_sql(parsed)

  -- Execute
  return sqlite.query(sql)
end

return M
```

### Layer 4: Interface (User-Facing)

**Responsibility:** Expose functionality as commands, keymaps, slash commands. Thin layer delegates to application.

**Modules:**
```
ui/
├── commands.lua        # Vim command definitions (:LifeModeNewNode, etc.)
├── keymaps.lua         # Keymap setup (<leader>nn, etc.)
├── slash.lua           # Slash command palette (fuzzy search, execute)
├── sidebar.lua         # Sidebar rendering (accordion, actions)
└── pickers.lua         # Telescope pickers (node search, etc.)
```

**Key principles:**
- Interface is **thin** (no business logic)
- Delegates immediately to application layer
- Handles user input and displays results
- No direct calls to domain or infrastructure

**Example (ui/commands.lua):**
```lua
local M = {}

function M.setup()
  vim.api.nvim_create_user_command("LifeModeNewNode", function()
    local result = app.capture.capture_node()
    if result.ok then
      vim.notify("[LifeMode] Node created: " .. result.value.id, vim.log.levels.INFO)
    end
  end, {})

  vim.api.nvim_create_user_command("LifeModeNarrow", function()
    app.narrow.narrow_to_current()
  end, {})

  -- ... more commands
end

return M
```

---

## 5. Extension Points

Beautiful software is **extensible without being modular hell**. Users extend behavior via configuration, not code changes.

### 5.1 Node Types

**User creates:** `.lifemode/node_types/paper.yaml`

```yaml
name: paper
description: "Academic paper reference"
matchers:
  - field: meta.type
    value: paper
  - content_contains: "# Abstract"
properties:
  - name: authors
    type: list
    required: false
  - name: year
    type: number
    required: false
render:
  title: "${meta.title} (${meta.year})"
  short: "[${meta.title}]"
  full: |
    ${meta.title}
    Authors: ${join(meta.authors, ", ")}
    Year: ${meta.year}
```

**How it works:**
1. Types loaded from `.lifemode/node_types/` on plugin init
2. Matchers run during type inference
3. Properties define schema for frontmatter validation
4. Render strategies used by `render()` function

**No core code changes required.**

### 5.2 Citation Schemes

**User creates:** `.lifemode/citation_schemes/summa.yaml`

```yaml
name: summa
description: "Summa Theologica references (ST I, Q. 1)"
patterns:
  - regex: 'ST\s+([IVX]+),\s+Q\.?\s*(\d+)'
    groups: [part, question]
  - regex: 'Summa\s+([IVX]+),\s+(\d+)'
    groups: [part, question]
normalize: |
  function(match)
    return string.format("@summa:%s.%s",
      string.lower(match.part),
      match.question)
  end
render:
  short: "ST ${part}, Q. ${question}"
  one_line: "Summa Theologica, Part ${part}, Question ${question}"
  full: |
    Aquinas, Thomas. *Summa Theologica*.
    Part ${part}, Question ${question}.
```

**How it works:**
1. Schemes loaded from `.lifemode/citation_schemes/` on init
2. Patterns matched against text during citation parsing
3. Normalize function converts to canonical form
4. Render strategies used by `render(citation, strategy)`

**User can add any citation format without touching plugin code.**

### 5.3 Query Operators

**User config:**

```lua
require('lifemode').setup({
  query_operators = {
    wordcount = function(node, op, value)
      local count = vim.fn.wordcount({node.content}).words
      return compare(count, op, tonumber(value))
    end,

    has_image = function(node, op, value)
      return node.content:match("!%[.-%]%(.*%)")
    end,

    recent = function(node, op, value)
      local days = tonumber(value)
      local cutoff = os.time() - (days * 86400)
      return parse_date(node.meta.created) > cutoff
    end
  }
})
```

**Usage:**
```lua
-- Nodes with more than 500 words
query("wordcount:>500")

-- Nodes with images created in last 7 days
query("has_image:true recent:7")
```

**No core changes, query DSL automatically supports new operators.**

### 5.4 Render Strategies

**User config:**

```lua
require('lifemode').setup({
  render_strategies = {
    bibtex = function(citation, context)
      local src = citation.source
      return string.format("@article{%s,\n  title={%s},\n  author={%s},\n  year={%s}\n}",
        citation.key,
        src.meta.title,
        table.concat(src.meta.author, " and "),
        src.meta.year)
    end,

    markdown_link = function(node, context)
      return string.format("[%s](%s)",
        node.meta.title or node.id,
        node.bounds.file)
    end
  }
})
```

**Usage:**
```lua
-- Export citation as BibTeX
local bib = render(citation, "bibtex", ctx)

-- Render node as markdown link
local link = render(node, "markdown_link", ctx)
```

**User-defined strategies available throughout the plugin.**

---

## 6. Directory Structure

Mapping architecture layers to filesystem:

```
lifemode.nvim/
├── lua/lifemode/
│   ├── init.lua                 # Plugin entry point, setup()
│   │
│   ├── domain/                  # LAYER 1: Pure business logic
│   │   ├── types.lua            # Value object definitions
│   │   ├── node.lua             # Node operations
│   │   ├── edge.lua             # Edge operations
│   │   ├── citation.lua         # Citation operations
│   │   ├── query.lua            # Query operations
│   │   └── transclude.lua       # Transclusion operations
│   │
│   ├── app/                     # LAYER 2: Use cases
│   │   ├── capture.lua          # CaptureNode use case
│   │   ├── narrow.lua           # Narrowing use cases
│   │   ├── transclude.lua       # Transclusion rendering
│   │   ├── sidebar.lua          # Sidebar updates
│   │   ├── index.lua            # Index management
│   │   └── query.lua            # Query execution
│   │
│   ├── infra/                   # LAYER 3: External dependencies
│   │   ├── nvim/                # Neovim API adapters
│   │   │   ├── buf.lua
│   │   │   ├── extmark.lua
│   │   │   ├── win.lua
│   │   │   └── cmd.lua
│   │   ├── fs/                  # Filesystem adapters
│   │   │   ├── read.lua
│   │   │   ├── write.lua
│   │   │   └── path.lua
│   │   ├── index/               # SQLite adapters
│   │   │   ├── init.lua
│   │   │   ├── sqlite.lua
│   │   │   ├── schema.lua
│   │   │   └── builder.lua
│   │   └── parse/               # Parser adapters
│   │       ├── frontmatter.lua
│   │       ├── markdown.lua
│   │       └── citation.lua
│   │
│   ├── ui/                      # LAYER 4: User interface
│   │   ├── commands.lua         # Command definitions
│   │   ├── keymaps.lua          # Keymap setup
│   │   ├── slash.lua            # Slash command palette
│   │   ├── sidebar.lua          # Sidebar rendering
│   │   └── pickers.lua          # Telescope pickers
│   │
│   ├── api.lua                  # Public Lua API (deep API surface)
│   ├── config.lua               # Configuration management
│   └── util.lua                 # Shared utilities (Result, uuid, etc.)
│
├── plugin/
│   └── lifemode.vim             # Vim plugin bootstrap
│
├── .lifemode/                   # Example vault structure
│   ├── node_types/
│   │   └── paper.yaml
│   ├── citation_schemes/
│   │   ├── bible.yaml
│   │   └── summa.yaml
│   └── sources/
│       └── smith2020.yaml
│
└── tests/
    ├── domain/                  # Unit tests (pure functions)
    ├── app/                     # Integration tests (use case workflows)
    └── fixtures/                # Test data
```

**Import Rules (enforced by tests):**
- Domain imports nothing from other layers
- Infrastructure imports domain only
- Application imports domain + infrastructure
- UI imports application only

**Test Strategy:**
- **Domain:** Pure unit tests, no mocks needed
- **Infrastructure:** Mock external systems (filesystem, SQLite)
- **Application:** Integration tests with real domain + mocked infra
- **UI:** Minimal tests, mostly manual testing

---

## 7. Composition Examples

The power of deep APIs is **composition**. Combine operations to build complex workflows without adding functions.

### Example 1: Smart Node Discovery

**Goal:** Find nodes related to current node through shared citations.

```lua
-- Get current node
local current = api.node("get", vim.b.lifemode_node_id)

-- Find all citations in current node
local current_cites = api.relate("query", current.id, "out", "citation")

-- For each citation, find other nodes citing it
local related = {}
for _, cite_edge in ipairs(current_cites) do
  local others = api.relate("query", cite_edge.to, "in", "citation")
  for _, other_edge in ipairs(others) do
    if other_edge.from ~= current.id then
      related[other_edge.from] = (related[other_edge.from] or 0) + 1
    end
  end
end

-- Sort by number of shared citations
local sorted = {}
for node_id, count in pairs(related) do
  table.insert(sorted, {id = node_id, score = count})
end
table.sort(sorted, function(a, b) return a.score > b.score end)

-- Render as sidebar list
local nodes = vim.tbl_map(function(item)
  return api.node("get", item.id).value
end, sorted)

api.render(nodes, "sidebar_list", {title = "Related by Citations"})
```

**No special "find related nodes" function needed. Composed from primitives.**

### Example 2: Export Pipeline

**Goal:** Export project as LaTeX book with bibliography.

```lua
-- Query all project nodes
local project_nodes = api.query("tag:my-project sort:created")

-- Expand all transclusions in each node
local expanded = vim.tbl_map(function(node)
  local content = node.content

  -- Find transclusions recursively
  local result = domain.transclude.expand_all(content, {
    max_depth = 10,
    visited = {}
  })

  return {
    id = node.id,
    content = result.ok and result.value or content,
    meta = node.meta
  }
end, project_nodes)

-- Render each as LaTeX section
local latex_sections = vim.tbl_map(function(node)
  return api.render(node, "latex_section", {
    level = 1,
    numbering = true
  })
end, expanded)

-- Extract all citations
local all_citations = {}
for _, node in ipairs(expanded) do
  local cites = domain.citation.extract(node.content)
  vim.list_extend(all_citations, cites)
end

-- Render bibliography
local bib = vim.tbl_map(function(cite)
  return api.render(cite, "bibtex", {})
end, all_citations)

-- Write output
local latex = table.concat(latex_sections, "\n\n")
local bibfile = table.concat(bib, "\n")

infra.fs.write("output/book.tex", latex)
infra.fs.write("output/bibliography.bib", bibfile)
```

**Custom export pipeline built from 5 core operations. No "export" function in core.**

### Example 3: Transclusion Health Check

**Goal:** Find all transclusions in vault and check for cycles/errors.

```lua
-- Query all nodes
local all_nodes = api.query("*")

-- Extract transclusions from each
local transclusions = {}
for _, node in ipairs(all_nodes) do
  local tokens = domain.transclude.parse(node.content)
  for _, token in ipairs(tokens) do
    table.insert(transclusions, {
      source = node.id,
      target = token.uuid,
      depth = token.depth
    })
  end
end

-- Check each for cycles
local errors = {}
for _, trans in ipairs(transclusions) do
  local result = domain.transclude.expand_token(
    {uuid = trans.target, depth = trans.depth},
    {[trans.source] = true},  -- visited set
    0,  -- current depth
    10  -- max depth
  )

  if not result.ok then
    table.insert(errors, {
      source = trans.source,
      target = trans.target,
      error = result.error
    })
  end
end

-- Report errors
if #errors > 0 then
  print("Found " .. #errors .. " transclusion errors:")
  for _, err in ipairs(errors) do
    local source_node = api.node("get", err.source).value
    print(string.format("  %s → %s: %s",
      source_node.meta.title or err.source,
      err.target,
      err.error))
  end
else
  print("All transclusions healthy!")
end
```

**Vault-wide analysis tool built by composing operations. No special "health check" needed.**

### Example 4: Citation Network Visualization

**Goal:** Export citation network as Graphviz DOT file.

```lua
-- Query all nodes with citations
local nodes = api.query("has:citations")

-- Build graph
local edges = {}
for _, node in ipairs(nodes) do
  local cites = api.relate("query", node.id, "out", "citation")
  for _, edge in ipairs(cites) do
    table.insert(edges, {
      from = node.id,
      to = edge.to,
      label = edge.context  -- citation context
    })
  end
end

-- Render as DOT
local dot = {"digraph citations {"}
table.insert(dot, '  node [shape=box];')

-- Nodes
local seen = {}
for _, edge in ipairs(edges) do
  if not seen[edge.from] then
    local node = api.node("get", edge.from).value
    table.insert(dot, string.format('  "%s" [label="%s"];',
      edge.from,
      node.meta.title or node.id))
    seen[edge.from] = true
  end

  if not seen[edge.to] then
    local source = api.node("get", edge.to).value
    table.insert(dot, string.format('  "%s" [label="%s"];',
      edge.to,
      source.meta.title or edge.to))
    seen[edge.to] = true
  end
end

-- Edges
for _, edge in ipairs(edges) do
  table.insert(dot, string.format('  "%s" -> "%s";',
    edge.from,
    edge.to))
end

table.insert(dot, "}")

-- Write output
infra.fs.write("output/citations.dot", table.concat(dot, "\n"))
print("Run: dot -Tpng output/citations.dot -o citations.png")
```

**Visualization export built from 5 core operations. Extensible to other formats.**

---

## 8. Why This Design is Beautiful

### 1. Small Interface, Wide Functionality

Five core operations cover the entire feature set:
- `node()` — All node operations
- `relate()` — All edge/relationship operations
- `query()` — All filtering/searching
- `render()` — All output formatting
- `sync()` — All persistence

**No explosion of specific functions.** jQuery has 300 methods. SQLite has 3 core operations. We follow SQLite.

### 2. Immutable Data Flows

Nodes and edges are value objects:
```lua
-- Wrong (mutation)
node.content = "new content"

-- Right (transformation)
local new_node = api.node("update", node.id, {content = "new content"})
```

**Benefits:**
- No shared mutable state = no concurrency bugs
- Caching is trivial (nodes never change, only new versions created)
- Time-travel debugging (keep old versions)
- Functional composition (map, filter, reduce)

### 3. Clear Boundaries

Four layers with **acyclic dependencies**:

```
Domain ← Infrastructure
   ↑         ↑
   └─── Application ← UI
```

**Domain is pure** — no I/O, testable in isolation, no dependencies.
**Infrastructure is swappable** — mock filesystem for tests, swap SQLite for in-memory store.
**Application orchestrates** — glue domain + infrastructure, handle errors.
**UI is thin** — delegate immediately, no business logic.

**No circular dependencies. No "util hell". No god objects.**

### 4. Composable Operations

Query results feed into render:
```lua
local nodes = api.query("tag:paper sort:-modified first:10")
local list = api.render(nodes, "sidebar_list", ctx)
```

Node transformations chain:
```lua
local node = api.node("get", id)
local expanded = api.node("transform", node, expand_transclusions)
local latex = api.render(expanded, "latex_section", ctx)
```

Edges combine with queries:
```lua
local backlinks = api.relate("backlinks", node.id)
local recent_backlinks = vim.tbl_filter(function(edge)
  local n = api.node("get", edge.from).value
  return is_recent(n.meta.created)
end, backlinks)
```

**Operations are Lego blocks. Combine infinitely.**

### 5. Fail Fast, Fail Explicitly

Every operation returns `Result<T, Error>`:
```lua
local result = api.node("create", content, meta)
if result.ok then
  local node = result.value
  -- success path
else
  vim.notify("[LifeMode] ERROR: " .. result.error, vim.log.levels.ERROR)
  -- error path
end
```

**No exceptions. Errors are data. Caller decides how to handle.**

Benefits:
- Explicit error handling (no hidden control flow)
- Errors carry context (file paths, line numbers, operation details)
- Type-safe (Lua LSP can check Result types)
- Composable error handling (map, flatMap, unwrapOr)

### 6. Extensible Without Fragility

Add node types without code:
```yaml
# .lifemode/node_types/recipe.yaml
name: recipe
matchers:
  - field: meta.type
    value: recipe
render:
  title: "🍳 ${meta.title}"
```

Add citation schemes without code:
```yaml
# .lifemode/citation_schemes/quran.yaml
name: quran
patterns:
  - regex: '(\d+):(\d+)'
    groups: [surah, ayah]
normalize: |
  function(match)
    return string.format("@quran:%s.%s", match.surah, match.ayah)
  end
```

Add query operators via config:
```lua
config.query_operators.wordcount = function(node, op, val)
  return compare(wordcount(node.content), op, val)
end
```

Add render strategies via config:
```lua
config.render_strategies.html = function(node, ctx)
  return markdown_to_html(node.content)
end
```

**Plugin grows without core changes. Users extend via data, not code.**

### 7. Testable in Isolation

Domain layer has **zero dependencies**:
```lua
-- Test domain/node.lua without Neovim, filesystem, or SQLite
local node = require('lifemode.domain.node')

describe("node.create", function()
  it("creates valid node with required fields", function()
    local result = node.create("# Test", {
      created = "2026-01-21",
      type = "note"
    })

    assert.is_true(result.ok)
    assert.is_not_nil(result.value.id)
    assert.equals("# Test", result.value.content)
  end)

  it("fails when content is empty", function()
    local result = node.create("", {created = "2026-01-21"})
    assert.is_false(result.ok)
    assert.matches("empty", result.error)
  end)
end)
```

**No mocks needed for domain tests. Pure functions = easy testing.**

Infrastructure tests use mocks:
```lua
-- Test app/capture.lua with mocked infrastructure
local capture = require('lifemode.app.capture')
local mock_fs = {
  write = function(path, content) return Ok() end,
  date_path = function() return "/vault/2026/01-Jan/21" end
}

describe("capture.capture_node", function()
  it("writes node to date directory", function()
    inject_dependency(capture, "fs", mock_fs)
    local result = capture.capture_node()

    assert.is_true(result.ok)
    assert.spy(mock_fs.write).was_called()
  end)
end)
```

**Application tests inject mocked infrastructure. Domain remains pure.**

### 8. Performance Through Simplicity

**Lazy evaluation:**
- Transclusions expand only when visible
- Index queries only when needed
- Extmarks created only for loaded buffers

**Caching without complexity:**
- Immutable nodes = cache forever (just check if ID exists)
- Query results cache by query string
- Rendered content caches by (content, strategy)

**Async where it matters:**
- Index queries async (don't block UI)
- File operations async (don't block editing)
- Sidebar updates debounced (no thrashing)

**Simple > clever:**
- SQLite for indexing (battle-tested, fast)
- Extmarks for buffer tracking (built-in, efficient)
- Markdown for storage (portable, readable)

---

## 9. Implementation Guidance

### First 5 Files to Build

Build in dependency order (no circular deps):

#### 1. `lua/lifemode/util.lua`

**Purpose:** Result type, UUID generation, shared helpers.

**Functions:**
- `Ok(value)` → `{ok = true, value = value}`
- `Err(error)` → `{ok = false, error = error}`
- `uuid()` → Generate UUID v4
- `parse_date(str)` → Parse ISO date to timestamp

**Why first:** Zero dependencies, needed by everything else.

#### 2. `lua/lifemode/domain/types.lua`

**Purpose:** Value object definitions and constructors.

**Types:**
- `Node` — Constructor with validation
- `Edge` — Constructor with validation
- `Citation` — Constructor with validation
- `Query` — Constructor with validation

**Why second:** Pure data definitions, needed by all domain modules.

#### 3. `lua/lifemode/domain/node.lua`

**Purpose:** Node operations (create, parse, validate, transform).

**Functions:**
- `create(content, meta)` → `Result<Node>`
- `parse(text)` → `Result<Node>` (parse markdown with frontmatter)
- `validate(node)` → `Result<Node>` (check required fields)
- `transform(node, fn)` → `Result<Node>` (apply content transformation)
- `to_markdown(node)` → `string` (serialize to markdown with frontmatter)

**Why third:** Core business logic, no external dependencies, pure functions.

#### 4. `lua/lifemode/infra/fs/write.lua` and `read.lua`

**Purpose:** Filesystem operations (read, write, mkdir).

**Functions (write.lua):**
- `write(path, content)` → `Result<()>`
- `mkdir(path)` → `Result<()>`
- `exists(path)` → `boolean`

**Functions (read.lua):**
- `read(path)` → `Result<string>`
- `mtime(path)` → `Result<number>`

**Why fourth:** Needed to persist nodes and build capture workflow.

#### 5. `lua/lifemode/app/capture.lua`

**Purpose:** First complete use case (capture new node).

**Functions:**
- `capture_node()` → `Result<Node>` (orchestrates date dir, node creation, file write)

**Workflow:**
1. Compute date path (`infra.fs.date_path`)
2. Create node (`domain.node.create`)
3. Serialize to markdown (`domain.node.to_markdown`)
4. Write to filesystem (`infra.fs.write`)
5. Open in Neovim (`infra.nvim.buf.open`)
6. Create extmark (`infra.nvim.extmark.set`)

**Why fifth:** First end-to-end feature. Demonstrates layer composition.

### Implementation Order (Milestones)

**Milestone 1: Capture + Read**
- ✅ Util (Result, UUID)
- ✅ Domain types (Node, Edge, Citation, Query)
- ✅ Domain node operations
- ✅ Infrastructure filesystem (read, write)
- ✅ Infrastructure Neovim buffers (open, close, get_lines)
- ✅ Infrastructure extmarks (set, query, delete)
- ✅ Application capture
- ✅ UI commands (`:LifeModeNewNode`)

**Result:** Users can capture new nodes to date directories and read them.

**Milestone 2: Index + Query**
- Domain query operations (parse DSL, build filters)
- Domain edge operations (create, query, validate)
- Infrastructure SQLite (schema, raw queries)
- Infrastructure index (facade, insert, query)
- Infrastructure index builder (scan vault, build index)
- Application index management (rebuild, update)
- Application query execution
- UI commands (`:LifeModeRebuildIndex`, query pickers)

**Result:** Users can query nodes by tags, dates, types.

**Milestone 3: Narrowing**
- Infrastructure Neovim windows (split, float, properties)
- Application narrowing (narrow, widen, jump)
- UI commands (`:LifeModeNarrow`, `:LifeModeWiden`, `:LifeModeJump`)
- UI keymaps (`<leader>nn`, `<leader>nw`, `<leader>nj`)

**Result:** Users can focus on single nodes (true narrowing).

**Milestone 4: Transclusion**
- Domain transclusion operations (parse, expand, cycle detection)
- Application transclusion rendering
- UI rendering (concealment, virtual text, extmarks)
- UI commands (`:LifeModeRefreshTransclusions`)

**Result:** Users can transclude nodes recursively with cycle detection.

**Milestone 5: Citations**
- Domain citation operations (parse, normalize, resolve)
- Infrastructure citation parsers (scheme loading, pattern matching)
- Infrastructure source management (YAML → .bib generation)
- Application citation rendering (short, one-line, full)
- UI citation highlighting and `gd` jump

**Result:** Users can cite sources with multiple schemes (Bible, BibTeX, custom).

**Milestone 6: Sidebar + Relations**
- Application sidebar updates (on cursor hold)
- UI sidebar rendering (accordion, actions)
- Application backlink queries
- UI commands (`:LifeModeSidebar`)

**Result:** Users see contextual info (citations, backlinks) in sidebar.

**Milestone 7: Extensions**
- Config loading (node types, citation schemes, operators, strategies)
- Domain extension registry (register custom types, schemes)
- Application extension integration (use custom renderers)

**Result:** Users extend plugin via YAML/config without code changes.

---

## Appendix: ASCII Art Diagrams

### Data Flow

```
┌─────────────┐
│  User Input │
│  (command)  │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  UI Layer                               │
│  Parse command, delegate to app         │
└──────┬──────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│  Application Layer                      │
│  Orchestrate workflow:                  │
│    1. Call domain operations            │
│    2. Call infrastructure operations    │
│    3. Handle errors                     │
│    4. Return result to UI               │
└──┬──────────────────────────┬───────────┘
   │                          │
   ▼                          ▼
┌──────────────┐      ┌───────────────┐
│  Domain      │      │  Infra        │
│  (pure)      │◄─────┤  (I/O)        │
│  • Node      │      │  • Filesystem │
│  • Edge      │      │  • SQLite     │
│  • Citation  │      │  • Neovim     │
│  • Query     │      │  • Parsers    │
└──────────────┘      └───────────────┘
       │                      │
       └──────────┬───────────┘
                  │
                  ▼
           ┌──────────────┐
           │    Result    │
           │  (data only) │
           └──────┬───────┘
                  │
                  ▼
           ┌──────────────┐
           │  UI Render   │
           │  (show user) │
           └──────────────┘
```

### Composition Example

```
query("tag:paper cites:@smith2020 sort:-modified first:10")
  │
  ├─► Parse DSL
  │    ├─ filter: tag:paper
  │    ├─ filter: cites:@smith2020
  │    ├─ sort: -modified
  │    └─ limit: 10
  │
  ├─► Build SQL
  │    SELECT * FROM nodes
  │    WHERE 'paper' IN tags
  │      AND id IN (SELECT from WHERE to = 'smith2020' AND kind = 'citation')
  │    ORDER BY modified DESC
  │    LIMIT 10
  │
  ├─► Execute Query → [Node, Node, ...]
  │
  └─► Render
       render(nodes, "sidebar_list", ctx)
         │
         ├─ For each node: render(node, "title", ctx)
         │
         └─ Format as markdown list:
              - [[Node 1 Title]]
              - [[Node 2 Title]]
              ...
```

