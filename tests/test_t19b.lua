-- Test script for T19b: Auto-task creation with detail files
-- Usage: nvim -l test_t19b.lua

-- Add lifemode to package path
package.path = package.path .. ';./lua/?.lua;./lua/?/init.lua'

-- Load lifemode
local lifemode = require('lifemode')

-- Setup with test vault
lifemode.setup({
  vault_root = vim.fn.getcwd(),
  leader = '<Space>',
})

print("=== T19b: Auto-Task Creation Test ===\n")

-- Test 1: Auto-UUID insertion (simulated)
print("=== Test 1: Auto-UUID Insertion ===")

-- Create a test file
local test_content = {
  "# My Tasks",
  "",
  "- [ ] Task without ID",
  "- [ ] Another task without ID",
}

vim.fn.writefile(test_content, 'test_autoid.md')
vim.cmd('edit test_autoid.md')
local bufnr = vim.api.nvim_get_current_buf()

-- Manually trigger ID insertion logic
local blocks = require('lifemode.blocks')
local ids_added = blocks.ensure_ids_in_buffer(bufnr)

print("IDs added: " .. ids_added)

-- Save the buffer so the index can see the changes
vim.cmd('write')

-- Check that IDs were added
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
local has_id = false
for _, line in ipairs(lines) do
  if line:match("%^[%w%-]+") then
    has_id = true
    print("✓ Found line with ID: " .. line:sub(1, 60))
  end
end

if has_id then
  print("✓ Auto-ID functionality works")
else
  print("✗ FAIL: No IDs found")
  os.exit(1)
end

-- Test 2: Task detail file creation
print("\n=== Test 2: Task Detail File ===")

-- Position cursor on first task
vim.api.nvim_win_set_cursor(0, {3, 0})

-- Get task at cursor
local tasks = require('lifemode.tasks')
local task_id, task_bufnr = tasks.get_task_at_cursor()

if task_id then
  print("✓ Task found at cursor: " .. task_id)

  -- Create detail file
  tasks.edit_task_details()

  -- Check if detail file was created
  local detail_file = vim.fn.getcwd() .. '/tasks/task-' .. task_id .. '.md'
  if vim.fn.filereadable(detail_file) == 1 then
    print("✓ Detail file created: " .. detail_file)

    -- Read detail file content
    local detail_lines = vim.fn.readfile(detail_file)
    print("Detail file preview:")
    for i = 1, math.min(5, #detail_lines) do
      print("  " .. detail_lines[i])
    end
  else
    print("✗ FAIL: Detail file not created")
    os.exit(1)
  end
else
  print("✗ FAIL: No task found at cursor")
  os.exit(1)
end

-- Test 3: Inclusion rendering shows only summary
print("\n=== Test 3: Inclusion Shows Summary Only ===")

-- Create a file with inclusion of the task
local main_file_content = {
  "# Main Tasks",
  "",
  "Include the task:",
  "",
  "![[" .. task_id .. "]]",
}

vim.fn.writefile(main_file_content, 'test_main_t19b.md')

-- Build index
local index = require('lifemode.index')
local vault_index = index.build_vault_index(vim.fn.getcwd())
local config = lifemode.get_config()
config.vault_index = vault_index

-- Render PageView
vim.cmd('edit test_main_t19b.md')
local main_bufnr = vim.api.nvim_get_current_buf()
local render = require('lifemode.render')
local view_bufnr = render.render_page_view(main_bufnr)

-- Check rendered content
local view_lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)

print("PageView content:")
for i, line in ipairs(view_lines) do
  print("  " .. i .. ": " .. line)
end

-- Verify that only summary is shown, not detail file content
local has_summary = false
local has_detail_file_content = false

for _, line in ipairs(view_lines) do
  if line:match("Task without ID") then
    has_summary = true
  end
  if line:match("Task Details:") or line:match("Dependencies") then
    has_detail_file_content = true
  end
end

if has_summary then
  print("\n✓ Task summary is shown")
else
  print("\n✗ FAIL: Task summary not shown")
  os.exit(1)
end

if not has_detail_file_content then
  print("✓ Detail file content is NOT included (correct)")
else
  print("✗ FAIL: Detail file content incorrectly included")
  os.exit(1)
end

print("\n=== All T19b Tests Passed ===")
print("\nManual verification:")
print("1. Open test_autoid.md and verify tasks have UUIDs")
print("2. Position cursor on a task and press <Space>te")
print("3. Verify detail file opens in tasks/ directory")
print("4. Add content to detail file")
print("5. Include the task elsewhere with ![[task-id]]")
print("6. Verify only summary line is shown, not detail file content")
