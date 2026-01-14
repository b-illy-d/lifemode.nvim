-- Manual acceptance test for T15: Expansion budget + cycle stub
-- Run with: nvim -l tests/manual_t15_test.lua

-- Add project lua directory to path
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local lifemode = require('lifemode')
local render = require('lifemode.render')

print("=== T15: Expansion Budget + Cycle Stub Manual Tests ===\n")

-- Helper function to create test buffer
local function create_test_buffer(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

-- Helper to print buffer contents
local function print_buffer(bufnr, label)
  print(label .. ":")
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    print(string.format("  %d: %s", i, line))
  end
  print()
end

-- Test 1: Cycle detection
print("Test 1: Cycle detection shows stub")
print("-------------------------------------")
lifemode._reset_for_testing()
lifemode.setup({ vault_root = '/test' })

local source1 = create_test_buffer({
  '- Task A ^a',
  '  - Task B ^b',
})

local view1 = render.render_page_view(source1)
print_buffer(view1, "Initial view (only root A)")

-- Create cycle: B → A
render._node_cache[string.format("%d:b", view1)].children = {"a"}

-- Expand A (shows B)
render.expand_instance(view1, 0)
print_buffer(view1, "After expanding A (shows B)")

-- Expand B (should show cycle stub)
render.expand_instance(view1, 1)
print_buffer(view1, "After expanding B (should show cycle stub)")

local lines1 = vim.api.nvim_buf_get_lines(view1, 0, -1, false)
local found_stub1 = false
for _, line in ipairs(lines1) do
  if line:match('↩') or line:match('already shown') then
    found_stub1 = true
    break
  end
end
print(found_stub1 and "✓ Cycle stub found" or "✗ Cycle stub NOT found")
print()

-- Test 2: Max depth limit
print("Test 2: Max depth limit")
print("------------------------")
lifemode._reset_for_testing()
lifemode.setup({ vault_root = '/test', max_depth = 2 })

local source2 = create_test_buffer({
  '- Level 1 ^l1',
  '  - Level 2 ^l2',
  '    - Level 3 ^l3',
  '      - Level 4 ^l4',
})

local view2 = render.render_page_view(source2)
print_buffer(view2, "Initial view (root L1 only)")

-- Expand L1 (depth 1)
render.expand_instance(view2, 0)
print_buffer(view2, "After expanding L1 (shows L2, depth 1)")

-- Expand L2 (depth 2, at limit)
render.expand_instance(view2, 1)
print_buffer(view2, "After expanding L2 (shows L3, depth 2 - at limit)")

-- Try to expand L3 (depth 3, exceeds limit)
local lines_before = vim.api.nvim_buf_line_count(view2)
render.expand_instance(view2, 2)
local lines_after = vim.api.nvim_buf_line_count(view2)

print(string.format("Lines before: %d, after: %d", lines_before, lines_after))
print(lines_after == lines_before and "✓ Max depth prevented expansion" or "✗ Max depth did not prevent expansion")
print()

-- Test 3: Max nodes per action
print("Test 3: Max nodes per action limit")
print("------------------------------------")
lifemode._reset_for_testing()
lifemode.setup({ vault_root = '/test', max_nodes_per_action = 3 })

local source3 = create_test_buffer({
  '- Parent ^parent',
  '  - Child 1 ^c1',
  '  - Child 2 ^c2',
  '  - Child 3 ^c3',
  '  - Child 4 ^c4',
  '  - Child 5 ^c5',
})

local view3 = render.render_page_view(source3)
print_buffer(view3, "Initial view (root Parent only)")

-- Expand Parent (should show only first 3 children)
render.expand_instance(view3, 0)
print_buffer(view3, "After expanding Parent (should show only 3 children)")

local lines3 = vim.api.nvim_buf_get_lines(view3, 0, -1, false)
local child_count = 0
for _, line in ipairs(lines3) do
  if line:match('Child') then
    child_count = child_count + 1
  end
end
print(string.format("Children rendered: %d", child_count))
print(child_count <= 3 and "✓ Node count limit respected" or "✗ Node count limit NOT respected")
print()

-- Test 4: Deep cycle detection
print("Test 4: Deep cycle detection (A→B→C→A)")
print("----------------------------------------")
lifemode._reset_for_testing()
lifemode.setup({ vault_root = '/test' })

local source4 = create_test_buffer({
  '- Task A ^a',
  '  - Task B ^b',
  '    - Task C ^c',
})

local view4 = render.render_page_view(source4)
print_buffer(view4, "Initial view (root A only)")

-- Create cycle: C → A
render._node_cache[string.format("%d:c", view4)].children = {"a"}

-- Expand A (shows B)
render.expand_instance(view4, 0)
print_buffer(view4, "After expanding A (shows B)")

-- Expand B (shows C)
render.expand_instance(view4, 1)
print_buffer(view4, "After expanding B (shows C)")

-- Expand C (should show cycle stub for A)
render.expand_instance(view4, 2)
print_buffer(view4, "After expanding C (should show cycle stub)")

local lines4 = vim.api.nvim_buf_get_lines(view4, 0, -1, false)
local found_stub4 = false
for _, line in ipairs(lines4) do
  if line:match('↩') or line:match('already shown') then
    found_stub4 = true
    break
  end
end
print(found_stub4 and "✓ Deep cycle stub found" or "✗ Deep cycle stub NOT found")
print()

-- Test 5: Config validation
print("Test 5: Config validation")
print("--------------------------")
lifemode._reset_for_testing()

-- Test max_nodes_per_action validation
local ok1, err1 = pcall(function()
  lifemode.setup({ vault_root = '/test', max_nodes_per_action = 0 })
end)
print(not ok1 and "✓ Rejects max_nodes_per_action = 0" or "✗ Accepts invalid max_nodes_per_action")

local ok2, err2 = pcall(function()
  lifemode.setup({ vault_root = '/test', max_nodes_per_action = 'invalid' })
end)
print(not ok2 and "✓ Rejects non-number max_nodes_per_action" or "✗ Accepts invalid type")

lifemode._reset_for_testing()
local ok3 = pcall(function()
  lifemode.setup({ vault_root = '/test', max_nodes_per_action = 100 })
end)
print(ok3 and "✓ Accepts valid max_nodes_per_action = 100" or "✗ Rejects valid config")

print()

-- Test 6: Same node in different branches (not a cycle)
print("Test 6: Same node in different branches")
print("----------------------------------------")
lifemode._reset_for_testing()
lifemode.setup({ vault_root = '/test' })

local source6 = create_test_buffer({
  '- Root ^root',
  '  - Branch A ^a',
  '    - Shared ^shared',
  '  - Branch B ^b',
  '    - Shared ^shared',
})

local view6 = render.render_page_view(source6)
print_buffer(view6, "Initial view (root only)")

-- Expand Root (shows A and B)
render.expand_instance(view6, 0)
print_buffer(view6, "After expanding Root (shows A and B)")

-- Expand A (shows Shared)
render.expand_instance(view6, 1)
print_buffer(view6, "After expanding A (shows Shared under A)")

-- Expand B (should also show Shared - not a cycle!)
local lines_before6 = vim.api.nvim_buf_line_count(view6)
render.expand_instance(view6, 3)  -- B is at line 3
local lines_after6 = vim.api.nvim_buf_line_count(view6)

print_buffer(view6, "After expanding B (should show Shared under B)")
print(lines_after6 > lines_before6 and "✓ Same node allowed in different branches" or "✗ False positive cycle detection")
print()

print("=== All manual tests complete ===")
