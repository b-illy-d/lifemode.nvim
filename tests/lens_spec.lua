#!/usr/bin/env -S nvim -l

-- lens.lua tests

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

local function assert_matches(pattern, text, msg)
  if not text:match(pattern) then
    error(msg or string.format("Expected text to match pattern '%s' but got: %s", pattern, text))
  end
end

local function assert_table_contains(tbl, value, msg)
  for _, v in ipairs(tbl) do
    if v == value then
      return
    end
  end
  error(msg or string.format("Expected table to contain %s", vim.inspect(value)))
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
    print("FAIL")
    print("    Error: " .. tostring(err))
  end
end

local function describe(description, fn)
  print("\n" .. description)
  fn()
end

-- Load the module
package.path = './lua/?.lua;' .. package.path
local lens = require('lifemode.lens')

-- Start tests
print("=== lens.lua Tests ===")

describe("Lens Registry", function()
  test("has task/brief lens", function()
    local lenses = lens.get_available_lenses()
    assert_table_contains(lenses, "task/brief", "Should have task/brief lens")
  end)

  test("has task/detail lens", function()
    local lenses = lens.get_available_lenses()
    assert_table_contains(lenses, "task/detail", "Should have task/detail lens")
  end)

  test("has node/raw lens", function()
    local lenses = lens.get_available_lenses()
    assert_table_contains(lenses, "node/raw", "Should have node/raw lens")
  end)
end)

describe("Lens Rendering - task/brief", function()
  test("renders task with state and title", function()
    local node = {
      type = "task",
      body_md = "- [ ] Write documentation",
      props = { state = "todo" }
    }
    local result = lens.render(node, "task/brief")
    assert_matches("%[ %]", result, "Should contain checkbox")
    assert_matches("Write documentation", result, "Should contain task title")
  end)

  test("renders task with priority", function()
    local node = {
      type = "task",
      body_md = "- [ ] Important task !2",
      props = { state = "todo", priority = 2 }
    }
    local result = lens.render(node, "task/brief")
    assert_matches("!2", result, "Should show priority marker")
  end)

  test("renders completed task", function()
    local node = {
      type = "task",
      body_md = "- [x] Completed task",
      props = { state = "done" }
    }
    local result = lens.render(node, "task/brief")
    assert_matches("%[x%]", result, "Should show completed checkbox")
  end)

  test("does not show ID in brief lens", function()
    local node = {
      type = "task",
      body_md = "- [ ] Task with ID ^uuid-1234",
      props = { state = "todo" }
    }
    local result = lens.render(node, "task/brief")
    assert_true(not result:match("%^uuid%-1234"), "Should not show ID in brief lens")
  end)
end)

describe("Lens Rendering - task/detail", function()
  test("renders task with full metadata", function()
    local node = {
      type = "task",
      body_md = "- [ ] Detailed task !3 ^task-123",
      props = {
        state = "todo",
        priority = 3,
        tags = { "#work", "#urgent" }
      },
      id = "task-123"
    }
    local result = lens.render(node, "task/detail")
    -- Result might be string or table of lines
    local text = type(result) == "table" and table.concat(result, "\n") or result
    assert_matches("Detailed task", text, "Should contain task title")
    assert_matches("!3", text, "Should show priority")
    assert_matches("task%-123", text, "Should show ID")
  end)

  test("renders task with tags", function()
    local node = {
      type = "task",
      body_md = "- [ ] Task with tags",
      props = {
        state = "todo",
        tags = { "#work", "#urgent" }
      }
    }
    local result = lens.render(node, "task/detail")
    -- Result might be string or table of lines
    local text = type(result) == "table" and table.concat(result, "\n") or result
    assert_matches("#work", text, "Should show #work tag")
    assert_matches("#urgent", text, "Should show #urgent tag")
  end)

  test("shows multiline format for detail lens", function()
    local node = {
      type = "task",
      body_md = "- [ ] Complex task !1 ^abc",
      props = {
        state = "todo",
        priority = 1
      },
      id = "abc"
    }
    local result = lens.render(node, "task/detail")
    -- task/detail should return string (can be multiline) or table of lines
    assert_true(type(result) == "string" or type(result) == "table",
      "Should return string or table of lines")
  end)
end)

describe("Lens Rendering - node/raw", function()
  test("renders raw markdown for task", function()
    local node = {
      type = "task",
      body_md = "- [ ] Raw task content !2 ^id-123",
      props = { state = "todo" }
    }
    local result = lens.render(node, "node/raw")
    assert_equals("- [ ] Raw task content !2 ^id-123", result,
      "Should render exact raw markdown")
  end)

  test("renders raw markdown for heading", function()
    local node = {
      type = "heading",
      body_md = "## Section Heading",
      props = { level = 2 }
    }
    local result = lens.render(node, "node/raw")
    assert_equals("## Section Heading", result,
      "Should render exact raw markdown")
  end)

  test("renders raw markdown for list item", function()
    local node = {
      type = "list_item",
      body_md = "- List item content",
      props = {}
    }
    local result = lens.render(node, "node/raw")
    assert_equals("- List item content", result,
      "Should render exact raw markdown")
  end)
end)

describe("Lens Cycling", function()
  test("cycles forward from task/brief to task/detail", function()
    local next_lens = lens.cycle_lens("task/brief", 1)
    assert_equals("task/detail", next_lens, "Should cycle to task/detail")
  end)

  test("cycles forward from task/detail to node/raw", function()
    local next_lens = lens.cycle_lens("task/detail", 1)
    assert_equals("node/raw", next_lens, "Should cycle to node/raw")
  end)

  test("cycles forward from node/raw to task/brief (wraps)", function()
    local next_lens = lens.cycle_lens("node/raw", 1)
    assert_equals("task/brief", next_lens, "Should wrap to task/brief")
  end)

  test("cycles backward from task/brief to node/raw (wraps)", function()
    local prev_lens = lens.cycle_lens("task/brief", -1)
    assert_equals("node/raw", prev_lens, "Should wrap to node/raw")
  end)

  test("cycles backward from node/raw to task/detail", function()
    local prev_lens = lens.cycle_lens("node/raw", -1)
    assert_equals("task/detail", prev_lens, "Should cycle to task/detail")
  end)

  test("cycles backward from task/detail to task/brief", function()
    local prev_lens = lens.cycle_lens("task/detail", -1)
    assert_equals("task/brief", prev_lens, "Should cycle to task/brief")
  end)

  test("defaults to forward cycle when direction is 0", function()
    local next_lens = lens.cycle_lens("task/brief", 0)
    assert_equals("task/detail", next_lens, "Should default to forward")
  end)

  test("handles unknown lens by returning first lens", function()
    local next_lens = lens.cycle_lens("unknown/lens", 1)
    assert_equals("task/brief", next_lens, "Should return first lens on unknown")
  end)
end)

describe("Render with fallback", function()
  test("falls back to node/raw for unsupported lens", function()
    local node = {
      type = "task",
      body_md = "- [ ] Task content",
      props = { state = "todo" }
    }
    local result = lens.render(node, "unsupported/lens")
    -- Should fall back to node/raw
    assert_equals("- [ ] Task content", result,
      "Should fall back to raw rendering")
  end)

  test("handles node without body_md", function()
    local node = {
      type = "task",
      props = { state = "todo" }
    }
    local result = lens.render(node, "node/raw")
    assert_equals("", result, "Should return empty string for missing body_md")
  end)
end)

-- Summary
print("\n=== Summary ===")
print(string.format("Total: %d", test_count))
print(string.format("Passed: %d", pass_count))
print(string.format("Failed: %d", fail_count))

-- Exit with appropriate code
if fail_count > 0 then
  os.exit(1)
else
  os.exit(0)
end
