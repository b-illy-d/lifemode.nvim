-- Test script for inclusion/transclusion feature
-- Usage: nvim -l test_inclusion.lua

-- Add lifemode to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Load lifemode
local lifemode = require('lifemode')

-- Setup with test vault
lifemode.setup({
  vault_root = vim.fn.getcwd(),
  leader = '<Space>',
})

print("=== Inclusion/Transclusion Test ===\n")

-- Create test files
print("Creating test files...")

-- File 1: Contains a task that will be included
local file1_content = [[# Source File

- [ ] Important task !1 #urgent ^task-abc123

Some context for this task.
]]

vim.fn.writefile(vim.split(file1_content, '\n'), 'test_source.md')

-- File 2: Contains an inclusion of the task from file1
local file2_lines = {
  "# Main File",
  "",
  "Here is the included task:",
  "",
  "![[task-abc123]]",
  "",
  "And some more text after the inclusion.",
}

vim.fn.writefile(file2_lines, 'test_main.md')

print("✓ Test files created")

-- Build vault index
print("\nBuilding vault index...")
local index = require('lifemode.index')
local vault_index = index.build_vault_index(vim.fn.getcwd())

-- Store index in config
local config = lifemode.get_config()
config.vault_index = vault_index

local node_count = 0
for _ in pairs(vault_index.node_locations) do
  node_count = node_count + 1
end

print("✓ Index built: " .. node_count .. " nodes")

-- Test 1: Verify inclusion parsing
print("\n=== Test 1: Inclusion Parsing ===")
vim.cmd('edit test_main.md')
local main_bufnr = vim.api.nvim_get_current_buf()

local node = require('lifemode.node')
local result = node.build_nodes_from_buffer(main_bufnr)

-- Find node with inclusion
local inclusion_found = false
for node_id, node_data in pairs(result.nodes_by_id) do
  if node_data.refs then
    for _, ref in ipairs(node_data.refs) do
      if ref.type == "inclusion" then
        inclusion_found = true
        print("✓ Inclusion found: " .. ref.target)
        break
      end
    end
  end
  if inclusion_found then break end
end

if not inclusion_found then
  print("✗ FAIL: No inclusion found in parsed nodes")
  os.exit(1)
end

-- Test 2: Verify rendering with inclusions
print("\n=== Test 2: Rendering with Inclusions ===")
vim.cmd('edit test_source.md')
local source_bufnr = vim.api.nvim_get_current_buf()

vim.cmd('edit test_main.md')
main_bufnr = vim.api.nvim_get_current_buf()

-- Debug: Show node tree
local node_result = node.build_nodes_from_buffer(main_bufnr)
print("\nNode tree for test_main.md:")
print("  Root nodes: " .. #node_result.root_ids)
for _, root_id in ipairs(node_result.root_ids) do
  local root_node = node_result.nodes_by_id[root_id]
  print("  - " .. root_id .. " (" .. root_node.type .. "): " .. root_node.body_md:sub(1, 40))
  print("    Children: " .. #root_node.children)
  for _, child_id in ipairs(root_node.children) do
    local child_node = node_result.nodes_by_id[child_id]
    print("      - " .. child_id .. " (" .. child_node.type .. "): " .. child_node.body_md:sub(1, 40))
    if child_node.refs then
      for _, ref in ipairs(child_node.refs) do
        print("        ref: " .. ref.type .. " -> " .. ref.target)
      end
    end
  end
end

local render = require('lifemode.render')
local view_bufnr = render.render_page_view(main_bufnr)

-- Check view buffer content
local view_lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)

print("View buffer content:")
for i, line in ipairs(view_lines) do
  print("  " .. i .. ": " .. line)
end

-- Check for inclusion marker
local has_inclusion_marker = false
local has_included_content = false

for _, line in ipairs(view_lines) do
  if line:match("↳ included:") then
    has_inclusion_marker = true
  end
  if line:match("Important task") then
    has_included_content = true
  end
end

if has_inclusion_marker then
  print("\n✓ Inclusion marker found")
else
  print("\n✗ FAIL: Inclusion marker not found")
  os.exit(1)
end

if has_included_content then
  print("✓ Included content rendered")
else
  print("✗ FAIL: Included content not rendered")
  os.exit(1)
end

-- Test 3: Verify node picker
print("\n=== Test 3: Node Picker ===")
local inclusion = require('lifemode.inclusion')

-- We can't test the interactive picker in headless mode,
-- but we can verify the module loads
print("✓ Inclusion module loaded")

print("\n=== All Tests Passed ===")
print("\nManual test:")
print("1. Open test_main.md in Neovim")
print("2. Run :LifeModePageView")
print("3. Verify the included task is displayed")
print("4. Press <Space>mi to test the picker")
