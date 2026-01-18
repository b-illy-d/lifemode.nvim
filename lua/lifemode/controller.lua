local M = {}

local navigation = require('lifemode.navigation')
local extmarks = require('lifemode.extmarks')

local state = {
  current_view = nil,
  last_view_bufnr = nil,
  active_instance = nil,
}

local GROUPING_CYCLE = {'by_due_date', 'by_priority', 'by_tag'}

function M.get_current_view()
  return state.current_view
end

function M.set_current_view(view_data)
  state.current_view = view_data
end

function M.get_last_view_bufnr()
  return state.last_view_bufnr
end

function M._reset_state()
  state.current_view = nil
  state.last_view_bufnr = nil
  state.active_instance = nil
end

local function get_task_at_cursor()
  local metadata = extmarks.get_instance_at_cursor()
  if not metadata then return nil, nil end
  if metadata.lens and metadata.lens:match('^date/') then return nil, nil end

  local node = metadata.node
  if not node or node.type ~= 'task' then return nil, nil end

  local node_id = metadata.target_id or node.id
  return node_id, metadata
end

local function with_task_at_cursor(fn)
  local node_id = get_task_at_cursor()
  if not node_id then
    vim.notify('No task under cursor', vim.log.levels.WARN)
    return
  end

  local cv = state.current_view
  if not cv then return end

  fn(node_id, cv)
end

local function refresh_index_and_tree(cv, config)
  local index = require('lifemode.index')
  local daily = require('lifemode.views.daily')

  index._reset_state()
  local idx = index.get_or_build(config.vault_root)
  local tree = daily.build_tree(idx, config)

  cv.index = idx
  cv.tree = tree
end

function M.refresh_view(config)
  local cv = state.current_view
  if not cv then return end

  local view_module = cv.view_type == 'tasks'
    and require('lifemode.views.tasks')
    or require('lifemode.views.daily')

  local rendered = view_module.render(cv.tree, { index = cv.index })
  local view = require('lifemode.view')
  view.apply_rendered_content(cv.bufnr, rendered)
  cv.spans = rendered.spans
end

local function refresh_after_patch(config)
  local cv = state.current_view
  if not cv then return end

  refresh_index_and_tree(cv, config)
  M.refresh_view(config)
end

function M.toggle_task(config)
  with_task_at_cursor(function(node_id, cv)
    local patch = require('lifemode.patch')
    local new_state = patch.toggle_task_state(node_id, cv.index)
    if not new_state then return end

    local msg = new_state == 'done' and 'Task completed' or 'Task reopened'
    vim.notify(msg, vim.log.levels.INFO)
    refresh_after_patch(config)
  end)
end

function M.inc_priority(config)
  with_task_at_cursor(function(node_id, cv)
    local patch = require('lifemode.patch')
    local new_priority = patch.inc_priority(node_id, cv.index)
    if new_priority then
      vim.notify('Priority: !' .. new_priority, vim.log.levels.INFO)
    end
    refresh_after_patch(config)
  end)
end

function M.dec_priority(config)
  with_task_at_cursor(function(node_id, cv)
    local patch = require('lifemode.patch')
    local new_priority = patch.dec_priority(node_id, cv.index)
    if new_priority then
      vim.notify('Priority: !' .. new_priority, vim.log.levels.INFO)
    else
      vim.notify('Priority removed', vim.log.levels.INFO)
    end
    refresh_after_patch(config)
  end)
end

function M.create_node_inline(config)
  local cv = state.current_view
  if not cv then return end

  local metadata = extmarks.get_instance_at_cursor()
  local dest_file = metadata and metadata.file
  local target_date = metadata and metadata.date

  local view = require('lifemode.view')
  local bufnr = cv.bufnr

  view.set_modifiable(bufnr, true)

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  vim.api.nvim_buf_set_lines(bufnr, row, row, false, {''})
  vim.api.nvim_win_set_cursor(0, {row + 1, 0})
  vim.cmd('startinsert')

  vim.api.nvim_create_autocmd('InsertLeave', {
    buffer = bufnr,
    once = true,
    callback = function()
      local new_cursor = vim.api.nvim_win_get_cursor(0)
      local new_row = new_cursor[1]
      local lines = vim.api.nvim_buf_get_lines(bufnr, new_row - 1, new_row, false)
      local content = vim.trim(lines[1] or '')

      if content ~= '' then
        if dest_file then
          local patch = require('lifemode.patch')
          patch.create_node(content, dest_file)
          vim.notify('Node created in ' .. vim.fn.fnamemodify(dest_file, ':t'), vim.log.levels.INFO)
        else
          local vault = require('lifemode.vault')
          local props = {}
          if target_date and target_date:match('^%d%d%d%d%-%d%d%-%d%d$') then
            props.created = target_date
          end
          local result = vault.create_task(config.vault_root, content, props)
          local index = require('lifemode.index')
          local parser = require('lifemode.parser')
          local node = parser.parse_file(result.path)
          if node and cv.index then
            index.add_node(cv.index, node, result.path, os.time())
          end
          vim.notify('Task created: ' .. result.id, vim.log.levels.INFO)
        end
      end

      refresh_after_patch(config)
    end,
  })
end

function M.edit_node_inline(config)
  local metadata = extmarks.get_instance_at_cursor()
  if not metadata or not metadata.node then
    vim.notify('No editable node under cursor', vim.log.levels.WARN)
    return
  end

  local cv = state.current_view
  if not cv then return end

  local node_id = metadata.target_id or metadata.node.id
  if not node_id then
    vim.notify('Node has no ID', vim.log.levels.WARN)
    return
  end

  local view = require('lifemode.view')
  view.set_modifiable(cv.bufnr, true)

  vim.cmd('startinsert')

  vim.api.nvim_create_autocmd('InsertLeave', {
    buffer = cv.bufnr,
    once = true,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local lines = vim.api.nvim_buf_get_lines(cv.bufnr, cursor[1] - 1, cursor[1], false)
      local edited_line = lines[1] or ''

      local new_text = edited_line
      new_text = new_text:gsub('^%[.%]%s*', '')
      new_text = new_text:gsub('%s*!%d', '')
      new_text = new_text:gsub('%s*@due%([^)]+%)', '')
      new_text = new_text:gsub('%s*#[%w_/%-]+', '')
      new_text = vim.trim(new_text)

      if new_text ~= '' then
        local patch = require('lifemode.patch')
        patch.update_node_text(node_id, new_text, cv.index)
      end

      refresh_after_patch(config)
    end,
  })
end

local function resolve_jump_target(metadata, idx)
  if metadata.file then
    return metadata.file, metadata.node and metadata.node.line
  end

  if metadata.target_id and idx then
    local loc = idx.node_locations[metadata.target_id]
    if loc then
      return loc.file, loc.line
    end
  end

  return nil, nil
end

function M.jump_to_source()
  local metadata = extmarks.get_instance_at_cursor()
  if not metadata then return end
  if metadata.lens and metadata.lens:match('^date/') then return end

  local cv = state.current_view
  local file, line = resolve_jump_target(metadata, cv and cv.index)
  if not file then return end

  state.last_view_bufnr = vim.api.nvim_get_current_buf()
  vim.cmd('edit ' .. vim.fn.fnameescape(file))
  if line then
    vim.api.nvim_win_set_cursor(0, {line + 1, 0})
  end
end

function M.return_to_view()
  if not state.last_view_bufnr then return end
  if not vim.api.nvim_buf_is_valid(state.last_view_bufnr) then
    state.last_view_bufnr = nil
    return
  end
  vim.api.nvim_set_current_buf(state.last_view_bufnr)
end

local function show_backlinks_qf(target, idx)
  if not target then return end

  local index = require('lifemode.index')
  local backlinks = index.get_backlinks(target, idx)

  if #backlinks == 0 then
    vim.notify('No backlinks found for: ' .. target, vim.log.levels.INFO)
    return
  end

  local qf_items = vim.tbl_map(function(link)
    return {
      filename = link.file,
      lnum = (link.line or 0) + 1,
      text = 'References: ' .. target,
    }
  end, backlinks)

  vim.fn.setqflist(qf_items)
  vim.cmd('copen')
end

function M.backlinks_at_cursor()
  local metadata = extmarks.get_instance_at_cursor()
  if not metadata then return end
  if metadata.lens and metadata.lens:match('^date/') then return end

  local node = metadata.node
  if not node then return end

  local target = node.text or node.id
  if not target then return end

  local cv = state.current_view
  show_backlinks_qf(target, cv and cv.index)
end

function M.bible_backlinks_at_cursor(config)
  local bible = require('lifemode.bible')
  local ref = bible.get_ref_at_cursor()

  if not ref then
    vim.notify('No Bible reference at cursor', vim.log.levels.INFO)
    return
  end

  local index = require('lifemode.index')
  local idx = index.get_or_build(config.vault_root)
  local verse_id = bible.generate_verse_id(ref.book, ref.chapter, ref.verse_start)
  show_backlinks_qf(verse_id, idx)
end

function M.cycle_lens_at_cursor(direction, config)
  local lens_module = require('lifemode.lens')

  local metadata = extmarks.get_instance_at_cursor()
  if not metadata then return end
  if metadata.lens and metadata.lens:match('^date/') then return end

  local node = metadata.node
  if not node then return end

  local current_lens = metadata.lens or lens_module.get_available_lenses(node.type)[1]
  local next_lens = lens_module.cycle(current_lens, node.type, direction)

  if next_lens ~= current_lens then
    metadata.lens = next_lens
    M.refresh_view(config)
  end
end

function M.cycle_grouping(config)
  local cv = state.current_view
  if not cv then return end
  if cv.view_type ~= 'tasks' then return end

  local current = cv.tree and cv.tree.grouping or 'by_due_date'
  local next_idx = 1
  for i, g in ipairs(GROUPING_CYCLE) do
    if g == current then
      next_idx = (i % #GROUPING_CYCLE) + 1
      break
    end
  end

  local new_grouping = GROUPING_CYCLE[next_idx]
  local tasks_view = require('lifemode.views.tasks')
  local view = require('lifemode.view')

  local tree = tasks_view.build_tree(cv.index, { grouping = new_grouping })
  local rendered = tasks_view.render(tree, { index = cv.index })

  cv.tree = tree
  view.apply_rendered_content(cv.bufnr, rendered)
  cv.spans = rendered.spans
end

function M.update_active_node()
  local cv = state.current_view
  if not cv then return end

  state.active_instance = extmarks.get_instance_at_cursor()
end

function M.get_statusline_info()
  local meta = state.active_instance
  if not meta then return '' end

  local parts = {}
  local node = meta.node

  if node then
    table.insert(parts, node.type or 'unknown')
  end

  if meta.lens then
    table.insert(parts, '[' .. meta.lens .. ']')
  end

  local id = meta.target_id or (node and node.id)
  if id then
    local short_id = #id > 12 and (id:sub(1, 12) .. '...') or id
    table.insert(parts, '^' .. short_id)
  end

  if meta.depth then
    table.insert(parts, 'd:' .. meta.depth)
  end

  return table.concat(parts, ' ')
end

local function setup_highlight_groups()
  vim.api.nvim_set_hl(0, 'LifeModeActive', { bold = true, underline = true })
end

local function setup_cursor_autocmd(bufnr)
  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = bufnr,
    callback = M.update_active_node,
  })
end

function M.setup_keymaps(bufnr, config)
  setup_highlight_groups()
  setup_cursor_autocmd(bufnr)

  local opts = { buffer = bufnr, silent = true }
  local cv = function() return state.current_view end
  local refresh = function() M.refresh_view(config) end

  vim.keymap.set('n', '<CR>', function() navigation.toggle_at_cursor(cv(), refresh) end, opts)
  vim.keymap.set('n', 'zo', function() navigation.expand_at_cursor(cv(), refresh) end, opts)
  vim.keymap.set('n', 'zc', function() navigation.collapse_at_cursor(cv(), refresh) end, opts)
  vim.keymap.set('n', ']d', function() navigation.jump(cv(), 'date/day', 1, refresh) end, opts)
  vim.keymap.set('n', '[d', function() navigation.jump(cv(), 'date/day', -1, refresh) end, opts)
  vim.keymap.set('n', ']m', function() navigation.jump(cv(), 'date/month', 1, refresh) end, opts)
  vim.keymap.set('n', '[m', function() navigation.jump(cv(), 'date/month', -1, refresh) end, opts)
  vim.keymap.set('n', 'gd', M.jump_to_source, opts)
  vim.keymap.set('n', '<Space><Space>', function() M.toggle_task(config) end, opts)
  vim.keymap.set('n', '<Space>tp', function() M.inc_priority(config) end, opts)
  vim.keymap.set('n', '<Space>tP', function() M.dec_priority(config) end, opts)
  vim.keymap.set('n', '<Space>g', function() M.cycle_grouping(config) end, opts)
  vim.keymap.set('n', 'gr', M.backlinks_at_cursor, opts)
  vim.keymap.set('n', '<Space>l', function() M.cycle_lens_at_cursor(1, config) end, opts)
  vim.keymap.set('n', '<Space>L', function() M.cycle_lens_at_cursor(-1, config) end, opts)
  vim.keymap.set('n', 'q', function() vim.cmd('bdelete') end, opts)
  vim.keymap.set('n', 'o', function() M.create_node_inline(config) end, opts)
  vim.keymap.set('n', 'i', function() M.edit_node_inline(config) end, opts)
  vim.keymap.set('n', 'a', function()
    M.edit_node_inline(config)
    vim.schedule(function() vim.cmd('normal! l') end)
  end, opts)
end

function M.expand_at_cursor(config)
  navigation.expand_at_cursor(state.current_view, function() M.refresh_view(config) end)
end

function M.collapse_at_cursor(config)
  navigation.collapse_at_cursor(state.current_view, function() M.refresh_view(config) end)
end

function M.jump_day(direction, config)
  navigation.jump(state.current_view, 'date/day', direction, function() M.refresh_view(config) end)
end

function M.jump_month(direction, config)
  navigation.jump(state.current_view, 'date/month', direction, function() M.refresh_view(config) end)
end

return M
