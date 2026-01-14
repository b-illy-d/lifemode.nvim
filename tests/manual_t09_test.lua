#!/usr/bin/env -S nvim -l

-- Manual acceptance test for T09: Minimal task state toggle
-- Tests the complete flow of toggling task state via command and keymap

local test_count = 0
local pass_count = 0
local fail_count = 0

local function assert_equals(expected, actual, msg)
  if expected ~= actual then
    error(string.format("%s\nExpected: %s\nActual: %s",
      msg or "Assertion failed",
      vim.inspect(expected),
      vim.inspect(actual)))
  end
end

local function assert_true(condition, msg)
  if not condition then
    error(msg or "Expected true but got false")
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

-- Setup environment
package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
local lifemode = require('lifemode')
local tasks = require('lifemode.tasks')

-- Initialize plugin
lifemode._reset_for_testing()
lifemode.setup({ vault_root = '/tmp/test-vault' })

describe("T09 Acceptance Tests", function()
  test("toggle_task_state toggles checkbox in buffer", function()
    -- Create buffer with tasks
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "# My Tasks",
      "- [ ] Write documentation ^doc-task",
      "- [x] Review code ^review-task",
      "- [ ] Fix bug ^bug-task",
    })

    -- Toggle todo to done
    local result = tasks.toggle_task_state(bufnr, "doc-task")
    assert_true(result, "toggle_task_state should return true")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [x] Write documentation ^doc-task", lines[2],
      "Task should be marked as done")

    -- Toggle done to todo
    result = tasks.toggle_task_state(bufnr, "review-task")
    assert_true(result, "toggle_task_state should return true")

    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [ ] Review code ^review-task", lines[3],
      "Task should be marked as todo")

    -- Clean up
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  test("get_task_at_cursor returns correct node_id", function()
    -- Create buffer with tasks
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "# Tasks",
      "- [ ] First task ^task-1",
      "- [ ] Second task ^task-2",
      "- List item ^list-1",
    })

    -- Set as current buffer and position cursor
    vim.api.nvim_set_current_buf(bufnr)

    -- Cursor on first task
    vim.api.nvim_win_set_cursor(0, {2, 0})
    local node_id, buf = tasks.get_task_at_cursor()
    assert_equals("task-1", node_id, "Should return task-1")
    assert_equals(bufnr, buf, "Should return correct buffer")

    -- Cursor on second task
    vim.api.nvim_win_set_cursor(0, {3, 0})
    node_id, buf = tasks.get_task_at_cursor()
    assert_equals("task-2", node_id, "Should return task-2")

    -- Cursor on list item (not a task)
    vim.api.nvim_win_set_cursor(0, {4, 0})
    node_id = tasks.get_task_at_cursor()
    assert_equals(nil, node_id, "Should return nil for non-task")

    -- Clean up
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  test(":LifeModeToggleTask command exists", function()
    local cmd = vim.api.nvim_get_commands({})['LifeModeToggleTask']
    assert_true(cmd ~= nil, "LifeModeToggleTask command should be defined")
  end)

  test(":LifeModeToggleTask toggles task at cursor", function()
    -- Create buffer with tasks
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "- [ ] Task to toggle ^task-1",
    })

    -- Set as current buffer and position cursor
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_win_set_cursor(0, {1, 0})

    -- Execute command
    vim.cmd('LifeModeToggleTask')

    -- Verify state changed
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [x] Task to toggle ^task-1", lines[1],
      "Task should be marked as done after command")

    -- Toggle again
    vim.cmd('LifeModeToggleTask')
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [ ] Task to toggle ^task-1", lines[1],
      "Task should be marked as todo after second toggle")

    -- Clean up
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  test("preserves content during toggle", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "- [ ] Complex task with [[wikilink]] and !1 priority ^complex-task",
    })

    -- Toggle to done
    tasks.toggle_task_state(bufnr, "complex-task")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_true(lines[1]:match("%[%[wikilink%]%]"), "Wikilink should be preserved")
    assert_true(lines[1]:match("!1"), "Priority should be preserved")
    assert_true(lines[1]:match("%^complex%-task"), "ID should be preserved")

    -- Clean up
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  test("handles nested task hierarchy", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "- [ ] Parent task ^parent",
      "  - [ ] Child task 1 ^child1",
      "  - [ ] Child task 2 ^child2",
      "    - [ ] Grandchild task ^grandchild",
    })

    -- Toggle child task
    tasks.toggle_task_state(bufnr, "child1")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    -- Verify child1 toggled but others unchanged
    assert_equals("- [ ] Parent task ^parent", lines[1])
    assert_equals("  - [x] Child task 1 ^child1", lines[2])
    assert_equals("  - [ ] Child task 2 ^child2", lines[3])
    assert_equals("    - [ ] Grandchild task ^grandchild", lines[4])

    -- Toggle grandchild
    tasks.toggle_task_state(bufnr, "grandchild")
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("    - [x] Grandchild task ^grandchild", lines[4])

    -- Clean up
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  test("handles multiple toggles correctly", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "- [ ] Flip me ^flip-task",
    })

    -- Perform 5 toggles
    for i = 1, 5 do
      tasks.toggle_task_state(bufnr, "flip-task")
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

      -- Should alternate between done and todo
      local expected = (i % 2 == 1) and "- [x] Flip me ^flip-task" or "- [ ] Flip me ^flip-task"
      assert_equals(expected, lines[1], string.format("After toggle %d", i))
    end

    -- Clean up
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  test("returns false for non-existent node_id", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "- [ ] Real task ^real-task",
    })

    local result = tasks.toggle_task_state(bufnr, "fake-task")
    assert_equals(false, result, "Should return false for non-existent ID")

    -- Original task unchanged
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [ ] Real task ^real-task", lines[1])

    -- Clean up
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  test("works with both hyphen and asterisk syntax", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "- [ ] Hyphen task ^task-1",
      "* [ ] Asterisk task ^task-2",
    })

    -- Toggle both
    tasks.toggle_task_state(bufnr, "task-1")
    tasks.toggle_task_state(bufnr, "task-2")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [x] Hyphen task ^task-1", lines[1])
    assert_equals("* [x] Asterisk task ^task-2", lines[2])

    -- Clean up
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
end)

-- Print summary
print(string.format("\n%s", string.rep("=", 50)))
print(string.format("Tests: %d | Pass: %d | Fail: %d", test_count, pass_count, fail_count))
print(string.rep("=", 50))

if pass_count == test_count then
  print("\nT09 ACCEPTANCE: PASS")
  print("- toggle_task_state() implemented")
  print("- Checkbox toggle working correctly")
  print("- get_task_at_cursor() implemented")
  print("- :LifeModeToggleTask command working")
  print("- Content preservation verified")
  print("- Edge cases handled")
end

-- Exit with appropriate code
if fail_count > 0 then
  os.exit(1)
else
  os.exit(0)
end
