#!/usr/bin/env -S nvim -l

-- Manual Acceptance Test for T12: Active node highlighting + winbar info
--
-- This test script verifies:
-- 1. Active node span is highlighted when cursor is on it
-- 2. Winbar shows node metadata (type, ID, lens)
-- 3. Cursor movement updates active node
-- 4. Highlight clears when cursor leaves span

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

-- Load plugin
local lifemode = require('lifemode')
lifemode.setup({ vault_root = '/tmp/lifemode_test' })

local view = require('lifemode.view')
local extmarks = require('lifemode.extmarks')
local activenode = require('lifemode.activenode')

print("=== T12: Active Node Highlighting + Winbar Manual Test ===\n")

-- Test 1: Create view buffer with spans
print("Test 1: Creating view buffer with test spans...")
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '# Heading 1',
  '',
  '- [ ] Task 1: First task !2 ^task-001',
  '- [ ] Task 2: Second task !1 ^task-002',
  '- [x] Task 3: Done task ^task-003',
  '',
  'Some text without a span',
})

-- Set span metadata for different blocks
extmarks.set_span_metadata(bufnr, 0, 0, {
  instance_id = 'inst-h1',
  node_id = 'heading-1',
  lens = 'node/raw',
  span_start = 0,
  span_end = 0,
})

extmarks.set_span_metadata(bufnr, 2, 2, {
  instance_id = 'inst-task-1',
  node_id = 'task-001',
  lens = 'task/brief',
  span_start = 2,
  span_end = 2,
})

extmarks.set_span_metadata(bufnr, 3, 3, {
  instance_id = 'inst-task-2',
  node_id = 'task-002',
  lens = 'task/detail',
  span_start = 3,
  span_end = 3,
})

extmarks.set_span_metadata(bufnr, 4, 4, {
  instance_id = 'inst-task-3',
  node_id = 'task-003',
  lens = 'task/brief',
  span_start = 4,
  span_end = 4,
})

vim.api.nvim_set_current_buf(bufnr)
print("✓ Buffer created with spans")

-- Test 2: Enable active node tracking
print("\nTest 2: Enabling active node tracking...")
activenode.track_cursor_movement(bufnr)
print("✓ Active node tracking enabled")

-- Test 3: Check highlight on first line (heading)
print("\nTest 3: Moving cursor to heading line...")
vim.api.nvim_win_set_cursor(0, {1, 0})
vim.cmd('redraw')

-- Trigger update manually
activenode.update_active_node(bufnr)

local hl_ns = activenode.get_highlight_namespace()
local marks = vim.api.nvim_buf_get_extmarks(bufnr, hl_ns, 0, -1, {})
assert(#marks > 0, "Should have highlight on heading")
print("✓ Heading highlighted")

local winbar = vim.api.nvim_win_get_option(0, 'winbar')
assert(winbar:match("heading"), "Winbar should show heading node")
print("✓ Winbar shows: " .. winbar)

-- Test 4: Move to task line
print("\nTest 4: Moving cursor to task line...")
vim.api.nvim_win_set_cursor(0, {3, 0})
vim.cmd('redraw')

activenode.update_active_node(bufnr)

marks = vim.api.nvim_buf_get_extmarks(bufnr, hl_ns, 0, -1, {})
assert(#marks > 0, "Should have highlight on task")
print("✓ Task highlighted")

winbar = vim.api.nvim_win_get_option(0, 'winbar')
assert(winbar:match("task%-001"), "Winbar should show task-001")
assert(winbar:match("task/brief"), "Winbar should show lens")
print("✓ Winbar shows: " .. winbar)

-- Test 5: Move to another task
print("\nTest 5: Moving cursor to second task...")
vim.api.nvim_win_set_cursor(0, {4, 0})
vim.cmd('redraw')

activenode.update_active_node(bufnr)

marks = vim.api.nvim_buf_get_extmarks(bufnr, hl_ns, 0, -1, {})
assert(#marks > 0, "Should have highlight on second task")
print("✓ Second task highlighted")

winbar = vim.api.nvim_win_get_option(0, 'winbar')
assert(winbar:match("task%-002"), "Winbar should show task-002")
assert(winbar:match("task/detail"), "Winbar should show detail lens")
print("✓ Winbar shows: " .. winbar)

-- Test 6: Move to line without span
print("\nTest 6: Moving cursor to line without span...")
vim.api.nvim_win_set_cursor(0, {7, 0})
vim.cmd('redraw')

activenode.update_active_node(bufnr)

marks = vim.api.nvim_buf_get_extmarks(bufnr, hl_ns, 0, -1, {})
assert(#marks == 0, "Should have no highlight on non-span line")
print("✓ No highlight on non-span line")

winbar = vim.api.nvim_win_get_option(0, 'winbar')
assert(winbar == '', "Winbar should be empty")
print("✓ Winbar cleared")

-- Test 7: Test multi-line span
print("\nTest 7: Testing multi-line span...")
extmarks.set_span_metadata(bufnr, 2, 4, {
  instance_id = 'inst-multi',
  node_id = 'multi-span',
  lens = 'node/raw',
  span_start = 2,
  span_end = 4,
})

vim.api.nvim_win_set_cursor(0, {4, 0})  -- Line in middle of span
vim.cmd('redraw')

activenode.update_active_node(bufnr)

marks = vim.api.nvim_buf_get_extmarks(bufnr, hl_ns, 0, -1, {details = true})
assert(#marks > 0, "Should have highlight on multi-line span")

-- Check that highlight covers multiple lines
local mark = marks[1]
local details = mark[4]
assert(details.end_row == 5, "Highlight should cover lines 2-4 (end_row=5 exclusive)")
print("✓ Multi-line span highlighted correctly")

winbar = vim.api.nvim_win_get_option(0, 'winbar')
assert(winbar:match("multi%-span"), "Winbar should show multi-span")
print("✓ Winbar shows: " .. winbar)

-- Test 8: Test highlight group exists
print("\nTest 8: Checking highlight group...")
local hl = vim.api.nvim_get_hl(0, { name = 'LifeModeActiveNode' })
assert(hl ~= nil and next(hl) ~= nil, "LifeModeActiveNode highlight group should be defined")
print("✓ LifeModeActiveNode highlight group defined")

-- Test 9: Test autocmd is set up
print("\nTest 9: Checking autocmd setup...")
local autocmds = vim.api.nvim_get_autocmds({
  group = 'LifeModeActiveNode_' .. bufnr,
  buffer = bufnr,
})
assert(#autocmds > 0, "Should have autocmd for cursor movement")
print("✓ CursorMoved autocmd registered")

-- Test 10: Integration with view.create_buffer
print("\nTest 10: Testing integration with view.create_buffer...")
local view_bufnr = view.create_buffer()
assert(vim.api.nvim_buf_is_valid(view_bufnr), "View buffer should be valid")

-- Check that autocmd was set up
autocmds = vim.api.nvim_get_autocmds({
  group = 'LifeModeActiveNode_' .. view_bufnr,
  buffer = view_bufnr,
})
assert(#autocmds > 0, "View buffer should have active node tracking")
print("✓ view.create_buffer() enables active node tracking")

print("\n=== All Tests Passed ===")
print("\nAcceptance Criteria:")
print("✓ Active node span is visually distinct (highlighted)")
print("✓ Winbar shows type, node_id, and lens")
print("✓ Cursor movement updates active node")
print("✓ Multi-line spans are highlighted correctly")
print("✓ Non-span lines clear highlight and winbar")
print("✓ Integration with view buffer works")

os.exit(0)
