-- Test script for lens cycling fix
-- Usage: nvim -l test_lens_fix.lua

-- Add lifemode to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Load lifemode
local lifemode = require('lifemode')

-- Setup with test vault
lifemode.setup({
  vault_root = vim.fn.getcwd(),
  leader = '<Space>',
})

print("✓ LifeMode configured")

-- Open test file
vim.cmd('edit test_lens_pageview.md')
local source_bufnr = vim.api.nvim_get_current_buf()
print("✓ Test file opened: buffer " .. source_bufnr)

-- Render page view
local render = require('lifemode.render')
local view_bufnr = render.render_page_view(source_bufnr)
print("✓ PageView rendered: buffer " .. view_bufnr)

-- Switch to view buffer
vim.api.nvim_set_current_buf(view_bufnr)

-- Enable active node tracking
local activenode = require('lifemode.activenode')
activenode.track_cursor_movement(view_bufnr)
print("✓ Active node tracking enabled")

-- Check that keymaps are set up
local keymaps = vim.api.nvim_buf_get_keymap(view_bufnr, 'n')
local has_expand = false
local has_collapse = false
local has_lens_next = false
local has_lens_prev = false

for _, map in ipairs(keymaps) do
  if map.lhs == '<Space>e' then
    has_expand = true
  elseif map.lhs == '<Space>E' then
    has_collapse = true
  elseif map.lhs == '<Space>ml' then
    has_lens_next = true
  elseif map.lhs == '<Space>mL' then
    has_lens_prev = true
  end
end

print("\n=== Keymap Status ===")
print("  <Space>e (expand):     " .. (has_expand and "✓" or "✗"))
print("  <Space>E (collapse):   " .. (has_collapse and "✓" or "✗"))
print("  <Space>ml (next lens): " .. (has_lens_next and "✓" or "✗"))
print("  <Space>mL (prev lens): " .. (has_lens_prev and "✗" or "✓"))

-- Test lens cycling functionality
print("\n=== Testing Lens Cycling ===")

-- Get first line (should be a task)
vim.api.nvim_win_set_cursor(0, {1, 0})
local extmarks = require('lifemode.extmarks')
local span = extmarks.get_span_at_line(view_bufnr, 0)

if span then
  print("✓ Found span at line 1")
  print("  Instance ID: " .. (span.instance_id or "nil"))
  print("  Node ID: " .. (span.node_id or "nil"))
  print("  Current lens: " .. (span.lens or "nil"))

  -- Test cycling to next lens
  local initial_lens = span.lens
  render.cycle_lens_at_cursor(view_bufnr, 0, 1)

  -- Check if lens changed
  local new_span = extmarks.get_span_at_line(view_bufnr, 0)
  if new_span then
    print("✓ Lens cycled")
    print("  New lens: " .. (new_span.lens or "nil"))

    if new_span.lens ~= initial_lens then
      print("✓ Lens changed successfully: " .. initial_lens .. " -> " .. new_span.lens)
    else
      print("✗ Lens did not change")
    end
  else
    print("✗ Could not find span after cycling")
  end
else
  print("✗ No span found at line 1")
end

-- Test with different leader key
print("\n=== Testing Custom Leader ===")
lifemode._reset_for_testing()
lifemode.setup({
  vault_root = vim.fn.getcwd(),
  leader = '<leader>m',
})

local view_bufnr2 = render.render_page_view(source_bufnr)
vim.api.nvim_set_current_buf(view_bufnr2)
activenode.track_cursor_movement(view_bufnr2)

local keymaps2 = vim.api.nvim_buf_get_keymap(view_bufnr2, 'n')
local has_custom_lens = false

for _, map in ipairs(keymaps2) do
  if map.lhs == '<leader>mml' then
    has_custom_lens = true
    break
  end
end

print("  Custom leader keymap (<leader>mml): " .. (has_custom_lens and "✓" or "✗"))

print("\n=== Test Summary ===")
if has_expand and has_collapse and has_lens_next and has_lens_prev then
  print("✓ All tests passed!")
else
  print("✗ Some tests failed")
  os.exit(1)
end
