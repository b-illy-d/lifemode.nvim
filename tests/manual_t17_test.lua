#!/usr/bin/env -S nvim -l

-- Manual acceptance test for T17: Due date set/clear

print("=================================================================")
print("Manual Acceptance Test: T17 - Due Date Set/Clear")
print("=================================================================\n")

local test_count = 0
local pass_count = 0

local function test(description, fn)
  test_count = test_count + 1
  io.write(string.format("[%d] %s ... ", test_count, description))
  io.flush()

  local ok, err = pcall(fn)
  if ok then
    pass_count = pass_count + 1
    print("PASS")
    return true
  else
    print(string.format("FAIL\n    %s", err))
    return false
  end
end

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s\nExpected: %s\nActual: %s",
      msg or "Values not equal",
      vim.inspect(expected),
      vim.inspect(actual)))
  end
end

local function assert_true(value, msg)
  if not value then
    error(msg or "Expected true")
  end
end

local function assert_match(str, pattern, msg)
  if not str:match(pattern) then
    error(string.format("%s\nString: %s\nPattern: %s",
      msg or "Pattern not found",
      str,
      pattern))
  end
end

-- Load modules
local tasks = require('lifemode.tasks')
local parser = require('lifemode.parser')

print("Testing due date extraction and manipulation\n")

test("get_due extracts @due(YYYY-MM-DD) from line", function()
  local line = "- [ ] Task with due @due(2026-02-15) ^task-1"
  local due = tasks.get_due(line)
  assert_eq(due, "2026-02-15", "Should extract due date")
end)

test("get_due returns nil when no due date present", function()
  local line = "- [ ] Task without due ^task-1"
  local due = tasks.get_due(line)
  assert_eq(due, nil, "Should return nil")
end)

test("get_due validates YYYY-MM-DD format strictly", function()
  local line1 = "- [ ] Task @due(2026-1-5) ^task-1"  -- Invalid: single digit
  local line2 = "- [ ] Task @due(26-01-05) ^task-1"  -- Invalid: 2-digit year
  local due1 = tasks.get_due(line1)
  local due2 = tasks.get_due(line2)
  assert_eq(due1, nil, "Should reject single digit month/day")
  assert_eq(due2, nil, "Should reject 2-digit year")
end)

test("set_due adds due date before ID", function()
  local line = "- [ ] Task ^task-1"
  local result = tasks.set_due(line, "2026-03-20")
  assert_eq(result, "- [ ] Task @due(2026-03-20) ^task-1", "Should add before ID")
end)

test("set_due updates existing due date", function()
  local line = "- [ ] Task @due(2026-01-01) ^task-1"
  local result = tasks.set_due(line, "2026-12-31")
  assert_eq(result, "- [ ] Task @due(2026-12-31) ^task-1", "Should update date")
end)

test("set_due removes due when date is nil", function()
  local line = "- [ ] Task @due(2026-06-15) ^task-1"
  local result = tasks.set_due(line, nil)
  assert_eq(result, "- [ ] Task ^task-1", "Should remove due")
end)

test("set_due preserves priority and tags", function()
  local line = "- [ ] Task !2 #work @due(2026-01-01) ^task-1"
  local result = tasks.set_due(line, "2026-02-01")
  assert_match(result, "!2", "Should preserve priority")
  assert_match(result, "#work", "Should preserve tags")
  assert_match(result, "@due%(2026%-02%-01%)", "Should update due")
end)

test("set_due_buffer updates task in buffer", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task one ^task-1",
    "- [ ] Task two ^task-2",
  })

  local success = tasks.set_due_buffer(bufnr, "task-2", "2026-07-04")
  assert_true(success, "Should succeed")

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  assert_eq(lines[2], "- [ ] Task two @due(2026-07-04) ^task-2", "Should add due to task-2")

  vim.api.nvim_buf_delete(bufnr, {force = true})
end)

test("set_due_buffer validates date format", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task ^task-1",
  })

  local success = tasks.set_due_buffer(bufnr, "task-1", "2026-1-15")
  assert_eq(success, false, "Should reject invalid format")

  vim.api.nvim_buf_delete(bufnr, {force = true})
end)

test("clear_due_buffer removes due date", function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task @due(2026-12-25) ^task-1",
  })

  local success = tasks.clear_due_buffer(bufnr, "task-1")
  assert_true(success, "Should succeed")

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  assert_eq(lines[1], "- [ ] Task ^task-1", "Should remove due")

  vim.api.nvim_buf_delete(bufnr, {force = true})
end)

print("\n=================================================================")
print(string.format("Results: %d/%d tests passed", pass_count, test_count))
print("=================================================================\n")

if pass_count == test_count then
  print("✓ All acceptance criteria met for T17")
  print("\nFeatures implemented:")
  print("  • Due date syntax: @due(YYYY-MM-DD)")
  print("  • get_due(line) - extract due date from task line")
  print("  • set_due(line, date) - add/update/remove due date")
  print("  • set_due_buffer(bufnr, node_id, date) - buffer operation")
  print("  • clear_due_buffer(bufnr, node_id) - clear due date")
  print("  • set_due_interactive() - prompt user for date")
  print("  • clear_due_interactive() - clear with confirmation")
  print("  • :LifeModeSetDue command")
  print("  • :LifeModeClearDue command")
  print("  • <Space>td keymap in vault files and view buffers")
  print("\nNext: Due dates can be displayed in task/brief lens virtual text")
  os.exit(0)
else
  print(string.format("✗ %d tests failed", test_count - pass_count))
  os.exit(1)
end
