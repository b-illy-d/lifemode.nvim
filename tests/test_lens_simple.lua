-- Simple test for lens cycling fix
-- Usage: nvim -l test_lens_simple.lua

-- Add lifemode to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Load lifemode
local lifemode = require('lifemode')

-- Setup with test vault
lifemode.setup({
  vault_root = vim.fn.getcwd(),
  leader = '<Space>',
})

-- Open test file
vim.cmd('edit test_lens_pageview.md')
local source_bufnr = vim.api.nvim_get_current_buf()

-- Render page view
local render = require('lifemode.render')
local view_bufnr = render.render_page_view(source_bufnr)
vim.api.nvim_set_current_buf(view_bufnr)

-- Enable active node tracking
local activenode = require('lifemode.activenode')
activenode.track_cursor_movement(view_bufnr)

print("=== Lens Cycling Test ===\n")

-- Get first span
local extmarks = require('lifemode.extmarks')
local span = extmarks.get_span_at_line(view_bufnr, 0)

if not span then
  print("✗ FAIL: No span found at line 1")
  os.exit(1)
end

print("Initial state:")
print("  Lens: " .. (span.lens or "nil"))
print("  Node ID: " .. (span.node_id or "nil"))

-- Cycle to next lens
print("\nCycling to next lens...")
render.cycle_lens_at_cursor(view_bufnr, 0, 1)

local span2 = extmarks.get_span_at_line(view_bufnr, 0)
if not span2 then
  print("✗ FAIL: Span disappeared after cycling")
  os.exit(1)
end

print("  New lens: " .. (span2.lens or "nil"))

if span2.lens == span.lens then
  print("✗ FAIL: Lens did not change")
  os.exit(1)
end

-- Cycle again
print("\nCycling to next lens again...")
render.cycle_lens_at_cursor(view_bufnr, 0, 1)

local span3 = extmarks.get_span_at_line(view_bufnr, 0)
print("  New lens: " .. (span3.lens or "nil"))

-- Cycle backwards
print("\nCycling to previous lens...")
render.cycle_lens_at_cursor(view_bufnr, 0, -1)

local span4 = extmarks.get_span_at_line(view_bufnr, 0)
print("  New lens: " .. (span4.lens or "nil"))

if span4.lens ~= span3.lens then
  print("\n✓ PASS: Lens cycling works correctly")
  print("  Forward cycling: ✓")
  print("  Backward cycling: ✓")
  print("  Span metadata updates: ✓")
else
  print("\n✗ FAIL: Backward cycling didn't work")
  os.exit(1)
end

-- Test with custom leader
print("\n=== Custom Leader Test ===\n")
lifemode._reset_for_testing()
lifemode.setup({
  vault_root = vim.fn.getcwd(),
  leader = '<leader>l',
})

local view_bufnr2 = render.render_page_view(source_bufnr)
local config = lifemode.get_config()
print("Configured leader: '" .. config.leader .. "'")

if config.leader == '<leader>l' then
  print("✓ PASS: Custom leader configuration works")
else
  print("✗ FAIL: Custom leader not applied")
  os.exit(1)
end

print("\n=== All Tests Passed ===")
