#!/usr/bin/env -S nvim -l

-- ensure_id() tests

local test_count = 0
local pass_count = 0
local fail_count = 0

local function assert_error(fn, expected_msg)
  local ok, err = pcall(fn)
  if ok then
    error("Expected error but function succeeded")
  end
  if expected_msg and not string.find(err, expected_msg, 1, true) then
    error(string.format("Expected error containing '%s' but got: %s", expected_msg, err))
  end
end

local function assert_no_error(fn)
  local ok, err = pcall(fn)
  if not ok then
    error(string.format("Expected no error but got: %s", err))
  end
end

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
package.path = './lua/?.lua;' .. package.path
local blocks = require('lifemode.blocks')
local parser = require('lifemode.parser')

describe("ensure_ids_in_buffer()", function()
  local bufnr

  local function setup_buffer(lines)
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    return bufnr
  end

  local function cleanup_buffer()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end

  test("adds ID to task without ID", function()
    local buf = setup_buffer({
      "- [ ] Task without ID"
    })

    local count = blocks.ensure_ids_in_buffer(buf)

    assert_equals(1, count)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert_true(lines[1]:match("^%- %[ %] Task without ID %^%x+%-%x+%-%x+%-%x+%-%x+$") ~= nil,
      "Expected ID appended to line: " .. lines[1])

    cleanup_buffer()
  end)

  test("preserves ID on task with existing ID", function()
    local buf = setup_buffer({
      "- [ ] Task with ID ^existing-id-123"
    })

    local count = blocks.ensure_ids_in_buffer(buf)

    assert_equals(0, count)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert_equals("- [ ] Task with ID ^existing-id-123", lines[1])

    cleanup_buffer()
  end)

  test("handles multiple tasks without IDs", function()
    local buf = setup_buffer({
      "- [ ] First task",
      "- [x] Second task",
      "- [ ] Third task"
    })

    local count = blocks.ensure_ids_in_buffer(buf)

    assert_equals(3, count)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for i = 1, 3 do
      assert_true(lines[i]:match("%^%x+%-%x+%-%x+%-%x+%-%x+$") ~= nil,
        "Line " .. i .. " should have ID appended: " .. lines[i])
    end

    cleanup_buffer()
  end)

  test("handles mixed tasks (some with IDs, some without)", function()
    local buf = setup_buffer({
      "- [ ] Task without ID",
      "- [x] Task with ID ^existing-123",
      "- [ ] Another task without ID"
    })

    local count = blocks.ensure_ids_in_buffer(buf)

    assert_equals(2, count)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert_true(lines[1]:match("%^%x+%-%x+%-%x+%-%x+%-%x+$") ~= nil, "Line 1 should have ID")
    assert_true(lines[2]:match("%^existing%-123$") ~= nil, "Line 2 should keep existing ID")
    assert_true(lines[3]:match("%^%x+%-%x+%-%x+%-%x+%-%x+$") ~= nil, "Line 3 should have ID")

    cleanup_buffer()
  end)

  test("preserves task content when adding ID", function()
    local buf = setup_buffer({
      "- [ ] Important task with !1 priority"
    })

    local count = blocks.ensure_ids_in_buffer(buf)

    assert_equals(1, count)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert_true(lines[1]:match("^%- %[ %] Important task with !1 priority %^") ~= nil,
      "Task content should be preserved: " .. lines[1])

    cleanup_buffer()
  end)

  test("ignores headings (not tasks)", function()
    local buf = setup_buffer({
      "# Heading without ID",
      "- [ ] Task without ID"
    })

    local count = blocks.ensure_ids_in_buffer(buf)

    assert_equals(1, count)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert_equals("# Heading without ID", lines[1])
    assert_true(lines[2]:match("%^%x+%-%x+%-%x+%-%x+%-%x+$") ~= nil, "Only task should have ID")

    cleanup_buffer()
  end)

  test("ignores list items (not tasks)", function()
    local buf = setup_buffer({
      "- Regular list item",
      "- [ ] Task without ID"
    })

    local count = blocks.ensure_ids_in_buffer(buf)

    assert_equals(1, count)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert_equals("- Regular list item", lines[1])
    assert_true(lines[2]:match("%^%x+%-%x+%-%x+%-%x+%-%x+$") ~= nil, "Only task should have ID")

    cleanup_buffer()
  end)

  test("returns 0 when no tasks need IDs", function()
    local buf = setup_buffer({
      "# Heading",
      "Some text",
      "- Regular list"
    })

    local count = blocks.ensure_ids_in_buffer(buf)

    assert_equals(0, count)

    cleanup_buffer()
  end)

  test("handles empty buffer", function()
    local buf = setup_buffer({})

    local count = blocks.ensure_ids_in_buffer(buf)

    assert_equals(0, count)

    cleanup_buffer()
  end)

  test("handles buffer with only whitespace", function()
    local buf = setup_buffer({
      "",
      "   ",
      ""
    })

    local count = blocks.ensure_ids_in_buffer(buf)

    assert_equals(0, count)

    cleanup_buffer()
  end)

  test("generates unique IDs for multiple tasks", function()
    local buf = setup_buffer({
      "- [ ] Task 1",
      "- [ ] Task 2",
      "- [ ] Task 3"
    })

    blocks.ensure_ids_in_buffer(buf)

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local id1 = lines[1]:match("%^([%x%-]+)$")
    local id2 = lines[2]:match("%^([%x%-]+)$")
    local id3 = lines[3]:match("%^([%x%-]+)$")

    assert_true(id1 ~= id2, "IDs 1 and 2 should be unique")
    assert_true(id1 ~= id3, "IDs 1 and 3 should be unique")
    assert_true(id2 ~= id3, "IDs 2 and 3 should be unique")

    cleanup_buffer()
  end)

  test("appends ID with proper spacing", function()
    local buf = setup_buffer({
      "- [ ] Task"
    })

    blocks.ensure_ids_in_buffer(buf)

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    -- Should have exactly one space before ^
    assert_true(lines[1]:match("Task %^%x") ~= nil, "Should have space before ^: " .. lines[1])
    assert_true(lines[1]:match("Task  %^") == nil, "Should not have double space: " .. lines[1])

    cleanup_buffer()
  end)
end)

-- Summary
print(string.format("\n=== ensure_id Tests Summary ==="))
print(string.format("Total: %d | Pass: %d | Fail: %d", test_count, pass_count, fail_count))

if fail_count > 0 then
  os.exit(1)
else
  os.exit(0)
end
