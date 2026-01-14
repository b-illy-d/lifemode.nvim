#!/usr/bin/env -S nvim -l

-- Priority operations tests for T10

local test_count = 0
local pass_count = 0
local fail_count = 0

local function assert_equals(expected, actual)
  if expected ~= actual then
    error(string.format("Expected %s but got %s", vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_true(condition, msg)
  if not condition then
    error(msg or "Expected true but got false")
  end
end

local function assert_false(condition, msg)
  if condition then
    error(msg or "Expected false but got true")
  end
end

local function assert_nil(value, msg)
  if value ~= nil then
    error(msg or string.format("Expected nil but got %s", vim.inspect(value)))
  end
end

local function test(name, fn)
  test_count = test_count + 1
  io.write(string.format("  [%d] %s ... ", test_count, name))
  io.flush()

  local ok, err = pcall(fn)
  if ok then
    pass_count = pass_count + 1
    print("PASS")
  else
    fail_count = fail_count + 1
    print(string.format("FAIL\n      %s", err))
  end
end

local function describe(name, fn)
  print(string.format("\n%s:", name))
  fn()
end

-- Load the module
package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
local tasks = require('lifemode.tasks')
local parser = require('lifemode.parser')

describe("get_priority()", function()
  test("extracts !1 from task line", function()
    local line = "- [ ] High priority task !1 ^task-id"
    local priority = tasks.get_priority(line)
    assert_equals(1, priority)
  end)

  test("extracts !5 from task line", function()
    local line = "- [ ] Low priority task !5 ^task-id"
    local priority = tasks.get_priority(line)
    assert_equals(5, priority)
  end)

  test("returns nil for task without priority", function()
    local line = "- [ ] Task without priority ^task-id"
    local priority = tasks.get_priority(line)
    assert_nil(priority, "Should return nil for no priority")
  end)

  test("returns nil for invalid priority !0", function()
    local line = "- [ ] Task with !0 ^task-id"
    local priority = tasks.get_priority(line)
    assert_nil(priority, "Should return nil for !0")
  end)

  test("returns nil for invalid priority !6", function()
    local line = "- [ ] Task with !6 ^task-id"
    local priority = tasks.get_priority(line)
    assert_nil(priority, "Should return nil for !6")
  end)

  test("extracts priority from middle of line", function()
    local line = "- [ ] Task !3 with more text ^task-id"
    local priority = tasks.get_priority(line)
    assert_equals(3, priority)
  end)
end)

describe("set_priority()", function()
  test("adds !3 to task without priority", function()
    local line = "- [ ] Task ^task-id"
    local new_line = tasks.set_priority(line, 3)
    assert_equals("- [ ] Task !3 ^task-id", new_line)
  end)

  test("updates !5 to !2", function()
    local line = "- [ ] Task !5 ^task-id"
    local new_line = tasks.set_priority(line, 2)
    assert_equals("- [ ] Task !2 ^task-id", new_line)
  end)

  test("removes priority when given nil", function()
    local line = "- [ ] Task !3 ^task-id"
    local new_line = tasks.set_priority(line, nil)
    assert_equals("- [ ] Task ^task-id", new_line)
  end)

  test("handles task without ID", function()
    local line = "- [ ] Task without ID"
    local new_line = tasks.set_priority(line, 2)
    assert_equals("- [ ] Task without ID !2", new_line)
  end)

  test("updates priority without ID", function()
    local line = "- [ ] Task with !4"
    local new_line = tasks.set_priority(line, 1)
    assert_equals("- [ ] Task with !1", new_line)
  end)

  test("preserves indentation", function()
    local line = "  - [ ] Indented task !2 ^task-id"
    local new_line = tasks.set_priority(line, 3)
    assert_equals("  - [ ] Indented task !3 ^task-id", new_line)
  end)
end)

describe("inc_priority()", function()
  local bufnr

  local function setup_buffer(lines)
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end

  test("increments !3 to !2", function()
    setup_buffer({"- [ ] Task !3 ^task-123"})
    local result = tasks.inc_priority(bufnr, "task-123")
    assert_true(result, "Should return true for success")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [ ] Task !2 ^task-123", lines[1])
  end)

  test("stops at !1", function()
    setup_buffer({"- [ ] Task !1 ^task-123"})
    local result = tasks.inc_priority(bufnr, "task-123")
    assert_true(result, "Should return true")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [ ] Task !1 ^task-123", lines[1])
  end)

  test("adds !5 to task without priority", function()
    setup_buffer({"- [ ] Task ^task-123"})
    local result = tasks.inc_priority(bufnr, "task-123")
    assert_true(result, "Should return true")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [ ] Task !5 ^task-123", lines[1])
  end)

  test("returns false for non-existent task", function()
    setup_buffer({"- [ ] Task !3 ^task-123"})
    local result = tasks.inc_priority(bufnr, "task-999")
    assert_false(result, "Should return false for non-existent task")
  end)

  test("returns false for non-task node", function()
    setup_buffer({"- List item !3 ^item-123"})
    local result = tasks.inc_priority(bufnr, "item-123")
    assert_false(result, "Should return false for list item")
  end)

  test("handles done tasks [x]", function()
    setup_buffer({"- [x] Done task !4 ^task-123"})
    local result = tasks.inc_priority(bufnr, "task-123")
    assert_true(result, "Should work on done tasks")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [x] Done task !3 ^task-123", lines[1])
  end)

  test("handles asterisk task marker", function()
    setup_buffer({"* [ ] Task !3 ^task-123"})
    local result = tasks.inc_priority(bufnr, "task-123")
    assert_true(result, "Should work with asterisk")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("* [ ] Task !2 ^task-123", lines[1])
  end)

  test("handles indented tasks", function()
    setup_buffer({"  - [ ] Indented task !2 ^task-123"})
    local result = tasks.inc_priority(bufnr, "task-123")
    assert_true(result, "Should work with indentation")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("  - [ ] Indented task !1 ^task-123", lines[1])
  end)
end)

describe("dec_priority()", function()
  local bufnr

  local function setup_buffer(lines)
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end

  test("decrements !2 to !3", function()
    setup_buffer({"- [ ] Task !2 ^task-123"})
    local result = tasks.dec_priority(bufnr, "task-123")
    assert_true(result, "Should return true")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [ ] Task !3 ^task-123", lines[1])
  end)

  test("stops at !5", function()
    setup_buffer({"- [ ] Task !5 ^task-123"})
    local result = tasks.dec_priority(bufnr, "task-123")
    assert_true(result, "Should return true")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [ ] Task !5 ^task-123", lines[1])
  end)

  test("does nothing for task without priority", function()
    setup_buffer({"- [ ] Task ^task-123"})
    local result = tasks.dec_priority(bufnr, "task-123")
    assert_true(result, "Should return true")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [ ] Task ^task-123", lines[1])
  end)

  test("handles indented tasks", function()
    setup_buffer({"  - [ ] Indented task !2 ^task-123"})
    local result = tasks.dec_priority(bufnr, "task-123")
    assert_true(result, "Should work with indentation")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("  - [ ] Indented task !3 ^task-123", lines[1])
  end)
end)

-- Print summary
print(string.rep("=", 70))
print(string.format("Total: %d | Passed: %d | Failed: %d",
  test_count, pass_count, fail_count))
print(string.rep("=", 70))

-- Exit with appropriate code
if fail_count > 0 then
  os.exit(1)
else
  os.exit(0)
end
