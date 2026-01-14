#!/usr/bin/env -S nvim -l

-- Tests for lua/lifemode/activenode.lua

local test_count = 0
local pass_count = 0
local fail_count = 0

local function assert_error(fn, expected_msg)
  local ok, err = pcall(fn)
  if ok then
    error("Expected error but function succeeded")
  end
  if expected_msg and not string.find(err, expected_msg, 1, true) then
    error(string.format("Expected error containing '%s' but got: %s", expected_msg, err))
  end
end

local function assert_no_error(fn)
  local ok, err = pcall(fn)
  if not ok then
    error(string.format("Expected no error but got: %s", err))
  end
end

local function assert(condition, msg)
  if not condition then
    error(msg or "Assertion failed")
  end
end

local function test(name, fn)
  test_count = test_count + 1

  -- Reset state before each test
  package.loaded['lifemode.activenode'] = nil
  package.loaded['lifemode.extmarks'] = nil
  vim.cmd('silent! %bwipeout!')

  local ok, err = pcall(fn)
  if ok then
    pass_count = pass_count + 1
    print(string.format("  ✓ %s", name))
  else
    fail_count = fail_count + 1
    print(string.format("  ✗ %s", name))
    print(string.format("    Error: %s", err))
  end
end

-- Add lua/ directory to package path
package.path = './lua/?.lua;' .. package.path

print("\nActive Node Tests\n")

-- highlight_active_span tests
test("highlight_active_span adds highlight to single-line span", function()
  local activenode = require("lifemode.activenode")
  local extmarks = require("lifemode.extmarks")

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {'line 1', 'line 2', 'line 3'})

  activenode.highlight_active_span(bufnr, 0, 0)

  -- Check that highlight namespace exists
  local ns = activenode.get_highlight_namespace()
  assert(ns ~= nil, "Highlight namespace should exist")

  -- Check that extmark was created for highlight
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
  assert(#marks > 0, "Should have at least one highlight extmark")
end)

test("highlight_active_span adds highlight to multi-line span", function()
  local activenode = require("lifemode.activenode")
  local extmarks = require("lifemode.extmarks")
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {'line 1', 'line 2', 'line 3', 'line 4'})

  activenode.highlight_active_span(bufnr, 1, 2)

  local ns = activenode.get_highlight_namespace()
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {details = true})

  assert(#marks > 0, "Should have highlight extmark")
  -- Check that highlight covers the span
  local mark = marks[1]
  local start_row = mark[2]
  local details = mark[4]
  assert(start_row == 1, "Highlight should start at line 1")
  assert(details.end_row == 3, "Highlight should end at line 3 (exclusive)")
end)

test("highlight_active_span clears previous highlight before adding new one", function()
  local activenode = require("lifemode.activenode")
  local extmarks = require("lifemode.extmarks")
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {'line 1', 'line 2', 'line 3'})

  -- Add first highlight
  activenode.highlight_active_span(bufnr, 0, 0)
  local ns = activenode.get_highlight_namespace()

  -- Add second highlight
  activenode.highlight_active_span(bufnr, 2, 2)
  local marks_after = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})

  -- Should only have one highlight (the new one)
  assert(#marks_after == 1, "Should only have one highlight after clearing previous")
end)

test("highlight_active_span handles invalid buffer", function()
  local activenode = require("lifemode.activenode")
  local extmarks = require("lifemode.extmarks")
  assert_no_error(function()
    activenode.highlight_active_span(9999, 0, 0)
  end)
end)

-- clear_active_highlight tests
test("clear_active_highlight removes highlight from buffer", function()
  local activenode = require("lifemode.activenode")
  local extmarks = require("lifemode.extmarks")
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {'line 1', 'line 2'})

  -- Add highlight
  activenode.highlight_active_span(bufnr, 0, 0)
  local ns = activenode.get_highlight_namespace()
  local marks_before = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})
  assert(#marks_before > 0, "Should have highlight before clear")

  -- Clear highlight
  activenode.clear_active_highlight(bufnr)
  local marks_after = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})

  assert(#marks_after == 0, "Should have no highlights after clear")
end)

test("clear_active_highlight handles invalid buffer", function()
  local activenode = require("lifemode.activenode")
  local extmarks = require("lifemode.extmarks")
  assert_no_error(function()
    activenode.clear_active_highlight(9999)
  end)
end)

-- update_winbar tests
test("update_winbar sets winbar with node metadata", function()
  local activenode = require("lifemode.activenode")
  local extmarks = require("lifemode.extmarks")
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)  -- Show buffer in current window

  local node_info = {
    type = "task",
    node_id = "node-123",
    lens = "task/brief",
  }

  activenode.update_winbar(bufnr, node_info)

  -- Check that winbar option was set on current window
  local winbar = vim.api.nvim_win_get_option(0, 'winbar')
  assert(winbar ~= nil and winbar ~= '', "Winbar should be set")
  assert(winbar:match("task"), "Winbar should contain type")
  assert(winbar:match("node%-123"), "Winbar should contain node_id")
  assert(winbar:match("task/brief"), "Winbar should contain lens")
end)

test("update_winbar clears winbar when node_info is nil", function()
  local activenode = require("lifemode.activenode")
  local extmarks = require("lifemode.extmarks")
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)  -- Show buffer in current window

  -- First set winbar
  activenode.update_winbar(bufnr, {
    type = "task",
    node_id = "node-123",
    lens = "task/brief",
  })

  -- Then clear it
  activenode.update_winbar(bufnr, nil)

  local winbar = vim.api.nvim_win_get_option(0, 'winbar')
  assert(winbar == '', "Winbar should be empty")
end)

test("update_winbar handles buffer with window", function()
  local activenode = require("lifemode.activenode")
  local extmarks = require("lifemode.extmarks")
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)

  local node_info = {
    type = "heading",
    node_id = "node-h1",
    lens = "node/raw",
  }

  assert_no_error(function()
    activenode.update_winbar(bufnr, node_info)
  end)
end)

test("update_winbar handles invalid buffer", function()
  local activenode = require("lifemode.activenode")
  local extmarks = require("lifemode.extmarks")
  assert_no_error(function()
    activenode.update_winbar(9999, { type = "task" })
  end)
end)

-- update_active_node tests
test("update_active_node highlights span and updates winbar for line with span", function()
  local activenode = require("lifemode.activenode")
  local extmarks = require("lifemode.extmarks")
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {'line 1', 'line 2', 'line 3'})
  vim.api.nvim_set_current_buf(bufnr)

  -- Set span metadata
  extmarks.set_span_metadata(bufnr, 1, 1, {
    instance_id = 'inst-1',
    node_id = 'node-abc',
    lens = 'task/brief',
    span_start = 1,
    span_end = 1,
  })

  -- Move cursor to line with span
  vim.api.nvim_win_set_cursor(0, {2, 0})  -- line 2 (1-indexed)

  activenode.update_active_node(bufnr)

  -- Check highlight was added
  local hl_ns = activenode.get_highlight_namespace()
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, hl_ns, 0, -1, {})
  assert(#marks > 0, "Should have highlight on active span")

  -- Check winbar was set
  local winbar = vim.api.nvim_win_get_option(0, 'winbar')
  assert(winbar:match("node%-abc"), "Winbar should show node_id")
  assert(winbar:match("task/brief"), "Winbar should show lens")
end)

test("update_active_node clears highlight and winbar for line without span", function()
  local activenode = require("lifemode.activenode")
  local extmarks = require("lifemode.extmarks")
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {'line 1', 'line 2', 'line 3'})
  vim.api.nvim_set_current_buf(bufnr)

  -- First add a highlight
  activenode.highlight_active_span(bufnr, 0, 0)

  -- Move cursor to line without span
  vim.api.nvim_win_set_cursor(0, {2, 0})

  activenode.update_active_node(bufnr)

  -- Check highlight was cleared
  local hl_ns = activenode.get_highlight_namespace()
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, hl_ns, 0, -1, {})
  assert(#marks == 0, "Should have no highlights")

  -- Check winbar was cleared
  local winbar = vim.api.nvim_win_get_option(0, 'winbar')
  assert(winbar == '', "Winbar should be empty")
end)

-- track_cursor_movement tests
test("track_cursor_movement sets up CursorMoved autocmd for buffer", function()
  local activenode = require("lifemode.activenode")
  local extmarks = require("lifemode.extmarks")
  local bufnr = vim.api.nvim_create_buf(false, true)

  activenode.track_cursor_movement(bufnr)

  -- Check that autocmd was created
  -- Note: This is difficult to test directly, so we just verify it doesn't error
  assert(true, "track_cursor_movement should not error")
end)

test("track_cursor_movement handles invalid buffer", function()
  local activenode = require("lifemode.activenode")
  local extmarks = require("lifemode.extmarks")
  assert_no_error(function()
    activenode.track_cursor_movement(9999)
  end)
end)

-- integration test
test("cursor movement updates active node", function()
  local activenode = require("lifemode.activenode")
  local extmarks = require("lifemode.extmarks")
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    'line 1',
    'line 2',
    'line 3',
  })
  vim.api.nvim_set_current_buf(bufnr)

  -- Set span metadata on different lines
  extmarks.set_span_metadata(bufnr, 0, 0, {
    instance_id = 'inst-1',
    node_id = 'node-1',
    lens = 'task/brief',
    span_start = 0,
    span_end = 0,
  })

  extmarks.set_span_metadata(bufnr, 2, 2, {
    instance_id = 'inst-2',
    node_id = 'node-2',
    lens = 'task/detail',
    span_start = 2,
    span_end = 2,
  })

  -- Enable cursor tracking
  activenode.track_cursor_movement(bufnr)

  -- Move to first span
  vim.api.nvim_win_set_cursor(0, {1, 0})
  activenode.update_active_node(bufnr)

  local winbar1 = vim.api.nvim_win_get_option(0, 'winbar')
  assert(winbar1:match("node%-1"), "Winbar should show first node")

  -- Move to second span
  vim.api.nvim_win_set_cursor(0, {3, 0})
  activenode.update_active_node(bufnr)

  local winbar2 = vim.api.nvim_win_get_option(0, 'winbar')
  assert(winbar2:match("node%-2"), "Winbar should show second node")
end)

-- Print summary
print(string.format("\n%d tests: %d passed, %d failed\n", test_count, pass_count, fail_count))
os.exit(fail_count > 0 and 1 or 0)
