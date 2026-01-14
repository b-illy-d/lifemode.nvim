#!/usr/bin/env -S nvim -l

-- Markdown block parser tests

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

local function describe(name, tests_fn)
  print(string.format("\n%s", name))
  tests_fn()
end

-- Helper to create a test buffer with content
local function create_test_buffer(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

-- Add lua directory to package path
package.path = package.path .. ';lua/?.lua;lua/?/init.lua'

-- Run tests
local parser = require('lifemode.parser')

describe("parser.parse_buffer - Basic Parsing", function()
  test("parses empty buffer", function()
    local bufnr = create_test_buffer({})
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(0, #blocks)
  end)

  test("parses single heading", function()
    local bufnr = create_test_buffer({ "# Heading" })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(1, #blocks)
    assert_equals("heading", blocks[1].type)
    assert_equals(1, blocks[1].line_num)
    assert_equals("# Heading", blocks[1].text)
  end)

  test("parses multiple heading levels", function()
    local bufnr = create_test_buffer({
      "# Heading 1",
      "## Heading 2",
      "### Heading 3",
    })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(3, #blocks)
    assert_equals("# Heading 1", blocks[1].text)
    assert_equals("## Heading 2", blocks[2].text)
    assert_equals("### Heading 3", blocks[3].text)
  end)

  test("parses simple list item", function()
    local bufnr = create_test_buffer({ "- List item" })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(1, #blocks)
    assert_equals("list_item", blocks[1].type)
    assert_equals(1, blocks[1].line_num)
    assert_equals("- List item", blocks[1].text)
  end)

  test("parses list items with * syntax", function()
    local bufnr = create_test_buffer({ "* List item" })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(1, #blocks)
    assert_equals("list_item", blocks[1].type)
    assert_equals("* List item", blocks[1].text)
  end)

  test("ignores non-heading non-list lines", function()
    local bufnr = create_test_buffer({
      "Some text",
      "# Heading",
      "More text",
      "- List item",
      "Even more text",
    })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(2, #blocks)
    assert_equals("heading", blocks[1].type)
    assert_equals("list_item", blocks[2].type)
  end)
end)

describe("parser.parse_buffer - Task Parsing", function()
  test("parses unchecked task", function()
    local bufnr = create_test_buffer({ "- [ ] Task item" })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(1, #blocks)
    assert_equals("task", blocks[1].type)
    assert_equals("todo", blocks[1].task_state)
    assert_equals("- [ ] Task item", blocks[1].text)
  end)

  test("parses checked task", function()
    local bufnr = create_test_buffer({ "- [x] Task item" })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(1, #blocks)
    assert_equals("task", blocks[1].type)
    assert_equals("done", blocks[1].task_state)
    assert_equals("- [x] Task item", blocks[1].text)
  end)

  test("parses task with uppercase X", function()
    local bufnr = create_test_buffer({ "- [X] Task item" })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(1, #blocks)
    assert_equals("task", blocks[1].type)
    assert_equals("done", blocks[1].task_state)
  end)

  test("distinguishes task from regular list item", function()
    local bufnr = create_test_buffer({
      "- Regular list item",
      "- [ ] Task item",
    })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(2, #blocks)
    assert_equals("list_item", blocks[1].type)
    assert_equals(nil, blocks[1].task_state)
    assert_equals("task", blocks[2].type)
    assert_equals("todo", blocks[2].task_state)
  end)

  test("handles task with * syntax", function()
    local bufnr = create_test_buffer({ "* [x] Task item" })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(1, #blocks)
    assert_equals("task", blocks[1].type)
    assert_equals("done", blocks[1].task_state)
  end)
end)

describe("parser.parse_buffer - ID Extraction", function()
  test("extracts ID from heading", function()
    local bufnr = create_test_buffer({ "# Heading ^abc123" })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(1, #blocks)
    assert_equals("abc123", blocks[1].id)
  end)

  test("extracts ID from list item", function()
    local bufnr = create_test_buffer({ "- List item ^def456" })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(1, #blocks)
    assert_equals("def456", blocks[1].id)
  end)

  test("extracts ID from task", function()
    local bufnr = create_test_buffer({ "- [ ] Task item ^task-123" })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(1, #blocks)
    assert_equals("task-123", blocks[1].id)
  end)

  test("extracts UUID format ID", function()
    local bufnr = create_test_buffer({ "# Heading ^550e8400-e29b-41d4-a716-446655440000" })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(1, #blocks)
    assert_equals("550e8400-e29b-41d4-a716-446655440000", blocks[1].id)
  end)

  test("handles block without ID", function()
    local bufnr = create_test_buffer({ "# Heading without ID" })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(1, #blocks)
    assert_equals(nil, blocks[1].id)
  end)

  test("extracts ID at end of line only", function()
    local bufnr = create_test_buffer({ "# ^not-an-id in middle ^real-id" })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(1, #blocks)
    assert_equals("real-id", blocks[1].id)
  end)
end)

describe("parser.parse_buffer - Edge Cases", function()
  test("handles headings with spaces before #", function()
    local bufnr = create_test_buffer({ "  # Heading" })
    local blocks = parser.parse_buffer(bufnr)
    -- Should NOT parse as heading (Markdown requires # at start)
    assert_equals(0, #blocks)
  end)

  test("handles list items with extra spaces", function()
    local bufnr = create_test_buffer({ "-  Extra spaces" })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(1, #blocks)
    assert_equals("list_item", blocks[1].type)
  end)

  test("handles task with no space after checkbox", function()
    local bufnr = create_test_buffer({ "- [ ]No space" })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(1, #blocks)
    assert_equals("task", blocks[1].type)
  end)

  test("handles empty line between blocks", function()
    local bufnr = create_test_buffer({
      "# Heading",
      "",
      "- List item",
    })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(2, #blocks)
    assert_equals(1, blocks[1].line_num)
    assert_equals(3, blocks[2].line_num)
  end)

  test("preserves original line numbers", function()
    local bufnr = create_test_buffer({
      "Text line",
      "# Heading",
      "More text",
      "- List item",
    })
    local blocks = parser.parse_buffer(bufnr)
    assert_equals(2, blocks[1].line_num) -- Heading at line 2
    assert_equals(4, blocks[2].line_num) -- List at line 4
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
