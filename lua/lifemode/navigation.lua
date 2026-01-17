local M = {}

local function find_spans_by_lens(spans, lens_name)
  local result = {}
  for _, span in ipairs(spans) do
    if span.lens == lens_name then
      table.insert(result, span)
    end
  end
  return result
end

local function find_next_span(spans, current_line)
  for _, span in ipairs(spans) do
    if span.line_start > current_line then
      return span
    end
  end
  return nil
end

local function find_prev_span(spans, current_line)
  for i = #spans, 1, -1 do
    if spans[i].line_start < current_line then
      return spans[i]
    end
  end
  return nil
end

function M.jump(view_state, lens_name, direction, refresh_fn)
  if not view_state then return end

  local matching_spans = find_spans_by_lens(view_state.spans, lens_name)
  if #matching_spans == 0 then return end

  local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1

  local target = direction > 0
    and find_next_span(matching_spans, current_line)
    or find_prev_span(matching_spans, current_line)

  if not target then return end

  M.jump_to_span(view_state, target, refresh_fn)
end

function M.jump_to_span(view_state, target, refresh_fn)
  if target.instance and target.instance.collapsed then
    target.instance.collapsed = false
    refresh_fn()

    for _, span in ipairs(view_state.spans) do
      if span.instance_id == target.instance_id then
        vim.api.nvim_win_set_cursor(0, {span.line_start + 1, 0})
        return
      end
    end
  else
    vim.api.nvim_win_set_cursor(0, {target.line_start + 1, 0})
  end
end

function M.expand_at_cursor(view_state, refresh_fn)
  if not view_state then return end

  local extmarks = require('lifemode.extmarks')
  local metadata = extmarks.get_instance_at_cursor()

  if not metadata or not metadata.instance then return end
  if metadata.instance.collapsed == nil then return end
  if not metadata.instance.collapsed then return end

  metadata.instance.collapsed = false
  refresh_fn()
end

function M.collapse_at_cursor(view_state, refresh_fn)
  if not view_state then return end

  local extmarks = require('lifemode.extmarks')
  local metadata = extmarks.get_instance_at_cursor()

  if not metadata or not metadata.instance then return end
  if metadata.instance.collapsed == nil then return end
  if metadata.instance.collapsed then return end

  metadata.instance.collapsed = true
  refresh_fn()
end

return M
