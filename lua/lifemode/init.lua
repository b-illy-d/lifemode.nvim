-- LifeMode: Markdown-native productivity + wiki system for Neovim
-- Main entry point

local M = {}

-- Internal state
local config = nil

-- Default configuration
local defaults = {
  leader = '<Space>',
  max_depth = 10,
  max_nodes_per_action = 100,
  bible_version = 'ESV',
}

-- Setup function - entry point for plugin configuration
function M.setup(user_config)
  user_config = user_config or {}

  -- Validate required config
  if not user_config.vault_root then
    error('vault_root is required')
  end

  if type(user_config.vault_root) ~= 'string' then
    error('vault_root must be a string')
  end

  -- Check for empty/whitespace vault_root
  if user_config.vault_root:match('^%s*$') then
    error('vault_root cannot be empty or whitespace')
  end

  -- Merge user config with defaults
  config = vim.tbl_extend('force', defaults, user_config)

  -- Validate types after merge
  if type(config.leader) ~= 'string' then
    error('leader must be a string')
  end

  if type(config.max_depth) ~= 'number' then
    error('max_depth must be a number')
  end

  if type(config.max_nodes_per_action) ~= 'number' then
    error('max_nodes_per_action must be a number')
  end

  if type(config.bible_version) ~= 'string' then
    error('bible_version must be a string')
  end

  -- Validate boundaries
  if config.max_depth < 1 or config.max_depth > 100 then
    error('max_depth must be between 1 and 100')
  end

  if config.max_nodes_per_action < 1 or config.max_nodes_per_action > 10000 then
    error('max_nodes_per_action must be between 1 and 10000')
  end

  -- Create :LifeModeHello command
  vim.api.nvim_create_user_command('LifeModeHello', function()
    local lines = {
      'LifeMode Configuration:',
      '  vault_root: ' .. config.vault_root,
      '  leader: ' .. config.leader,
      '  max_depth: ' .. config.max_depth,
      '  max_nodes_per_action: ' .. config.max_nodes_per_action,
      '  bible_version: ' .. config.bible_version,
    }
    for _, line in ipairs(lines) do
      vim.api.nvim_echo({{line, 'Normal'}}, true, {})
    end
  end, {
    desc = 'Show LifeMode configuration'
  })

  -- Create :LifeModeOpen command
  vim.api.nvim_create_user_command('LifeModeOpen', function()
    local view = require('lifemode.view')
    view.create_buffer()
  end, {
    desc = 'Open a LifeMode view buffer'
  })

  -- Create :LifeModeDebugSpan command
  vim.api.nvim_create_user_command('LifeModeDebugSpan', function()
    local extmarks = require('lifemode.extmarks')
    local metadata = extmarks.get_span_at_cursor()

    if metadata then
      local lines = {
        'Span Metadata at Cursor:',
        '  instance_id: ' .. (metadata.instance_id or 'nil'),
        '  node_id: ' .. (metadata.node_id or 'nil'),
        '  lens: ' .. (metadata.lens or 'nil'),
        '  span_start: ' .. (metadata.span_start or 'nil'),
        '  span_end: ' .. (metadata.span_end or 'nil'),
      }
      for _, line in ipairs(lines) do
        vim.api.nvim_echo({{line, 'Normal'}}, true, {})
      end
    else
      vim.api.nvim_echo({{'No span metadata at cursor', 'WarningMsg'}}, true, {})
    end
  end, {
    desc = 'Debug: show span metadata at cursor'
  })

  -- Create :LifeModeParse command
  vim.api.nvim_create_user_command('LifeModeParse', function()
    local parser = require('lifemode.parser')
    local bufnr = vim.api.nvim_get_current_buf()
    local blocks = parser.parse_buffer(bufnr)

    -- Count tasks
    local task_count = 0
    for _, block in ipairs(blocks) do
      if block.type == 'task' then
        task_count = task_count + 1
      end
    end

    -- Print summary
    local lines = {
      'Markdown Parser Results:',
      '  Total blocks: ' .. #blocks,
      '  Tasks: ' .. task_count,
    }
    for _, line in ipairs(lines) do
      vim.api.nvim_echo({{line, 'Normal'}}, true, {})
    end
  end, {
    desc = 'Parse current buffer and show block count + task count'
  })

  -- Create :LifeModeEnsureIDs command
  vim.api.nvim_create_user_command('LifeModeEnsureIDs', function()
    local blocks = require('lifemode.blocks')
    local bufnr = vim.api.nvim_get_current_buf()
    local ids_added = blocks.ensure_ids_in_buffer(bufnr)

    local msg = string.format('Added %d ID%s to tasks', ids_added, ids_added == 1 and '' or 's')
    vim.api.nvim_echo({{msg, 'Normal'}}, true, {})
  end, {
    desc = 'Ensure all tasks in current buffer have IDs'
  })

  -- Create :LifeModeShowNodes command
  vim.api.nvim_create_user_command('LifeModeShowNodes', function()
    local node = require('lifemode.node')
    local bufnr = vim.api.nvim_get_current_buf()
    local result = node.build_nodes_from_buffer(bufnr)

    -- Helper to print tree recursively
    local function print_tree(node_id, depth)
      local n = result.nodes_by_id[node_id]
      if not n then return end

      local indent = string.rep('  ', depth)
      local type_label = string.format('[%s]', n.type)
      local body_preview = n.body_md:sub(1, 60)
      if #n.body_md > 60 then
        body_preview = body_preview .. '...'
      end

      vim.api.nvim_echo({{
        string.format('%s%s %s: %s', indent, type_label, n.id, body_preview),
        'Normal'
      }}, true, {})

      -- Print children
      for _, child_id in ipairs(n.children) do
        print_tree(child_id, depth + 1)
      end
    end

    -- Print header
    local lines = {
      'Node Tree:',
      '  Total nodes: ' .. vim.tbl_count(result.nodes_by_id),
      '  Root nodes: ' .. #result.root_ids,
      '',
    }
    for _, line in ipairs(lines) do
      vim.api.nvim_echo({{line, 'Normal'}}, true, {})
    end

    -- Print tree for each root
    for _, root_id in ipairs(result.root_ids) do
      print_tree(root_id, 0)
    end
  end, {
    desc = 'Show node tree structure for current buffer'
  })

  -- Create :LifeModeRefs command
  vim.api.nvim_create_user_command('LifeModeRefs', function()
    local node = require('lifemode.node')
    local extmarks = require('lifemode.extmarks')
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1]

    -- Build nodes from buffer
    local result = node.build_nodes_from_buffer(bufnr)

    -- Find node at cursor position
    local current_node = nil
    for node_id, n in pairs(result.nodes_by_id) do
      -- Check if cursor is within node body
      -- For simplicity, match by line number (assumes single-line nodes for MVP)
      if n.body_md then
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        for i, l in ipairs(lines) do
          if l == n.body_md and i == line then
            current_node = n
            break
          end
        end
        if current_node then break end
      end
    end

    if not current_node then
      vim.api.nvim_echo({{'No node found at cursor', 'WarningMsg'}}, true, {})
      return
    end

    -- Display refs for this node
    vim.api.nvim_echo({{'References for node: ' .. current_node.id, 'Title'}}, true, {})
    vim.api.nvim_echo({{'', 'Normal'}}, true, {})

    -- Show outbound refs
    vim.api.nvim_echo({{'Outbound links (' .. #current_node.refs .. '):', 'Normal'}}, true, {})
    if #current_node.refs == 0 then
      vim.api.nvim_echo({{'  (none)', 'Comment'}}, true, {})
    else
      for _, ref in ipairs(current_node.refs) do
        vim.api.nvim_echo({{
          string.format('  -> %s (%s)', ref.target, ref.type),
          'Normal'
        }}, true, {})
      end
    end

    vim.api.nvim_echo({{'', 'Normal'}}, true, {})

    -- Show backlinks (inbound refs)
    local backlink_count = 0
    for target, sources in pairs(result.backlinks) do
      if target == current_node.id then
        backlink_count = #sources
        break
      end
    end

    vim.api.nvim_echo({{'Backlinks (' .. backlink_count .. '):', 'Normal'}}, true, {})
    if backlink_count == 0 then
      vim.api.nvim_echo({{'  (none)', 'Comment'}}, true, {})
    else
      for target, sources in pairs(result.backlinks) do
        if target == current_node.id then
          for _, source_id in ipairs(sources) do
            local source_node = result.nodes_by_id[source_id]
            local preview = source_node.body_md:sub(1, 60)
            if #source_node.body_md > 60 then
              preview = preview .. '...'
            end
            vim.api.nvim_echo({{
              string.format('  <- %s: %s', source_id, preview),
              'Normal'
            }}, true, {})
          end
          break
        end
      end
    end
  end, {
    desc = 'Show references (outbound + backlinks) for node at cursor'
  })

  -- Create :LifeModeBibleRefs command
  vim.api.nvim_create_user_command('LifeModeBibleRefs', function()
    local node = require('lifemode.node')
    local bufnr = vim.api.nvim_get_current_buf()

    -- Build nodes from buffer
    local result = node.build_nodes_from_buffer(bufnr)

    -- Collect all Bible references from all nodes
    local bible_refs = {}
    for node_id, n in pairs(result.nodes_by_id) do
      for _, ref in ipairs(n.refs) do
        if ref.type == "bible_verse" then
          table.insert(bible_refs, {
            target = ref.target,
            node_id = node_id,
            body = n.body_md
          })
        end
      end
    end

    -- Display results
    vim.api.nvim_echo({{'Bible References in Buffer', 'Title'}}, true, {})
    vim.api.nvim_echo({{'', 'Normal'}}, true, {})

    if #bible_refs == 0 then
      vim.api.nvim_echo({{'No Bible references found', 'Comment'}}, true, {})
    else
      vim.api.nvim_echo({{
        string.format('Found %d Bible reference(s):', #bible_refs),
        'Normal'
      }}, true, {})
      vim.api.nvim_echo({{'', 'Normal'}}, true, {})

      for _, ref in ipairs(bible_refs) do
        -- Show verse ID
        vim.api.nvim_echo({{
          string.format('  %s', ref.target),
          'Identifier'
        }}, true, {})

        -- Show node context (truncated)
        local preview = ref.body:sub(1, 60)
        if #ref.body > 60 then
          preview = preview .. '...'
        end
        vim.api.nvim_echo({{
          string.format('    in node %s: %s', ref.node_id, preview),
          'Comment'
        }}, true, {})
      end
    end
  end, {
    desc = 'Show all Bible references found in current buffer'
  })

  -- Create :LifeModeGotoDef command (manual testing for goto_definition)
  vim.api.nvim_create_user_command('LifeModeGotoDef', function()
    local navigation = require('lifemode.navigation')
    navigation.goto_definition()
  end, {
    desc = 'Go to definition for wikilink or Bible ref under cursor'
  })

  -- Set up autocommand to add gd keymap to markdown files in vault
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'markdown',
    callback = function(args)
      local bufnr = args.buf
      -- Check if this file is in the vault
      local filepath = vim.api.nvim_buf_get_name(bufnr)
      if filepath:match('^' .. vim.pesc(config.vault_root)) then
        -- File is in vault - add gd and gr keymaps
        vim.keymap.set('n', 'gd', function()
          local navigation = require('lifemode.navigation')
          navigation.goto_definition()
        end, { buffer = bufnr, noremap = true, silent = true, desc = 'Go to definition' })

        vim.keymap.set('n', 'gr', function()
          local references = require('lifemode.references')
          references.find_references_at_cursor()
        end, { buffer = bufnr, noremap = true, silent = true, desc = 'Find references' })

        -- Add <leader><leader> keymap for task toggle
        vim.keymap.set('n', config.leader .. config.leader, function()
          local tasks = require('lifemode.tasks')
          local node_id, buf = tasks.get_task_at_cursor()
          if node_id then
            local success = tasks.toggle_task_state(buf, node_id)
            if success then
              vim.api.nvim_echo({{'Task state toggled', 'Normal'}}, false, {})
            else
              vim.api.nvim_echo({{'Failed to toggle task state', 'WarningMsg'}}, false, {})
            end
          else
            vim.api.nvim_echo({{'No task at cursor', 'WarningMsg'}}, false, {})
          end
        end, { buffer = bufnr, noremap = true, silent = true, desc = 'Toggle task state' })

        -- Auto-insert UUID for tasks on InsertLeave
        vim.api.nvim_create_autocmd('InsertLeave', {
          buffer = bufnr,
          callback = function()
            local cursor = vim.api.nvim_win_get_cursor(0)
            local line_num = cursor[1]
            local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]

            -- Check if this is a task line without an ID
            if line and line:match('^%s*%- %[.%]') and not line:match('%^[%w%-_]+%s*$') then
              -- Generate UUID and append to line
              local uuid = require('lifemode.uuid')
              local new_uuid = uuid.generate()
              local new_line = line .. ' ^' .. new_uuid

              -- Update the line
              vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {new_line})
            end
          end,
        })
      end
    end,
  })

  -- Create :LifeModeToggleTask command for manual testing
  vim.api.nvim_create_user_command('LifeModeToggleTask', function()
    local tasks = require('lifemode.tasks')
    local node_id, bufnr = tasks.get_task_at_cursor()
    if node_id then
      local success = tasks.toggle_task_state(bufnr, node_id)
      if success then
        vim.api.nvim_echo({{'Task state toggled', 'Normal'}}, false, {})
      else
        vim.api.nvim_echo({{'Failed to toggle task state', 'WarningMsg'}}, false, {})
      end
    else
      vim.api.nvim_echo({{'No task at cursor', 'WarningMsg'}}, false, {})
    end
  end, {
    desc = 'Toggle task state at cursor'
  })

  -- Create :LifeModeIncPriority command
  vim.api.nvim_create_user_command('LifeModeIncPriority', function()
    local tasks = require('lifemode.tasks')
    local node_id, bufnr = tasks.get_task_at_cursor()
    if node_id then
      local success = tasks.inc_priority(bufnr, node_id)
      if success then
        vim.api.nvim_echo({{'Task priority increased', 'Normal'}}, false, {})
      else
        vim.api.nvim_echo({{'Failed to increase priority', 'WarningMsg'}}, false, {})
      end
    else
      vim.api.nvim_echo({{'No task at cursor', 'WarningMsg'}}, false, {})
    end
  end, {
    desc = 'Increase task priority (toward !1)'
  })

  -- Create :LifeModeDecPriority command
  vim.api.nvim_create_user_command('LifeModeDecPriority', function()
    local tasks = require('lifemode.tasks')
    local node_id, bufnr = tasks.get_task_at_cursor()
    if node_id then
      local success = tasks.dec_priority(bufnr, node_id)
      if success then
        vim.api.nvim_echo({{'Task priority decreased', 'Normal'}}, false, {})
      else
        vim.api.nvim_echo({{'Failed to decrease priority', 'WarningMsg'}}, false, {})
      end
    else
      vim.api.nvim_echo({{'No task at cursor', 'WarningMsg'}}, false, {})
    end
  end, {
    desc = 'Decrease task priority (toward !5)'
  })

  -- Create :LifeModeAddTag command
  vim.api.nvim_create_user_command('LifeModeAddTag', function()
    local tasks = require('lifemode.tasks')
    tasks.add_tag_interactive()
  end, {
    desc = 'Add tag to task at cursor'
  })

  -- Create :LifeModeRemoveTag command
  vim.api.nvim_create_user_command('LifeModeRemoveTag', function()
    local tasks = require('lifemode.tasks')
    tasks.remove_tag_interactive()
  end, {
    desc = 'Remove tag from task at cursor'
  })

  -- Create :LifeModeSetDue command
  vim.api.nvim_create_user_command('LifeModeSetDue', function()
    local tasks = require('lifemode.tasks')
    tasks.set_due_interactive()
  end, {
    desc = 'Set due date on task at cursor'
  })

  -- Create :LifeModeClearDue command
  vim.api.nvim_create_user_command('LifeModeClearDue', function()
    local tasks = require('lifemode.tasks')
    tasks.clear_due_interactive()
  end, {
    desc = 'Clear due date from task at cursor'
  })

  -- Create :LifeModeRebuildIndex command
  vim.api.nvim_create_user_command('LifeModeRebuildIndex', function()
    local index = require('lifemode.index')
    local vault_root = config.vault_root

    vim.api.nvim_echo({{"Building vault index...", "Normal"}}, true, {})

    -- Build index
    local idx = index.build_vault_index(vault_root)

    -- Count nodes and backlinks
    local node_count = 0
    for _ in pairs(idx.node_locations) do node_count = node_count + 1 end

    local backlink_count = 0
    for _ in pairs(idx.backlinks) do backlink_count = backlink_count + 1 end

    -- Store in config for gr to use
    config.vault_index = idx

    vim.api.nvim_echo({{
      string.format("Index built: %d nodes, %d backlink targets", node_count, backlink_count),
      "Normal"
    }}, true, {})
  end, {
    desc = 'Rebuild vault-wide index'
  })

  -- Create :LifeModeBacklinks command
  vim.api.nvim_create_user_command('LifeModeBacklinks', function()
    local backlinks = require('lifemode.backlinks')
    backlinks.show_backlinks()
  end, {
    desc = 'Show backlinks for current node/page'
  })

  -- Create :LifeModeIncludeNode command
  vim.api.nvim_create_user_command('LifeModeIncludeNode', function()
    local inclusion = require('lifemode.inclusion')
    inclusion.include_node_interactive()
  end, {
    desc = 'Insert node inclusion at cursor'
  })

  -- Create :LifeModeEditTaskDetails command
  vim.api.nvim_create_user_command('LifeModeEditTaskDetails', function()
    local tasks = require('lifemode.tasks')
    tasks.edit_task_details()
  end, {
    desc = 'Open/create task detail file for task at cursor'
  })

  -- Create :LifeModeTasksToday command
  vim.api.nvim_create_user_command('LifeModeTasksToday', function()
    local query = require('lifemode.query')
    local tasks_today = query.get_tasks_today()
    query.show_tasks_quickfix(tasks_today, "Tasks Due Today")
  end, {
    desc = 'Show tasks due today in quickfix list'
  })

  -- Create :LifeModeTasksByTag command
  vim.api.nvim_create_user_command('LifeModeTasksByTag', function(opts)
    local tag = opts.args
    if not tag or tag == "" then
      vim.api.nvim_echo({{'Please provide a tag name', 'ErrorMsg'}}, true, {})
      return
    end

    local query = require('lifemode.query')
    local tasks_by_tag = query.get_tasks_by_tag(tag)
    query.show_tasks_quickfix(tasks_by_tag, string.format("Tasks Tagged: #%s", tag))
  end, {
    nargs = 1,
    desc = 'Show tasks with specified tag in quickfix list'
  })

  -- Create :LifeModeTasksAll command
  vim.api.nvim_create_user_command('LifeModeTasksAll', function()
    local query = require('lifemode.query')
    local all_tasks = query.get_all_todo_tasks()
    query.show_tasks_quickfix(all_tasks, "All TODO Tasks")
  end, {
    desc = 'Show all TODO tasks in quickfix list'
  })

  -- Create :LifeModeTasksOverdue command
  vim.api.nvim_create_user_command('LifeModeTasksOverdue', function()
    local query = require('lifemode.query')
    local overdue_tasks = query.get_overdue_tasks()
    query.show_tasks_quickfix(overdue_tasks, "Overdue Tasks")
  end, {
    desc = 'Show overdue tasks in quickfix list'
  })

  -- Add priority keymaps to markdown files in vault
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'markdown',
    callback = function(args)
      local filepath = vim.api.nvim_buf_get_name(args.buf)
      -- Only add keymaps if file is in vault
      if filepath:match('^' .. vim.pesc(config.vault_root)) then
        -- <Space>tp: increment priority
        vim.keymap.set('n', config.leader .. 'tp', function()
          local tasks = require('lifemode.tasks')
          local node_id, bufnr = tasks.get_task_at_cursor()
          if node_id then
            local success = tasks.inc_priority(bufnr, node_id)
            if success then
              vim.api.nvim_echo({{'Priority increased', 'Normal'}}, false, {})
            else
              vim.api.nvim_echo({{'Failed to increase priority', 'WarningMsg'}}, false, {})
            end
          else
            vim.api.nvim_echo({{'No task at cursor', 'WarningMsg'}}, false, {})
          end
        end, { buffer = args.buf, noremap = true, silent = true, desc = 'Increase task priority' })

        -- <Space>tP: decrement priority
        vim.keymap.set('n', config.leader .. 'tP', function()
          local tasks = require('lifemode.tasks')
          local node_id, bufnr = tasks.get_task_at_cursor()
          if node_id then
            local success = tasks.dec_priority(bufnr, node_id)
            if success then
              vim.api.nvim_echo({{'Priority decreased', 'Normal'}}, false, {})
            else
              vim.api.nvim_echo({{'Failed to decrease priority', 'WarningMsg'}}, false, {})
            end
          else
            vim.api.nvim_echo({{'No task at cursor', 'WarningMsg'}}, false, {})
          end
        end, { buffer = args.buf, noremap = true, silent = true, desc = 'Decrease task priority' })

        -- <Space>tt: edit tags (add/remove tag prompt)
        vim.keymap.set('n', config.leader .. 'tt', function()
          local tasks = require('lifemode.tasks')
          tasks.add_tag_interactive()
        end, { buffer = args.buf, noremap = true, silent = true, desc = 'Add tag to task' })

        -- <Space>td: set due date
        vim.keymap.set('n', config.leader .. 'td', function()
          local tasks = require('lifemode.tasks')
          tasks.set_due_interactive()
        end, { buffer = args.buf, noremap = true, silent = true, desc = 'Set due date on task' })

        -- <Space>vb: show backlinks
        vim.keymap.set('n', config.leader .. 'vb', function()
          local backlinks = require('lifemode.backlinks')
          backlinks.show_backlinks()
        end, { buffer = args.buf, noremap = true, silent = true, desc = 'Show backlinks for current node/page' })

        -- <Space>mi: include node
        vim.keymap.set('n', config.leader .. 'mi', function()
          local inclusion = require('lifemode.inclusion')
          inclusion.include_node_interactive()
        end, { buffer = args.buf, noremap = true, silent = true, desc = 'Insert node inclusion' })

        -- <Space>te: edit task details
        vim.keymap.set('n', config.leader .. 'te', function()
          local tasks = require('lifemode.tasks')
          tasks.edit_task_details()
        end, { buffer = args.buf, noremap = true, silent = true, desc = 'Edit task details' })

        -- <Space>vt: tasks by tag
        vim.keymap.set('n', config.leader .. 'vt', function()
          vim.ui.input({ prompt = 'Enter tag: ' }, function(tag)
            if tag and tag ~= "" then
              local query = require('lifemode.query')
              local tasks_by_tag = query.get_tasks_by_tag(tag)
              query.show_tasks_quickfix(tasks_by_tag, string.format("Tasks Tagged: #%s", tag))
            end
          end)
        end, { buffer = args.buf, noremap = true, silent = true, desc = 'View tasks by tag' })

        -- <Space>vv: all tasks view
        vim.keymap.set('n', config.leader .. 'vv', function()
          local query = require('lifemode.query')
          local all_tasks = query.get_all_todo_tasks()
          query.show_tasks_quickfix(all_tasks, "All TODO Tasks")
        end, { buffer = args.buf, noremap = true, silent = true, desc = 'View all tasks' })
      end
    end,
  })

  -- Create :LifeModeLensNext command
  vim.api.nvim_create_user_command('LifeModeLensNext', function()
    local lens = require('lifemode.lens')
    -- For MVP, just show message about lens cycling
    -- In future: get current lens from active instance, cycle, re-render
    local current = "task/brief"  -- default for MVP
    local next_lens = lens.cycle_lens(current, 1)
    vim.api.nvim_echo({{'Next lens: ' .. next_lens, 'Normal'}}, false, {})
  end, {
    desc = 'Cycle to next lens for active instance'
  })

  -- Create :LifeModeLensPrev command
  vim.api.nvim_create_user_command('LifeModeLensPrev', function()
    local lens = require('lifemode.lens')
    -- For MVP, just show message about lens cycling
    -- In future: get current lens from active instance, cycle, re-render
    local current = "task/brief"  -- default for MVP
    local prev_lens = lens.cycle_lens(current, -1)
    vim.api.nvim_echo({{'Previous lens: ' .. prev_lens, 'Normal'}}, false, {})
  end, {
    desc = 'Cycle to previous lens for active instance'
  })

  -- Create :LifeModePageView command
  vim.api.nvim_create_user_command('LifeModePageView', function()
    local render = require('lifemode.render')
    local source_bufnr = vim.api.nvim_get_current_buf()
    local view_bufnr = render.render_page_view(source_bufnr)
    vim.api.nvim_set_current_buf(view_bufnr)

    -- Enable active node tracking
    local activenode = require('lifemode.activenode')
    activenode.track_cursor_movement(view_bufnr)
  end, {
    desc = 'Render current file as compiled page view'
  })
end

-- Get current configuration (for testing and internal use)
function M.get_config()
  if not config then
    error('LifeMode is not configured. Call setup() first.')
  end
  return config
end

-- Reset config for testing
function M._reset_for_testing()
  config = nil
  -- Remove commands if they exist
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeHello')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeOpen')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeDebugSpan')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeParse')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeEnsureIDs')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeShowNodes')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeRefs')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeBibleRefs')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeGotoDef')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeToggleTask')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeIncPriority')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeDecPriority')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeAddTag')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeRemoveTag')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeSetDue')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeClearDue')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeRebuildIndex')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeLensNext')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeLensPrev')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModePageView')
  end)
  pcall(function()
    vim.api.nvim_del_user_command('LifeModeBacklinks')
  end)
end

return M
