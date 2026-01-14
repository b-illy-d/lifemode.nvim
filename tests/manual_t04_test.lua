#!/usr/bin/env -S nvim -l

-- Manual acceptance test for T04: Ensure IDs for indexable blocks
-- Creates a buffer with tasks and verifies :LifeModeEnsureIDs command works

package.path = './lua/?.lua;' .. package.path
local lifemode = require('lifemode.init')

print("=== T04 Manual Acceptance Test ===\n")

-- Setup plugin
lifemode.setup({
  vault_root = '/tmp/test-vault',
})
print("✓ Plugin setup complete\n")

-- Create a test buffer with tasks
local bufnr = vim.api.nvim_create_buf(false, true)
local test_content = {
  "# Test Tasks",
  "",
  "- [ ] Task without ID",
  "- [x] Another task without ID",
  "- [ ] Task with existing ID ^abc-123",
  "",
  "Regular text",
  "",
  "- Regular list item",
  "- [ ] Third task without ID",
}

vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, test_content)
print("✓ Created test buffer with content:")
for i, line in ipairs(test_content) do
  print("  " .. i .. ": " .. line)
end
print()

-- Parse before ensuring IDs
local parser = require('lifemode.parser')
local blocks_before = parser.parse_buffer(bufnr)
local tasks_without_ids = 0
for _, block in ipairs(blocks_before) do
  if block.type == "task" and not block.id then
    tasks_without_ids = tasks_without_ids + 1
  end
end
print(string.format("✓ Parsed buffer: %d total blocks, %d tasks without IDs\n", #blocks_before, tasks_without_ids))

-- Ensure IDs
local blocks = require('lifemode.blocks')
local ids_added = blocks.ensure_ids_in_buffer(bufnr)
print(string.format("✓ Added %d IDs to tasks\n", ids_added))

-- Verify results
local lines_after = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
print("✓ Buffer content after ensure_ids_in_buffer():")
for i, line in ipairs(lines_after) do
  print("  " .. i .. ": " .. line)
end
print()

-- Parse again to verify all tasks have IDs
local blocks_after = parser.parse_buffer(bufnr)
local tasks_with_ids = 0
local tasks_total = 0
for _, block in ipairs(blocks_after) do
  if block.type == "task" then
    tasks_total = tasks_total + 1
    if block.id then
      tasks_with_ids = tasks_with_ids + 1
    end
  end
end

print(string.format("✓ Final state: %d/%d tasks have IDs\n", tasks_with_ids, tasks_total))

-- Acceptance criteria checks
local success = true

-- Check 1: All tasks should now have IDs
if tasks_with_ids ~= tasks_total then
  print("✗ FAIL: Not all tasks have IDs")
  success = false
else
  print("✓ PASS: All tasks have IDs")
end

-- Check 2: Number of IDs added should match tasks without IDs
if ids_added ~= tasks_without_ids then
  print(string.format("✗ FAIL: Expected %d IDs added but got %d", tasks_without_ids, ids_added))
  success = false
else
  print("✓ PASS: Correct number of IDs added")
end

-- Check 3: Content preserved (check task text)
if not lines_after[3]:match("Task without ID %^") then
  print("✗ FAIL: Task content not preserved on line 3")
  success = false
else
  print("✓ PASS: Task content preserved")
end

-- Check 4: Existing ID preserved
if not lines_after[5]:match("%^abc%-123$") then
  print("✗ FAIL: Existing ID not preserved on line 5")
  success = false
else
  print("✓ PASS: Existing ID preserved")
end

-- Check 5: Non-task lines unchanged
if lines_after[7] ~= "Regular text" then
  print("✗ FAIL: Non-task line was modified")
  success = false
else
  print("✓ PASS: Non-task lines unchanged")
end

-- Check 6: UUID format validation
local uuid_pattern = "^[%x%-]+$"
for _, block in ipairs(blocks_after) do
  if block.type == "task" and block.id and not block.id:match("abc%-123") then
    if not block.id:match(uuid_pattern) or #block.id ~= 36 then
      print("✗ FAIL: Invalid UUID format: " .. block.id)
      success = false
    end
  end
end
if success then
  print("✓ PASS: All new IDs are valid UUIDs")
end

-- Cleanup
vim.api.nvim_buf_delete(bufnr, { force = true })

-- Summary
print("\n=== Summary ===")
if success then
  print("✓ All acceptance criteria met")
  print("✓ T04 implementation complete")
  os.exit(0)
else
  print("✗ Some acceptance criteria failed")
  os.exit(1)
end
