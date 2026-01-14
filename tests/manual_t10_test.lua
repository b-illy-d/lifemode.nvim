#!/usr/bin/env -S nvim -l

-- Manual acceptance test for T10: Task priority bump

print("=== T10 Manual Acceptance Test ===\n")

-- Setup
package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
local lifemode = require('lifemode')
local tasks = require('lifemode.tasks')

lifemode.setup({ vault_root = '/tmp/test-vault' })

local test_count = 0
local pass_count = 0

local function test(name, fn)
  test_count = test_count + 1
  io.write(string.format("[%d] %s ... ", test_count, name))
  io.flush()

  local ok, err = pcall(fn)
  if ok then
    pass_count = pass_count + 1
    print("PASS")
  else
    print(string.format("FAIL: %s", err))
  end
end

local function assert_equals(expected, actual, msg)
  if expected ~= actual then
    error(msg or string.format("Expected %s but got %s", vim.inspect(expected), vim.inspect(actual)))
  end
end

-- Test 1: Priority extraction works
test("get_priority extracts from line", function()
  local line = "- [ ] Task !3 ^task-id"
  local priority = tasks.get_priority(line)
  assert_equals(3, priority, "Should extract priority 3")
end)

-- Test 2: Priority setting adds priority
test("set_priority adds priority", function()
  local line = "- [ ] Task ^task-id"
  local new_line = tasks.set_priority(line, 2)
  assert_equals("- [ ] Task !2 ^task-id", new_line, "Should add priority")
end)

-- Test 3: inc_priority increases priority
test("inc_priority increases priority in buffer", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task !4 ^task-123"
  })

  local result = tasks.inc_priority(bufnr, "task-123")
  assert_equals(true, result, "Should return true")

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  assert_equals("- [ ] Task !3 ^task-123", lines[1], "Should increment to !3")
end)

-- Test 4: inc_priority stops at !1
test("inc_priority stops at !1", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task !1 ^task-123"
  })

  tasks.inc_priority(bufnr, "task-123")
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  assert_equals("- [ ] Task !1 ^task-123", lines[1], "Should stay at !1")
end)

-- Test 5: dec_priority decreases priority
test("dec_priority decreases priority in buffer", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task !2 ^task-123"
  })

  local result = tasks.dec_priority(bufnr, "task-123")
  assert_equals(true, result, "Should return true")

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  assert_equals("- [ ] Task !3 ^task-123", lines[1], "Should decrement to !3")
end)

-- Test 6: dec_priority stops at !5
test("dec_priority stops at !5", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task !5 ^task-123"
  })

  tasks.dec_priority(bufnr, "task-123")
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  assert_equals("- [ ] Task !5 ^task-123", lines[1], "Should stay at !5")
end)

-- Test 7: Commands exist
test(":LifeModeIncPriority command exists", function()
  local commands = vim.api.nvim_get_commands({})
  assert_equals(true, commands.LifeModeIncPriority ~= nil, "Command should exist")
end)

test(":LifeModeDecPriority command exists", function()
  local commands = vim.api.nvim_get_commands({})
  assert_equals(true, commands.LifeModeDecPriority ~= nil, "Command should exist")
end)

-- Test 8: Keymaps work in view buffer
test("Priority keymaps registered in view buffer", function()
  local view = require('lifemode.view')
  local bufnr = view.create_buffer()

  -- Check if keymaps exist
  local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
  local has_inc = false
  local has_dec = false

  for _, keymap in ipairs(keymaps) do
    -- Keymap lhs might be normalized to ' tp' instead of '<Space>tp'
    if keymap.lhs == ' tp' or keymap.lhs == '<Space>tp' then
      has_inc = true
    end
    if keymap.lhs == ' tP' or keymap.lhs == '<Space>tP' then
      has_dec = true
    end
  end

  assert_equals(true, has_inc, "Should have <Space>tp keymap")
  assert_equals(true, has_dec, "Should have <Space>tP keymap")
end)

-- Print summary
print(string.rep("=", 50))
print(string.format("Total: %d | Passed: %d | Failed: %d",
  test_count, pass_count, test_count - pass_count))
print(string.rep("=", 50))

if pass_count == test_count then
  print("\nAll T10 acceptance criteria met!")
  os.exit(0)
else
  print("\nSome tests failed.")
  os.exit(1)
end
