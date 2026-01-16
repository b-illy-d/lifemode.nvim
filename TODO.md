## Known Issues & High Priority Features

### Critical Bugs
1. **LifeMode Leader key broken in LifeModePageView** (BLOCKING)
   - Symptom: Changing lenses doesn't work; LifeMode Leader key mappings are not responding in PageView buffers
   - Affects: T11 (lens cycling), T13 (page view)
   - Priority: P0 - blocks core workflow
   - Status: Needs investigation and fix

### High Priority Features (Add Before T20)
2. **Node inclusion/transclusion with search modal** (TOP PRIORITY)
   - User should be able to create an "inclusion" of any node while in Page View
   - Approach: **Markdown-level syntax** (stored in files, aligns with P1: Markdown-first)
   - Syntax: `![[node-id]]` (Obsidian-style)
   - Workflow:
     - Trigger command in Page View (e.g., `<Space>mi` for "LifeMode include")
     - Modal appears with fuzzy search across all nodes (tasks, headings, blocks)
     - User selects node to include
     - Insert `![[node-id]]` at cursor position
   - Parsing: Recognized as special reference type (inclusion vs regular wikilink)
   - Rendering: Target node content is expanded inline with visual distinction (border/highlight)
   - Requires: Cycle detection (node includes itself transitively)
   - Acceptance: Can insert and render inclusions; included content renders inline with proper formatting
   - Add as: **T19a — Node inclusion/transclusion with Telescope picker**

3. **Automatic task creation with enhanced detail lens** (TOP PRIORITY)
   - **Removed**: Task detail files concept (violates P1: Markdown-first)
   - **Keep**: Auto-UUID insertion when user creates task
   - Behavior: When user types `- [ ] ` and completes line:
     - Automatically append `^<uuid>` if missing
     - Hook on `InsertLeave` or `TextChanged` for task lines
   - Task details: Use indented property lines and notes as children (already in SPEC C3):
     ```md
     - [ ] Task summary !2 @due(2026-02-01) #tag ^uuid
       depends:: [[Task/Parser]]
       notes about the task...
     ```
   - Lens system handles display:
     - `task/brief`: Shows summary line only
     - `task/detail`: Shows full metadata + children
   - Add syntax highlighting for node types in rendered views:
     - Different highlight groups for task nodes, source nodes, verse nodes
     - Visual distinction (border, background, icon) by node type
   - Acceptance: Typing `- [ ] My task` auto-adds UUID; lens cycling shows brief vs detail; syntax highlighting distinguishes node types
   - Add as: **T19b — Auto-task creation with enhanced detail lens + node type highlighting**

**Implementation notes for T19a/T19b:**
- Architectural changes affecting the node model and rendering
- Inclusion rendering: Need recursive expansion with cycle detection
- Enhanced lenses: `task/detail` must properly show/hide children
- Syntax highlighting: Extmark-based decorations by node type


## Iteration (commit-sized tasks)

Each task below should fit in ~10–1000 LOC and land as a single git commit.

**Implementation Notes:**
- Focus on the **Core MVP Loop** first (T00-T19 prioritized)
- Write tests for parsing/indexing logic; pause for manual testing at milestones
- Bible reference parsing and navigation should be treated as **core features**, not nice-to-haves
- User will signal when to pause for extensive user testing
- Keep engine boundary in mind but don't over-architect initially
- Prefer plenary.nvim and telescope.nvim for utilities and pickers

### T00 — Repo skeleton + plugin bootstrap
- Create `lua/lifemode/init.lua`, minimal `setup()` with config defaults.
- Required config: `vault_root` (must be provided by user)
- Optional config: `leader`, `max_depth`, `bible_version`, `default_view`, etc.
- Add a `:LifeModeHello` command to validate loading and show config.
- Add a `:LifeMode` command that opens an empty view (scaffold for default Daily view).
- Acceptance: `:LifeModeHello` echoes config, `:LifeMode` opens empty view buffer, plugin loads without errors.

### T01 — View buffer creation utility
- Implement `lifemode.view.create_buffer()`:
  - `buftype=nofile`, `swapfile=false`, `bufhidden=wipe`
- Add `:LifeModeOpen` to open an empty view buffer.
- Acceptance: buffer opens and is clearly marked as LifeMode view.

### T02 — Extmark-based span mapping
- Add an extmark namespace and helpers to attach metadata per rendered block:
  - `instance_id`, `node_id`, `lens`, `span_start/end` (initially computed)
- Acceptance: debug command prints metadata for instance under cursor.

### T03 — Minimal Markdown block parser (Lua MVP)
- Parse a Markdown file into a list of blocks (headings + list items).
- Extract:
  - task checkbox state
  - `^id` suffix if present
- Acceptance: command parses current buffer and prints block count + tasks count.

### T04 — Ensure IDs for indexable blocks
- Implement `ensure_id(block)`:
  - if no `^id`, generate UUID v4 and insert on line end
  - Format: `^550e8400-e29b-41d4-a716-446655440000`
- Only apply for task blocks initially.
- Use `vim.fn.system('uuidgen')` or pure Lua UUID generation
- Acceptance: running command adds UUIDs to tasks in file and preserves content.

### T05 — Build in-memory Node model for a single file
- Convert parsed blocks into Node records:
  - `id`, `type` (task vs text), `body_md`, `children` (basic via indentation or heading nesting)
- Acceptance: command prints node tree summary.

### T06 — Basic wikilink extraction
- Extract `[[...]]` links from node body.
- Create outbound refs list and collect backlinks map in-memory for the file.
- Acceptance: `:LifeModeRefs` shows refs for node under cursor.

### T07 — Bible reference extraction and parsing (CORE)
- Parse Bible references from markdown text:
  - `John 17:20` (single verse)
  - `John 17:18-23` (verse range)
  - `Rom 8:28` (abbreviated book names)
  - Support common abbreviations (Gen, Rom, Matt, etc.)
- Create a deterministic ID for each verse: `bible:john:17:20`
- Extract refs from node body and add to refs list
- Acceptance: command shows all Bible refs found in current file with parsed verse IDs.

### T07a — Quickfix "references" view
- Implement `gr` mapping in LifeMode view buffers:
  - find occurrences of the link/node under cursor (initially within current file)
  - populate quickfix list with locations
- Acceptance: `gr` opens quickfix with correct matches.

### T08 — "Definition" jump for wikilinks and Bible refs
- Implement `gd`:
  - resolve `[[Page]]` → open file
  - resolve `[[Page#Heading]]` → jump to heading
  - resolve `[[Page^id]]` → jump to block by id
  - resolve Bible reference (e.g., `John 17:20`) → show verse (inline or separate buffer/provider)
- Acceptance: `gd` works for all forms inside vault, including Bible references.

### T09 — Minimal task state toggle (commanded edit)
- Implement `toggle_task_state(node_id)` patch:
  - edit the checkbox `[ ]` ↔ `[x]` in source line
  - reparse file (MVP) and refresh view
- Acceptance: toggling updates file and view correctly.

### T10 — Task priority bump
- Define priority syntax: `!1` (highest) to `!5` (lowest).
- Implement `inc_priority` (toward !1) / `dec_priority` (toward !5) by editing inline marker.
- Acceptance: keymaps adjust priority and re-render decorations.

### T11 — Basic lens system + lens cycling
- Define lens registry with at least:
  - `task/brief`, `task/detail`, `node/raw`
- Implement `<Space>l` / `<Space>L` to change lens for active instance and re-render span.
- Acceptance: same task displays differently in brief vs detail lens.

### T12 — Active node highlighting + statusline/winbar info
- Highlight active instance span (extmark highlight).
- Populate winbar with `type`, `node_id`, `lens`.
- Acceptance: active node is unambiguous while navigating.

### T13a — Daily view scaffold (date tree, no data)
- Implement basic Daily view: YEAR > MONTH > DAY tree structure.
- Hardcode example dates initially (no index integration).
- Expand today by default, siblings collapsed.
- Acceptance: `:LifeMode` opens empty Daily view tree with example dates.

### T13b — All Tasks view scaffold (grouped tree)
- Implement basic All Tasks view: grouping by due date.
- Hardcode example tasks initially (no index integration).
- Support `:LifeMode tasks` command.
- Acceptance: `:LifeMode tasks` opens empty grouped task tree with example structure.

### T13c — Compiled view render of a page root (single file)
- Create a simple "page view":
  - root instances are top-level nodes of current file
- Render to view buffer with extmarks for each node span.
- Acceptance: `:LifeModePageView` shows the file as a compiled interactive view.

### T14 — Expand/collapse one level (children)
- Implement expansion for instances pointing at nodes with children:
  - expand inserts rendered children lines beneath parent
  - collapse removes them
- Add cycle-safe stack tracking (minimal).
- Acceptance: expand/collapse works and does not duplicate children on repeated expand.

### T15 — Expansion budget + cycle stub
- Add max depth + max nodes per action.
- If cycle detected: render stub line “↩ already shown”.
- Acceptance: crafted cycle does not blow up buffer.

### T16 — Tag add/remove (commanded edit)
- Define tag syntax `#tag/subtag`.
- Implement add/remove tag ops (edit inline).
- Provide a simple prompt for tag string.
- Acceptance: tags update source line and view decorations.

### T17 — Due date set/clear (commanded edit)
- Define due syntax `@due(YYYY-MM-DD)`.
- Implement set/clear due ops.
- Acceptance: due date appears in task/brief lens virtual text.

### T18a — Vault index enhancement: Add file timestamps
- Update `index.build_vault_index()` to capture `mtime` per node.
- Add `nodes_by_date` map: date string → node IDs.
- Acceptance: Index includes date-added data from file timestamps.

### T18b — Lazy index initialization
- Move index build to first `:LifeMode` invocation.
- Store index in plugin state (not requiring manual command).
- Show "Building index..." message on first open.
- Acceptance: First `:LifeMode` builds index automatically.

### T18c — Incremental index updates on save
- Add `BufWritePost` autocmd for vault files.
- Re-index only changed file, merge into vault index.
- Acceptance: Saving vault file updates index in background.

### T19 — Backlinks view buffer for current node/page
- Implement `:LifeModeBacklinks`:
  - show backlinks as a compiled view listing contexts/snippets
- Acceptance: backlinks list updates when files change and is navigable.

### T19a — Node inclusion/transclusion with Telescope picker (HIGH PRIORITY)
- Implement markdown-level inclusion syntax: `![[node-id]]` stored in vault files
- Add command `<Space>mi` (LifeMode include) in Page View:
  - Opens Telescope fuzzy finder with all indexable nodes (tasks, headings, blocks)
  - User selects node to include
  - Insert `![[node-id]]` at cursor position
- Parser enhancement:
  - Recognize `![[node-id]]` as special reference type (inclusion vs regular wikilink)
  - Create inclusion instances (vs regular link references)
- Rendering enhancement:
  - Expand target node content inline (recursive rendering)
  - Add visual distinction (border, background color, highlight)
  - Implement cycle detection (node includes itself transitively → render stub)
- Acceptance: Can search for and insert inclusions; included content renders inline with proper formatting; cycles detected and handled.

### T19b — Auto-task creation with enhanced detail lens + node type highlighting (HIGH PRIORITY)
- Implement automatic UUID insertion when user types `- [ ] ` and completes the line
  - Hook on `InsertLeave` or `TextChanged` for task lines
  - Auto-append `^<uuid>` if missing
- Task details remain inline (markdown-first, no separate files):
  - Use indented property lines as children (already in SPEC C3)
  - Example:
    ```md
    - [ ] Task summary !2 @due(2026-02-01) #tag ^uuid
      depends:: [[Task/Parser]]
      notes about the task...
    ```
- Enhance `task/detail` lens to properly display:
  - Full metadata (priority, due, tags)
  - Child property lines (depends, blocks, outputs)
  - Child notes and subtasks
- Add syntax highlighting by node type in rendered views:
  - Different highlight groups for task nodes, source nodes, verse nodes, text nodes
  - Visual distinction via extmarks (border, background color, icon prefix)
  - Applies to both inline nodes and included nodes
- Acceptance: Typing `- [ ] My task` auto-adds UUID; lens cycling shows brief vs detail properly; node types have distinct visual styling.

### T20 — Minimal query views for tasks
- Implement a tiny filter engine for tasks:
  - `state`, `tag`, `due`
- Add `:LifeModeTasksToday` and `:LifeModeTasksByTag <tag>`.
- Acceptance: results appear in quickfix or a view buffer.

### T21 — Populate Daily view from index
- Connect Daily view to `nodes_by_date` from index.
- Show actual vault nodes grouped by date-added.
- Render with appropriate lenses (tasks: brief, text: raw).
- Acceptance: Daily view shows real vault data by date.

### T22 — Populate All Tasks view from index
- Connect All Tasks view to task query system.
- Group by due date (Overdue/Today/Week/Later/None).
- Allow grouping mode cycling (`<Space>g`).
- Acceptance: All Tasks view shows filtered tasks grouped by due date.

### T23 — Productive edges (depends/blocks) parsing
- Parse property lines in a task subtree:
  - `depends:: [[...]]`
  - `blocks:: [[...]]`
- Index these as typed edges.
- Acceptance: `:LifeModeBlocked` shows tasks with open dependencies.

### T24 — Warn-on-done if blocked (non-enforcing)
- When toggling to done, if `depends::` has unfinished tasks:
  - show warning message (do not block, MVP)
- Acceptance: warning appears with a list of blockers.

### T25 — Source entities + citation mentions (MVP)
- Add `type:: source` node handling and `type:: citation` mention nodes.
- Index citations referencing `source:: [[source:...]]`.
- Acceptance: "show all citations for this source" view works.

### T26 — Provider interface (Bible provider stub)
- Define provider API:
  - `get_node(node_id)` and `expand_selector(selector)`
- Implement a stub provider with a few hardcoded verse nodes.
- Acceptance: selector expands to provider nodes and renders in view.

### T27 — Verse range selector parsing + backlinks accounting
- Parse `John 17:18-23` style text into selector.
- Ensure reference queries for a verse find range mentions (expand at query time if needed).
- Acceptance: searching references for `bible:john:17:20` includes range citations.

### T28 — External engine boundary (RPC skeleton)
- Create an engine process stub (could be Lua first, then swapped):
  - `parse_file`, `build_index`, `view_plan`, `apply_patch`
- Neovim plugin calls engine via RPC.
- Acceptance: same features work with engine calls routed over RPC.

### T29 — Incremental indexing hooks
- On `BufWritePost` and debounced `TextChanged`, update engine index for that file.
- Acceptance: backlinks/tasks views refresh without full rescan.

### T30 — Patch op: replace body (for direct in-view editing, experimental)
- Allow toggling the active span to modifiable on `i/a`.
- On exit insert, diff and send `replace_body(node_id, new_md)`.
- Acceptance: editing updates source file and re-renders span.

### T31 — Creative connection suggestions (non-AI baseline)
- Implement "suggest bridges" based on:
  - shared tags, shared backlinks neighbors, co-occurrence
- Render suggestions as a view with actions:
  - promote → insert a productive/creative link property line
  - ignore → store ignore list (optional, later)
- Acceptance: suggestions appear and can be promoted into explicit edges.

### T32 — Agent-neutral suggestion protocol (comments)
- Define comment block format:
  - `<!-- lifemode:suggest ... -->`
- Implement import/export of suggestions.
- Acceptance: external tool can append suggestions; LifeMode renders and can accept them.


