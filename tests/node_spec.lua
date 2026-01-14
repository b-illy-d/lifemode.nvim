#!/usr/bin/env -S nvim -l

-- Node model tests

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
local node = require('lifemode.node')

describe("node.build_nodes_from_buffer - Basic Functionality", function()
  test("returns empty structure for empty buffer", function()
    local bufnr = create_test_buffer({})
    local result = node.build_nodes_from_buffer(bufnr)
    assert_true(result.nodes_by_id ~= nil, "nodes_by_id should exist")
    assert_true(result.root_ids ~= nil, "root_ids should exist")
    assert_equals(0, vim.tbl_count(result.nodes_by_id))
    assert_equals(0, #result.root_ids)
  end)

  test("handles single task node", function()
    local bufnr = create_test_buffer({ "- [ ] Task one ^abc123" })
    local result = node.build_nodes_from_buffer(bufnr)

    -- Should have one node
    assert_equals(1, vim.tbl_count(result.nodes_by_id))
    assert_equals(1, #result.root_ids)
    assert_equals("abc123", result.root_ids[1])

    -- Check node structure
    local n = result.nodes_by_id["abc123"]
    assert_equals("abc123", n.id)
    assert_equals("task", n.type)
    assert_equals("- [ ] Task one ^abc123", n.body_md)
    assert_equals(0, #n.children)
  end)

  test("handles task without ID", function()
    local bufnr = create_test_buffer({ "- [ ] Task without ID" })
    local result = node.build_nodes_from_buffer(bufnr)

    -- Should have one node with generated ID
    assert_equals(1, vim.tbl_count(result.nodes_by_id))
    assert_equals(1, #result.root_ids)

    -- Should have auto-generated ID
    local node_id = result.root_ids[1]
    assert_true(node_id ~= nil and node_id ~= "", "Should have auto-generated ID")

    local n = result.nodes_by_id[node_id]
    assert_equals("task", n.type)
    assert_equals("- [ ] Task without ID", n.body_md)
  end)

  test("handles heading node", function()
    local bufnr = create_test_buffer({ "# Main heading ^head1" })
    local result = node.build_nodes_from_buffer(bufnr)

    assert_equals(1, vim.tbl_count(result.nodes_by_id))
    assert_equals("head1", result.root_ids[1])

    local n = result.nodes_by_id["head1"]
    assert_equals("heading", n.type)
    assert_equals("# Main heading ^head1", n.body_md)
    assert_equals(0, #n.children)
  end)

  test("handles list item node", function()
    local bufnr = create_test_buffer({ "- Regular list item ^item1" })
    local result = node.build_nodes_from_buffer(bufnr)

    assert_equals(1, vim.tbl_count(result.nodes_by_id))
    assert_equals("item1", result.root_ids[1])

    local n = result.nodes_by_id["item1"]
    assert_equals("list_item", n.type)
    assert_equals("- Regular list item ^item1", n.body_md)
    assert_equals(0, #n.children)
  end)
end)

describe("node.build_nodes_from_buffer - Heading Hierarchy", function()
  test("builds two-level heading hierarchy", function()
    local bufnr = create_test_buffer({
      "# Level 1 ^h1",
      "## Level 2 ^h2"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    -- Should have 2 nodes, 1 root
    assert_equals(2, vim.tbl_count(result.nodes_by_id))
    assert_equals(1, #result.root_ids)
    assert_equals("h1", result.root_ids[1])

    -- h1 should have h2 as child
    local h1 = result.nodes_by_id["h1"]
    assert_equals(1, #h1.children)
    assert_equals("h2", h1.children[1])

    -- h2 should have no children
    local h2 = result.nodes_by_id["h2"]
    assert_equals(0, #h2.children)
  end)

  test("builds three-level heading hierarchy", function()
    local bufnr = create_test_buffer({
      "# Level 1 ^h1",
      "## Level 2 ^h2",
      "### Level 3 ^h3"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    assert_equals(3, vim.tbl_count(result.nodes_by_id))
    assert_equals(1, #result.root_ids)

    -- h1 → h2 → h3
    local h1 = result.nodes_by_id["h1"]
    assert_equals(1, #h1.children)
    assert_equals("h2", h1.children[1])

    local h2 = result.nodes_by_id["h2"]
    assert_equals(1, #h2.children)
    assert_equals("h3", h2.children[1])

    local h3 = result.nodes_by_id["h3"]
    assert_equals(0, #h3.children)
  end)

  test("handles multiple children at same level", function()
    local bufnr = create_test_buffer({
      "# Level 1 ^h1",
      "## Child 1 ^h2",
      "## Child 2 ^h3"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    assert_equals(3, vim.tbl_count(result.nodes_by_id))
    assert_equals(1, #result.root_ids)

    -- h1 should have two children
    local h1 = result.nodes_by_id["h1"]
    assert_equals(2, #h1.children)
    assert_equals("h2", h1.children[1])
    assert_equals("h3", h1.children[2])
  end)

  test("handles heading level skip back (## → #)", function()
    local bufnr = create_test_buffer({
      "# First root ^h1",
      "## Child of first ^h2",
      "# Second root ^h3"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    assert_equals(3, vim.tbl_count(result.nodes_by_id))
    assert_equals(2, #result.root_ids)
    assert_equals("h1", result.root_ids[1])
    assert_equals("h3", result.root_ids[2])

    -- h1 has h2 as child
    local h1 = result.nodes_by_id["h1"]
    assert_equals(1, #h1.children)

    -- h3 has no children
    local h3 = result.nodes_by_id["h3"]
    assert_equals(0, #h3.children)
  end)
end)

describe("node.build_nodes_from_buffer - List Indentation", function()
  test("builds two-level list hierarchy", function()
    local bufnr = create_test_buffer({
      "- Item 1 ^i1",
      "  - Item 1.1 ^i2"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    assert_equals(2, vim.tbl_count(result.nodes_by_id))
    assert_equals(1, #result.root_ids)

    -- i1 should have i2 as child
    local i1 = result.nodes_by_id["i1"]
    assert_equals(1, #i1.children)
    assert_equals("i2", i1.children[1])
  end)

  test("builds three-level list hierarchy", function()
    local bufnr = create_test_buffer({
      "- Item 1 ^i1",
      "  - Item 1.1 ^i2",
      "    - Item 1.1.1 ^i3"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    assert_equals(3, vim.tbl_count(result.nodes_by_id))
    assert_equals(1, #result.root_ids)

    -- i1 → i2 → i3
    local i1 = result.nodes_by_id["i1"]
    assert_equals(1, #i1.children)

    local i2 = result.nodes_by_id["i2"]
    assert_equals(1, #i2.children)

    local i3 = result.nodes_by_id["i3"]
    assert_equals(0, #i3.children)
  end)

  test("handles dedent back to root level", function()
    local bufnr = create_test_buffer({
      "- Item 1 ^i1",
      "  - Item 1.1 ^i2",
      "- Item 2 ^i3"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    assert_equals(3, vim.tbl_count(result.nodes_by_id))
    assert_equals(2, #result.root_ids)
    assert_equals("i1", result.root_ids[1])
    assert_equals("i3", result.root_ids[2])

    -- i1 has i2 as child
    local i1 = result.nodes_by_id["i1"]
    assert_equals(1, #i1.children)

    -- i3 has no children
    local i3 = result.nodes_by_id["i3"]
    assert_equals(0, #i3.children)
  end)

  test("tasks with indentation form hierarchy", function()
    local bufnr = create_test_buffer({
      "- [ ] Parent task ^t1",
      "  - [ ] Child task ^t2"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    assert_equals(2, vim.tbl_count(result.nodes_by_id))
    assert_equals(1, #result.root_ids)

    local t1 = result.nodes_by_id["t1"]
    assert_equals("task", t1.type)
    assert_equals(1, #t1.children)
    assert_equals("t2", t1.children[1])
  end)
end)

describe("node.build_nodes_from_buffer - Mixed Content", function()
  test("handles mixed headings and lists", function()
    local bufnr = create_test_buffer({
      "# Heading ^h1",
      "- List item under heading ^i1",
      "## Subheading ^h2",
      "- List under subheading ^i2"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    assert_equals(4, vim.tbl_count(result.nodes_by_id))
    assert_equals(1, #result.root_ids)

    -- h1 is root with i1 and h2 as children
    local h1 = result.nodes_by_id["h1"]
    assert_equals(2, #h1.children)
    assert_equals("i1", h1.children[1])
    assert_equals("h2", h1.children[2])

    -- h2 has i2 as child
    local h2 = result.nodes_by_id["h2"]
    assert_equals(1, #h2.children)
    assert_equals("i2", h2.children[1])
  end)

  test("heading resets list context", function()
    local bufnr = create_test_buffer({
      "- List item ^i1",
      "  - Nested ^i2",
      "# Heading ^h1",
      "- New list ^i3"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    assert_equals(4, vim.tbl_count(result.nodes_by_id))
    assert_equals(2, #result.root_ids)
    assert_equals("i1", result.root_ids[1])
    assert_equals("h1", result.root_ids[2])

    -- h1 should have i3 as child
    local h1 = result.nodes_by_id["h1"]
    assert_equals(1, #h1.children)
    assert_equals("i3", h1.children[1])
  end)
end)

-- Print summary
print(string.format("\n========================================"))
print(string.format("Tests: %d, Pass: %d, Fail: %d", test_count, pass_count, fail_count))
print(string.format("========================================\n"))

-- Exit with appropriate code
if fail_count > 0 then
  os.exit(1)
else
  os.exit(0)
end
