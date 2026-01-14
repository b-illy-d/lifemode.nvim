#!/usr/bin/env -S nvim -l

-- tasks.lua tests

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
local tasks = require('lifemode.tasks')
local parser = require('lifemode.parser')

describe("toggle_task_state()", function()
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

  test("toggles todo to done", function()
    bufnr = setup_buffer({
      "# Tasks",
      "- [ ] Write tests ^task-1",
      "- [ ] Write code ^task-2",
    })

    tasks.toggle_task_state(bufnr, "task-1")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [x] Write tests ^task-1", lines[2])
    -- Other lines unchanged
    assert_equals("# Tasks", lines[1])
    assert_equals("- [ ] Write code ^task-2", lines[3])

    cleanup_buffer()
  end)

  test("toggles done to todo", function()
    bufnr = setup_buffer({
      "# Tasks",
      "- [x] Write tests ^task-1",
      "- [ ] Write code ^task-2",
    })

    tasks.toggle_task_state(bufnr, "task-1")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [ ] Write tests ^task-1", lines[2])
    -- Other lines unchanged
    assert_equals("# Tasks", lines[1])
    assert_equals("- [ ] Write code ^task-2", lines[3])

    cleanup_buffer()
  end)

  test("handles uppercase [X] checkbox", function()
    bufnr = setup_buffer({
      "- [X] Done task ^task-1",
    })

    tasks.toggle_task_state(bufnr, "task-1")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [ ] Done task ^task-1", lines[1])

    cleanup_buffer()
  end)

  test("preserves indentation", function()
    bufnr = setup_buffer({
      "- [ ] Parent ^task-1",
      "  - [ ] Child ^task-2",
      "    - [ ] Grandchild ^task-3",
    })

    tasks.toggle_task_state(bufnr, "task-2")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("  - [x] Child ^task-2", lines[2])
    -- Check indentation preserved
    assert_true(lines[2]:match("^%s%s"), "Should preserve 2-space indent")

    cleanup_buffer()
  end)

  test("preserves task content", function()
    bufnr = setup_buffer({
      "- [ ] Task with [[wikilink]] and !1 priority ^task-1",
    })

    tasks.toggle_task_state(bufnr, "task-1")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [x] Task with [[wikilink]] and !1 priority ^task-1", lines[1])

    cleanup_buffer()
  end)

  test("handles multiple toggles", function()
    bufnr = setup_buffer({
      "- [ ] Toggle me ^task-1",
    })

    -- Toggle to done
    tasks.toggle_task_state(bufnr, "task-1")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [x] Toggle me ^task-1", lines[1])

    -- Toggle back to todo
    tasks.toggle_task_state(bufnr, "task-1")
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [ ] Toggle me ^task-1", lines[1])

    -- Toggle to done again
    tasks.toggle_task_state(bufnr, "task-1")
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [x] Toggle me ^task-1", lines[1])

    cleanup_buffer()
  end)

  test("returns false when node_id not found", function()
    bufnr = setup_buffer({
      "- [ ] Task ^task-1",
    })

    local result = tasks.toggle_task_state(bufnr, "nonexistent-id")
    assert_equals(false, result)

    cleanup_buffer()
  end)

  test("returns false when node is not a task", function()
    bufnr = setup_buffer({
      "# Heading ^heading-1",
      "- List item ^list-1",
    })

    local result = tasks.toggle_task_state(bufnr, "heading-1")
    assert_equals(false, result)

    result = tasks.toggle_task_state(bufnr, "list-1")
    assert_equals(false, result)

    cleanup_buffer()
  end)

  test("handles task without ID gracefully", function()
    bufnr = setup_buffer({
      "- [ ] Task without ID",
      "- [ ] Task with ID ^task-1",
    })

    -- Try to toggle non-existent ID - should return false
    local result = tasks.toggle_task_state(bufnr, "nonexistent")
    assert_equals(false, result)

    -- Task without ID remains unchanged
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("- [ ] Task without ID", lines[1])

    cleanup_buffer()
  end)

  test("handles empty buffer", function()
    bufnr = setup_buffer({})

    local result = tasks.toggle_task_state(bufnr, "task-1")
    assert_equals(false, result)

    cleanup_buffer()
  end)

  test("handles buffer with no tasks", function()
    bufnr = setup_buffer({
      "# Heading",
      "Some text",
      "- List item",
    })

    local result = tasks.toggle_task_state(bufnr, "task-1")
    assert_equals(false, result)

    cleanup_buffer()
  end)

  test("uses asterisk syntax", function()
    bufnr = setup_buffer({
      "* [ ] Task with asterisk ^task-1",
    })

    tasks.toggle_task_state(bufnr, "task-1")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert_equals("* [x] Task with asterisk ^task-1", lines[1])

    cleanup_buffer()
  end)
end)

describe("get_task_at_cursor()", function()
  local bufnr

  local function setup_buffer_and_cursor(lines, row, col)
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_win_set_cursor(0, {row, col})
    return bufnr
  end

  local function cleanup_buffer()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end

  test("returns node_id when cursor on task line", function()
    bufnr = setup_buffer_and_cursor({
      "# Tasks",
      "- [ ] Write tests ^task-1",
      "- [ ] Write code ^task-2",
    }, 2, 5)  -- Cursor on "Write tests" line

    local node_id, buf = tasks.get_task_at_cursor()
    assert_equals("task-1", node_id)
    assert_equals(bufnr, buf)

    cleanup_buffer()
  end)

  test("returns nil when cursor on non-task line", function()
    bufnr = setup_buffer_and_cursor({
      "# Tasks",
      "- List item ^list-1",
    }, 2, 0)

    local node_id = tasks.get_task_at_cursor()
    assert_nil(node_id)

    cleanup_buffer()
  end)

  test("returns nil when cursor on heading", function()
    bufnr = setup_buffer_and_cursor({
      "# Tasks ^heading-1",
      "- [ ] Write tests ^task-1",
    }, 1, 0)

    local node_id = tasks.get_task_at_cursor()
    assert_nil(node_id)

    cleanup_buffer()
  end)

  test("returns nil when task has no ID", function()
    bufnr = setup_buffer_and_cursor({
      "- [ ] Task without ID",
    }, 1, 0)

    local node_id = tasks.get_task_at_cursor()
    assert_nil(node_id)

    cleanup_buffer()
  end)

  test("works with indented tasks", function()
    bufnr = setup_buffer_and_cursor({
      "- [ ] Parent ^task-1",
      "  - [ ] Child ^task-2",
    }, 2, 5)

    local node_id, buf = tasks.get_task_at_cursor()
    assert_equals("task-2", node_id)
    assert_equals(bufnr, buf)

    cleanup_buffer()
  end)
end)

-- Print summary
print(string.format("\n%s", string.rep("=", 50)))
print(string.format("Tests: %d | Pass: %d | Fail: %d", test_count, pass_count, fail_count))
print(string.rep("=", 50))

-- Exit with appropriate code
if fail_count > 0 then
  os.exit(1)
else
  os.exit(0)
end
