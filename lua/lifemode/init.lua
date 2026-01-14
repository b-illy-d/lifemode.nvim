-- LifeMode: Markdown-native productivity + wiki system for Neovim
-- Main entry point

local M = {}

-- Internal state
local config = nil

-- Default configuration
local defaults = {
  leader = '<Space>',
  max_depth = 10,
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

  if type(config.bible_version) ~= 'string' then
    error('bible_version must be a string')
  end

  -- Validate boundaries
  if config.max_depth < 1 or config.max_depth > 100 then
    error('max_depth must be between 1 and 100')
  end

  -- Create :LifeModeHello command
  vim.api.nvim_create_user_command('LifeModeHello', function()
    local lines = {
      'LifeMode Configuration:',
      '  vault_root: ' .. config.vault_root,
      '  leader: ' .. config.leader,
      '  max_depth: ' .. config.max_depth,
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
        -- File is in vault - add gd keymap
        vim.keymap.set('n', 'gd', function()
          local navigation = require('lifemode.navigation')
          navigation.goto_definition()
        end, { buffer = bufnr, noremap = true, silent = true, desc = 'Go to definition' })
      end
    end,
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
end

return M
