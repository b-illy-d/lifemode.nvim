#!/usr/bin/env -S nvim -l

-- Wikilink extraction and refs tests

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

describe("Wikilink Extraction - Simple Page Links", function()
  test("extracts simple page link [[Page]]", function()
    local bufnr = create_test_buffer({ "- Item with [[Page]] link ^i1" })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["i1"]
    assert_true(n.refs ~= nil, "Node should have refs field")
    assert_equals(1, #n.refs)
    assert_equals("Page", n.refs[1].target)
    assert_equals("wikilink", n.refs[1].type)
  end)

  test("extracts multiple page links", function()
    local bufnr = create_test_buffer({ "- Item with [[Page1]] and [[Page2]] ^i1" })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["i1"]
    assert_equals(2, #n.refs)
    assert_equals("Page1", n.refs[1].target)
    assert_equals("Page2", n.refs[2].target)
  end)

  test("node without links has empty refs", function()
    local bufnr = create_test_buffer({ "- Item without links ^i1" })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["i1"]
    assert_true(n.refs ~= nil, "Node should have refs field")
    assert_equals(0, #n.refs)
  end)
end)

describe("Wikilink Extraction - Heading and Block References", function()
  test("extracts heading reference [[Page#Heading]]", function()
    local bufnr = create_test_buffer({ "- See [[Page#Introduction]] ^i1" })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["i1"]
    assert_equals(1, #n.refs)
    assert_equals("Page#Introduction", n.refs[1].target)
    assert_equals("wikilink", n.refs[1].type)
  end)

  test("extracts block reference [[Page^block-id]]", function()
    local bufnr = create_test_buffer({ "- See [[Page^abc123]] ^i1" })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["i1"]
    assert_equals(1, #n.refs)
    assert_equals("Page^abc123", n.refs[1].target)
    assert_equals("wikilink", n.refs[1].type)
  end)

  test("extracts heading with spaces [[Page#Multiple Words]]", function()
    local bufnr = create_test_buffer({ "- See [[Page#Multiple Words Here]] ^i1" })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["i1"]
    assert_equals(1, #n.refs)
    assert_equals("Page#Multiple Words Here", n.refs[1].target)
  end)

  test("handles mixed link types", function()
    local bufnr = create_test_buffer({
      "- Links: [[Page1]], [[Page2#Heading]], [[Page3^id]] ^i1"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["i1"]
    assert_equals(3, #n.refs)
    assert_equals("Page1", n.refs[1].target)
    assert_equals("Page2#Heading", n.refs[2].target)
    assert_equals("Page3^id", n.refs[3].target)
  end)
end)

describe("Backlinks Index", function()
  test("builds backlinks map for single link", function()
    local bufnr = create_test_buffer({ "- Link to [[Target]] ^i1" })
    local result = node.build_nodes_from_buffer(bufnr)

    assert_true(result.backlinks ~= nil, "Should have backlinks map")
    assert_true(result.backlinks["Target"] ~= nil, "Should have entry for Target")
    assert_equals(1, #result.backlinks["Target"])
    assert_equals("i1", result.backlinks["Target"][1])
  end)

  test("builds backlinks for multiple sources", function()
    local bufnr = create_test_buffer({
      "- First link to [[Target]] ^i1",
      "- Second link to [[Target]] ^i2"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    assert_equals(2, #result.backlinks["Target"])
    assert_equals("i1", result.backlinks["Target"][1])
    assert_equals("i2", result.backlinks["Target"][2])
  end)

  test("handles multiple targets from one source", function()
    local bufnr = create_test_buffer({
      "- Links to [[Target1]] and [[Target2]] ^i1"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    assert_equals(1, #result.backlinks["Target1"])
    assert_equals(1, #result.backlinks["Target2"])
    assert_equals("i1", result.backlinks["Target1"][1])
    assert_equals("i1", result.backlinks["Target2"][1])
  end)

  test("handles heading refs in backlinks by base page", function()
    local bufnr = create_test_buffer({
      "- Link to [[Page#Heading]] ^i1"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    -- Should index by full target including heading
    assert_true(result.backlinks["Page#Heading"] ~= nil, "Should index by full target")
    assert_equals(1, #result.backlinks["Page#Heading"])
  end)

  test("handles block refs in backlinks", function()
    local bufnr = create_test_buffer({
      "- Link to [[Page^block123]] ^i1"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    assert_true(result.backlinks["Page^block123"] ~= nil, "Should index by full target")
    assert_equals(1, #result.backlinks["Page^block123"])
  end)

  test("empty buffer has empty backlinks", function()
    local bufnr = create_test_buffer({})
    local result = node.build_nodes_from_buffer(bufnr)

    assert_true(result.backlinks ~= nil, "Should have backlinks map")
    assert_equals(0, vim.tbl_count(result.backlinks))
  end)
end)

describe("Edge Cases", function()
  test("handles link in heading text", function()
    local bufnr = create_test_buffer({ "# Heading with [[Link]] ^h1" })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["h1"]
    assert_equals(1, #n.refs)
    assert_equals("Link", n.refs[1].target)
  end)

  test("handles empty link brackets [[]]", function()
    local bufnr = create_test_buffer({ "- Item with [[]] empty ^i1" })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["i1"]
    -- Should not create ref for empty brackets
    assert_equals(0, #n.refs)
  end)

  test("handles incomplete link [[ without closing", function()
    local bufnr = create_test_buffer({ "- Item with [[ incomplete ^i1" })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["i1"]
    assert_equals(0, #n.refs)
  end)

  test("handles link with special characters [[Page-Name_123]]", function()
    local bufnr = create_test_buffer({ "- Link [[Page-Name_123]] ^i1" })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["i1"]
    assert_equals(1, #n.refs)
    assert_equals("Page-Name_123", n.refs[1].target)
  end)

  test("handles nested brackets [[Page [[nested]]]]", function()
    local bufnr = create_test_buffer({ "- Link [[Page]] and [[nested]] ^i1" })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["i1"]
    -- Should extract both valid links
    assert_equals(2, #n.refs)
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
