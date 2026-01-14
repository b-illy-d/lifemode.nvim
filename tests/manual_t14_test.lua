-- Manual acceptance test for T14: Expand/collapse one level (children)

-- Add project lua directory to path
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

-- Initialize lifemode
local lifemode = require('lifemode')
lifemode.setup({
  vault_root = '/tmp/test_vault',
  leader = '<Space>',
})

local render = require('lifemode.render')
local extmarks = require('lifemode.extmarks')

print("=== T14: Expand/Collapse Acceptance Test ===\n")

-- Test 1: Create source buffer with nested structure
print("Test 1: Create source buffer with nested tasks")
local source_bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(source_bufnr, 0, -1, false, {
  '- [ ] Parent Task 1 ^parent-1',
  '  - [ ] Child 1.1 ^child-1-1',
  '  - [ ] Child 1.2 ^child-1-2',
  '- [ ] Parent Task 2 ^parent-2',
  '  - [ ] Child 2.1 ^child-2-1',
  '  - [ ] Child 2.2 ^child-2-2',
  '    - [ ] Grandchild 2.2.1 ^grandchild-2-2-1',
  '- [ ] Leaf Task 3 ^leaf-3',
})
print("✓ Source buffer created with 8 tasks (3 roots, 4 children, 1 grandchild)")

-- Test 2: Render page view (should show only roots)
print("\nTest 2: Render page view (roots only)")
local view_bufnr = render.render_page_view(source_bufnr)
local initial_lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
print(string.format("✓ View rendered with %d lines (3 roots expected)", #initial_lines))
for i, line in ipairs(initial_lines) do
  print(string.format("  Line %d: %s", i, line))
end

-- Test 3: Find Parent Task 1 and check it's not expanded
print("\nTest 3: Check Parent Task 1 expansion state")
local parent1_line = nil
for i, line in ipairs(initial_lines) do
  if line:match("Parent Task 1") then
    parent1_line = i - 1
    break
  end
end

if not parent1_line then
  print("✗ FAIL: Parent Task 1 not found in view")
  os.exit(1)
end

local span = extmarks.get_span_at_line(view_bufnr, parent1_line)
if not span then
  print("✗ FAIL: No span at Parent Task 1 line")
  os.exit(1)
end

local is_expanded_before = render.is_expanded(view_bufnr, span.instance_id)
if is_expanded_before then
  print("✗ FAIL: Parent Task 1 should not be expanded initially")
  os.exit(1)
end
print("✓ Parent Task 1 is not expanded initially")

-- Test 4: Expand Parent Task 1
print("\nTest 4: Expand Parent Task 1")
render.expand_instance(view_bufnr, parent1_line)
local expanded_lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
print(string.format("✓ View now has %d lines (should be 5: 3 roots + 2 children)", #expanded_lines))
for i, line in ipairs(expanded_lines) do
  print(string.format("  Line %d: %s", i, line))
end

-- Verify children are visible
local has_child_11 = false
local has_child_12 = false
for _, line in ipairs(expanded_lines) do
  if line:match("Child 1%.1") then has_child_11 = true end
  if line:match("Child 1%.2") then has_child_12 = true end
end

if not (has_child_11 and has_child_12) then
  print("✗ FAIL: Children of Parent Task 1 not visible after expand")
  os.exit(1)
end
print("✓ Children 1.1 and 1.2 are now visible")

-- Test 5: Check expansion state
print("\nTest 5: Check expansion state after expand")
local is_expanded_after = render.is_expanded(view_bufnr, span.instance_id)
if not is_expanded_after then
  print("✗ FAIL: Parent Task 1 should be expanded after expand_instance")
  os.exit(1)
end
print("✓ Parent Task 1 is marked as expanded")

-- Test 6: Try to expand again (should be idempotent)
print("\nTest 6: Repeated expand should be idempotent")
render.expand_instance(view_bufnr, parent1_line)
local second_expand_lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
if #second_expand_lines ~= #expanded_lines then
  print(string.format("✗ FAIL: Line count changed on repeated expand (%d -> %d)", #expanded_lines, #second_expand_lines))
  os.exit(1)
end
print("✓ Repeated expand did not duplicate children")

-- Test 7: Collapse Parent Task 1
print("\nTest 7: Collapse Parent Task 1")
render.collapse_instance(view_bufnr, parent1_line)
local collapsed_lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
print(string.format("✓ View now has %d lines (back to 3 roots)", #collapsed_lines))
for i, line in ipairs(collapsed_lines) do
  print(string.format("  Line %d: %s", i, line))
end

-- Verify children are gone
local has_child_after_collapse = false
for _, line in ipairs(collapsed_lines) do
  if line:match("Child") then
    has_child_after_collapse = true
    break
  end
end

if has_child_after_collapse then
  print("✗ FAIL: Children still visible after collapse")
  os.exit(1)
end
print("✓ Children are hidden after collapse")

-- Test 8: Check expansion state after collapse
print("\nTest 8: Check expansion state after collapse")
local is_expanded_after_collapse = render.is_expanded(view_bufnr, span.instance_id)
if is_expanded_after_collapse then
  print("✗ FAIL: Parent Task 1 should not be expanded after collapse")
  os.exit(1)
end
print("✓ Parent Task 1 is not expanded after collapse")

-- Test 9: Expand node without children
print("\nTest 9: Expand leaf task (no children)")
local leaf_line = nil
for i, line in ipairs(collapsed_lines) do
  if line:match("Leaf Task 3") then
    leaf_line = i - 1
    break
  end
end

if not leaf_line then
  print("✗ FAIL: Leaf Task 3 not found")
  os.exit(1)
end

local before_leaf_expand = #vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
render.expand_instance(view_bufnr, leaf_line)
local after_leaf_expand = #vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)

if after_leaf_expand ~= before_leaf_expand then
  print("✗ FAIL: Expanding leaf task should not change line count")
  os.exit(1)
end
print("✓ Expanding leaf task (no children) does nothing")

-- Test 10: Verify keymaps are registered
print("\nTest 10: Check keymaps <Space>e and <Space>E")
local keymaps = vim.api.nvim_buf_get_keymap(view_bufnr, 'n')
local has_expand_key = false
local has_collapse_key = false

for _, map in ipairs(keymaps) do
  if map.lhs == ' e' then has_expand_key = true end
  if map.lhs == ' E' then has_collapse_key = true end
end

if not has_expand_key then
  print("✗ FAIL: <Space>e keymap not registered")
  os.exit(1)
end

if not has_collapse_key then
  print("✗ FAIL: <Space>E keymap not registered")
  os.exit(1)
end
print("✓ Keymaps <Space>e and <Space>E are registered")

-- Test 11: Expand nested structure (Parent Task 2 has grandchildren)
print("\nTest 11: Expand Parent Task 2 (has nested children)")
-- Re-render to get fresh state
view_bufnr = render.render_page_view(source_bufnr)
local parent2_line = nil
local fresh_lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
for i, line in ipairs(fresh_lines) do
  if line:match("Parent Task 2") then
    parent2_line = i - 1
    break
  end
end

if not parent2_line then
  print("✗ FAIL: Parent Task 2 not found")
  os.exit(1)
end

render.expand_instance(view_bufnr, parent2_line)
local parent2_expanded = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)

-- Should see children but NOT grandchildren (only one level)
local has_child_21 = false
local has_child_22 = false
local has_grandchild = false

for _, line in ipairs(parent2_expanded) do
  if line:match("Child 2%.1") then has_child_21 = true end
  if line:match("Child 2%.2") then has_child_22 = true end
  if line:match("Grandchild") then has_grandchild = true end
end

if not (has_child_21 and has_child_22) then
  print("✗ FAIL: Children of Parent Task 2 should be visible")
  os.exit(1)
end

if has_grandchild then
  print("✗ FAIL: Grandchild should NOT be visible (only one level expanded)")
  os.exit(1)
end
print("✓ Parent Task 2 expanded shows children but not grandchildren (one level only)")

print("\n=== All 11 Tests Passed ===")
print("T14: Expand/collapse one level (children) - COMPLETE")
