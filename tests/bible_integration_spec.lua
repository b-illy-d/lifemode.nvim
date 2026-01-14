#!/usr/bin/env -S nvim -l

-- Bible reference integration tests
-- Tests that Bible refs are extracted and added to node refs

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

-- Load the module
local node = require('lifemode.node')

describe("Bible Reference Integration - Single Verses", function()
  test("extracts Bible reference from task", function()
    local bufnr = create_test_buffer({
      "- [ ] Read John 3:16 ^t1"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["t1"]
    assert_true(n ~= nil, "Node should exist")
    assert_equals(1, #n.refs)
    assert_equals("bible:john:3:16", n.refs[1].target)
    assert_equals("bible_verse", n.refs[1].type)
  end)

  test("extracts abbreviated book name", function()
    local bufnr = create_test_buffer({
      "- Study Rom 8:28 ^i1"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["i1"]
    assert_equals(1, #n.refs)
    assert_equals("bible:romans:8:28", n.refs[1].target)
  end)

  test("extracts multiple Bible refs from same node", function()
    local bufnr = create_test_buffer({
      "- Compare Gen 1:1 with John 1:1 ^i1"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["i1"]
    assert_equals(2, #n.refs)
    assert_equals("bible:genesis:1:1", n.refs[1].target)
    assert_equals("bible:john:1:1", n.refs[2].target)
  end)
end)

describe("Bible Reference Integration - Verse Ranges", function()
  test("expands verse range to individual verses", function()
    local bufnr = create_test_buffer({
      "- Read John 17:18-20 ^i1"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["i1"]
    assert_equals(3, #n.refs)
    assert_equals("bible:john:17:18", n.refs[1].target)
    assert_equals("bible:john:17:19", n.refs[2].target)
    assert_equals("bible:john:17:20", n.refs[3].target)
  end)
end)

describe("Bible Reference Integration - Backlinks", function()
  test("builds backlinks for Bible references", function()
    local bufnr = create_test_buffer({
      "- Study John 3:16 ^i1",
      "- Memorize John 3:16 ^i2"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    -- Both nodes should reference the same verse
    local backlinks = result.backlinks["bible:john:3:16"]
    assert_true(backlinks ~= nil, "Backlinks should exist for bible:john:3:16")
    assert_equals(2, #backlinks)
    assert_true(backlinks[1] == "i1" or backlinks[1] == "i2", "Backlink should be i1 or i2")
    assert_true(backlinks[2] == "i1" or backlinks[2] == "i2", "Backlink should be i1 or i2")
  end)

  test("builds backlinks for verse ranges", function()
    local bufnr = create_test_buffer({
      "- Read John 17:18-20 ^i1"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    -- Each verse in range should have backlink to i1
    assert_true(result.backlinks["bible:john:17:18"] ~= nil)
    assert_equals(1, #result.backlinks["bible:john:17:18"])
    assert_equals("i1", result.backlinks["bible:john:17:18"][1])

    assert_true(result.backlinks["bible:john:17:19"] ~= nil)
    assert_equals("i1", result.backlinks["bible:john:17:19"][1])

    assert_true(result.backlinks["bible:john:17:20"] ~= nil)
    assert_equals("i1", result.backlinks["bible:john:17:20"][1])
  end)
end)

describe("Bible Reference Integration - Mixed Refs", function()
  test("extracts both wikilinks and Bible refs", function()
    local bufnr = create_test_buffer({
      "- See [[Gospel Study]] and John 3:16 ^i1"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["i1"]
    assert_equals(2, #n.refs)

    -- Find wikilink and bible ref (order may vary)
    local has_wikilink = false
    local has_bible = false
    for _, ref in ipairs(n.refs) do
      if ref.type == "wikilink" and ref.target == "Gospel Study" then
        has_wikilink = true
      end
      if ref.type == "bible_verse" and ref.target == "bible:john:3:16" then
        has_bible = true
      end
    end
    assert_true(has_wikilink, "Should have wikilink")
    assert_true(has_bible, "Should have Bible ref")
  end)
end)

describe("Bible Reference Integration - No Refs", function()
  test("node without Bible refs has empty refs list", function()
    local bufnr = create_test_buffer({
      "- Just a plain task ^i1"
    })
    local result = node.build_nodes_from_buffer(bufnr)

    local n = result.nodes_by_id["i1"]
    assert_equals(0, #n.refs)
  end)
end)

-- Print summary
print(string.format("\n========================================"))
print(string.format("Tests: %d, Pass: %d, Fail: %d", test_count, pass_count, fail_count))
print(string.format("========================================\n"))

if fail_count > 0 then
  os.exit(1)
end
