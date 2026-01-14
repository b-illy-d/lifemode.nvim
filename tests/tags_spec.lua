#!/usr/bin/env -S nvim -l

-- Tag operations tests for T16

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

local function assert_contains(list, item, msg)
  for _, v in ipairs(list) do
    if v == item then
      return
    end
  end
  error(msg or string.format("Expected list to contain %s but it didn't: %s", vim.inspect(item), vim.inspect(list)))
end

local function assert_not_contains(list, item, msg)
  for _, v in ipairs(list) do
    if v == item then
      error(msg or string.format("Expected list not to contain %s but it did: %s", vim.inspect(item), vim.inspect(list)))
    end
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

describe("get_tags()", function()
  test("extracts single tag from line", function()
    local line = "- [ ] Task with #project tag ^task-id"
    local tags = tasks.get_tags(line)
    assert_equals(1, #tags)
    assert_contains(tags, "project")
  end)

  test("extracts multiple tags from line", function()
    local line = "- [ ] Task #urgent #project #work ^task-id"
    local tags = tasks.get_tags(line)
    assert_equals(3, #tags)
    assert_contains(tags, "urgent")
    assert_contains(tags, "project")
    assert_contains(tags, "work")
  end)

  test("extracts hierarchical tags with slash", function()
    local line = "- [ ] Task #project/lifemode #area/coding ^task-id"
    local tags = tasks.get_tags(line)
    assert_equals(2, #tags)
    assert_contains(tags, "project/lifemode")
    assert_contains(tags, "area/coding")
  end)

  test("returns empty array for line with no tags", function()
    local line = "- [ ] Task without tags ^task-id"
    local tags = tasks.get_tags(line)
    assert_equals(0, #tags)
  end)

  test("handles tags with underscores", function()
    local line = "- [ ] Task #my_tag #another_one ^task-id"
    local tags = tasks.get_tags(line)
    assert_equals(2, #tags)
    assert_contains(tags, "my_tag")
    assert_contains(tags, "another_one")
  end)

  test("handles tags with hyphens", function()
    local line = "- [ ] Task #my-tag #another-one ^task-id"
    local tags = tasks.get_tags(line)
    assert_equals(2, #tags)
    assert_contains(tags, "my-tag")
    assert_contains(tags, "another-one")
  end)

  test("handles tags mixed with priority and ID", function()
    local line = "- [ ] Task #urgent !1 #project ^task-id"
    local tags = tasks.get_tags(line)
    assert_equals(2, #tags)
    assert_contains(tags, "urgent")
    assert_contains(tags, "project")
  end)
end)

describe("add_tag()", function()
  test("adds tag to task without existing tags", function()
    -- Create a test buffer
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    -- Add tag
    local success = tasks.add_tag(bufnr, "test-id", "urgent")
    assert_true(success, "add_tag should return true")

    -- Verify tag added
    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    local tags = tasks.get_tags(lines[1])
    assert_contains(tags, "urgent")

    -- Cleanup
    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("adds tag before existing ID", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    tasks.add_tag(bufnr, "test-id", "project")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    assert_true(lines[1]:match("#project.*%^test%-id"), "Tag should appear before ID")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("adds second tag to task with existing tag", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task #urgent ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    tasks.add_tag(bufnr, "test-id", "project")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    local tags = tasks.get_tags(lines[1])
    assert_equals(2, #tags)
    assert_contains(tags, "urgent")
    assert_contains(tags, "project")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("does not add duplicate tag", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task #urgent ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    tasks.add_tag(bufnr, "test-id", "urgent")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    local tags = tasks.get_tags(lines[1])
    assert_equals(1, #tags, "Should not add duplicate tag")
    assert_contains(tags, "urgent")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("handles hierarchical tags", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    tasks.add_tag(bufnr, "test-id", "project/lifemode")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    local tags = tasks.get_tags(lines[1])
    assert_contains(tags, "project/lifemode")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("returns false for non-existent node_id", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    local success = tasks.add_tag(bufnr, "nonexistent-id", "urgent")
    assert_false(success, "Should return false for nonexistent node")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("returns false for non-task node", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- List item ^list-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    local success = tasks.add_tag(bufnr, "list-id", "urgent")
    assert_false(success, "Should return false for non-task node")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)
end)

describe("remove_tag()", function()
  test("removes tag from task", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task #urgent #project ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    local success = tasks.remove_tag(bufnr, "test-id", "urgent")
    assert_true(success, "remove_tag should return true")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    local tags = tasks.get_tags(lines[1])
    assert_equals(1, #tags)
    assert_not_contains(tags, "urgent")
    assert_contains(tags, "project")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("removes only specified tag", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task #urgent #project #work ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    tasks.remove_tag(bufnr, "test-id", "project")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    local tags = tasks.get_tags(lines[1])
    assert_equals(2, #tags)
    assert_contains(tags, "urgent")
    assert_contains(tags, "work")
    assert_not_contains(tags, "project")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("removes last tag from task", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task #urgent ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    tasks.remove_tag(bufnr, "test-id", "urgent")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    local tags = tasks.get_tags(lines[1])
    assert_equals(0, #tags, "Should have no tags after removing last one")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("handles hierarchical tag removal", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task #project/lifemode #area/coding ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    tasks.remove_tag(bufnr, "test-id", "project/lifemode")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    local tags = tasks.get_tags(lines[1])
    assert_equals(1, #tags)
    assert_contains(tags, "area/coding")
    assert_not_contains(tags, "project/lifemode")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("returns true but does nothing if tag not present", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task #urgent ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    local success = tasks.remove_tag(bufnr, "test-id", "nonexistent")
    assert_true(success, "Should return true even if tag not found")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    local tags = tasks.get_tags(lines[1])
    assert_equals(1, #tags)
    assert_contains(tags, "urgent")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("returns false for non-existent node_id", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task #urgent ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    local success = tasks.remove_tag(bufnr, "nonexistent-id", "urgent")
    assert_false(success, "Should return false for nonexistent node")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("returns false for non-task node", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- List item #tag ^list-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    local success = tasks.remove_tag(bufnr, "list-id", "tag")
    assert_false(success, "Should return false for non-task node")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("cleans up spacing after tag removal", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task #urgent ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    tasks.remove_tag(bufnr, "test-id", "urgent")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    -- Should not have double spaces
    assert_false(lines[1]:match("%s%s"), "Should not have double spaces")
    -- Should have exactly one space before ID
    assert_true(lines[1]:match("Task %^test%-id$"), "Should have single space before ID")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)
end)

-- Print summary
print(string.format("\n\nSummary: %d tests, %d passed, %d failed", test_count, pass_count, fail_count))

-- Exit with appropriate code
if fail_count > 0 then
  os.exit(1)
else
  os.exit(0)
end
