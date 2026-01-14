#!/usr/bin/env -S nvim -l

-- References (find references / quickfix) tests

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
local references = require('lifemode.references')

describe("Extract Target Under Cursor", function()
  test("extracts wikilink target under cursor", function()
    local bufnr = create_test_buffer({ "- Item with [[Page]] link" })
    -- Cursor at column 14 (inside [[Page]])
    local target, ref_type = references.extract_target_at_cursor(bufnr, 1, 14)
    assert_equals("Page", target)
    assert_equals("wikilink", ref_type)
  end)

  test("extracts wikilink with heading under cursor", function()
    local bufnr = create_test_buffer({ "See [[Page#Heading]] for details" })
    -- Cursor at column 7 (inside [[Page#Heading]])
    local target, ref_type = references.extract_target_at_cursor(bufnr, 1, 7)
    assert_equals("Page#Heading", target)
    assert_equals("wikilink", ref_type)
  end)

  test("extracts wikilink with block ref under cursor", function()
    local bufnr = create_test_buffer({ "Ref: [[Page^block-id]]" })
    -- Cursor at column 9 (inside [[Page^block-id]])
    local target, ref_type = references.extract_target_at_cursor(bufnr, 1, 9)
    assert_equals("Page^block-id", target)
    assert_equals("wikilink", ref_type)
  end)

  test("extracts Bible reference under cursor", function()
    local bufnr = create_test_buffer({ "Read John 3:16 today" })
    -- Cursor at column 7 (inside John 3:16)
    local target, ref_type = references.extract_target_at_cursor(bufnr, 1, 7)
    assert_equals("bible:john:3:16", target)
    assert_equals("bible_verse", ref_type)
  end)

  test("extracts Bible range reference under cursor", function()
    local bufnr = create_test_buffer({ "Romans 8:28-30 is key" })
    -- Cursor at column 2 (inside Romans 8:28-30)
    -- Should extract first verse of range as target
    local target, ref_type = references.extract_target_at_cursor(bufnr, 1, 2)
    assert_equals("bible:romans:8:28", target)
    assert_equals("bible_verse", ref_type)
  end)

  test("returns nil when cursor not on a link", function()
    local bufnr = create_test_buffer({ "Just plain text here" })
    local target, ref_type = references.extract_target_at_cursor(bufnr, 1, 5)
    assert_nil(target)
    assert_nil(ref_type)
  end)

  test("returns nil for empty line", function()
    local bufnr = create_test_buffer({ "" })
    local target, ref_type = references.extract_target_at_cursor(bufnr, 1, 0)
    assert_nil(target)
    assert_nil(ref_type)
  end)
end)

describe("Find References in Buffer", function()
  test("finds all wikilink references to target", function()
    local bufnr = create_test_buffer({
      "# Heading with [[Page]] link",
      "- Task referencing [[Page]]",
      "- Another task with [[Other]]",
      "  - Nested [[Page]] reference",
    })

    local refs = references.find_references_in_buffer(bufnr, "Page", "wikilink")

    -- Should find 3 references (lines 1, 2, 4)
    assert_equals(3, #refs)
    assert_equals(1, refs[1].lnum)
    assert_equals(2, refs[2].lnum)
    assert_equals(4, refs[3].lnum)
  end)

  test("finds Bible verse references", function()
    local bufnr = create_test_buffer({
      "- Task: read John 3:16",
      "- See also John 3:16-17",
      "- Compare with Rom 8:28",
    })

    local refs = references.find_references_in_buffer(bufnr, "bible:john:3:16", "bible_verse")

    -- Should find 2 references (lines 1 and 2, since 8:28-30 expands to include 8:28)
    assert_equals(2, #refs)
    assert_equals(1, refs[1].lnum)
    assert_equals(2, refs[2].lnum)
  end)

  test("returns empty array when no references found", function()
    local bufnr = create_test_buffer({
      "- Task with [[Other]] link",
      "- No references to target",
    })

    local refs = references.find_references_in_buffer(bufnr, "Page", "wikilink")
    assert_equals(0, #refs)
  end)

  test("finds multiple references in same line", function()
    local bufnr = create_test_buffer({
      "Compare [[Page]] with [[Page]] for consistency",
    })

    local refs = references.find_references_in_buffer(bufnr, "Page", "wikilink")

    -- Should find 2 references, both on line 1
    assert_equals(2, #refs)
    assert_equals(1, refs[1].lnum)
    assert_equals(1, refs[2].lnum)
    -- Columns should be different
    assert_true(refs[1].col ~= refs[2].col, "Columns should differ for multiple refs on same line")
  end)

  test("includes correct text preview in reference", function()
    local bufnr = create_test_buffer({
      "- Task with [[Page]] link",
    })

    local refs = references.find_references_in_buffer(bufnr, "Page", "wikilink")

    assert_equals(1, #refs)
    assert_equals("- Task with [[Page]] link", refs[1].text)
  end)
end)

describe("Populate Quickfix List", function()
  test("populates quickfix with reference locations", function()
    local bufnr = create_test_buffer({
      "# Heading with [[Page]]",
      "- Task with [[Page]]",
    })

    -- Clear quickfix
    vim.fn.setqflist({}, 'r')

    local refs = references.find_references_in_buffer(bufnr, "Page", "wikilink")
    references.populate_quickfix(refs, bufnr, "Page")

    local qflist = vim.fn.getqflist()
    assert_equals(2, #qflist)
    assert_equals(bufnr, qflist[1].bufnr)
    assert_equals(1, qflist[1].lnum)
    assert_equals(bufnr, qflist[2].bufnr)
    assert_equals(2, qflist[2].lnum)
  end)

  test("sets quickfix title with target", function()
    local bufnr = create_test_buffer({
      "- Task with [[Page]]",
    })

    vim.fn.setqflist({}, 'r')

    local refs = references.find_references_in_buffer(bufnr, "Page", "wikilink")
    references.populate_quickfix(refs, bufnr, "Page")

    local qflist_info = vim.fn.getqflist({ title = 1 })
    assert_true(qflist_info.title:find("References to: Page"), "Quickfix title should include target")
  end)

  test("handles empty reference list", function()
    local bufnr = create_test_buffer({ "- No references" })

    vim.fn.setqflist({}, 'r')

    local refs = references.find_references_in_buffer(bufnr, "Page", "wikilink")
    references.populate_quickfix(refs, bufnr, "Page")

    local qflist = vim.fn.getqflist()
    assert_equals(0, #qflist)
  end)
end)

describe("Find References at Cursor (Integration)", function()
  test("finds references for wikilink at cursor", function()
    local bufnr = create_test_buffer({
      "# Heading with [[Page]]",
      "- Task with [[Page]]",
      "- See [[Other]]",
    })

    -- Set cursor to line 1, column 18 (inside [[Page]])
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_win_set_cursor(0, {1, 17})

    -- Clear quickfix
    vim.fn.setqflist({}, 'r')

    references.find_references_at_cursor()

    local qflist = vim.fn.getqflist()
    assert_equals(2, #qflist)
  end)

  test("shows message when cursor not on link", function()
    local bufnr = create_test_buffer({ "Just plain text" })

    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_win_set_cursor(0, {1, 5})

    -- Should not error, just show message (test that it doesn't crash)
    assert_no_error(function()
      references.find_references_at_cursor()
    end)
  end)

  test("shows message when no references found", function()
    local bufnr = create_test_buffer({
      "- Only reference is [[Unique]]",
      "- No other mentions",
    })

    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_win_set_cursor(0, {1, 20})

    vim.fn.setqflist({}, 'r')

    assert_no_error(function()
      references.find_references_at_cursor()
    end)

    -- Should populate quickfix with single entry (the reference itself)
    local qflist = vim.fn.getqflist()
    assert_equals(1, #qflist)
  end)
end)

-- Summary
print(string.format("\n========================================"))
print(string.format("Tests run: %d", test_count))
print(string.format("Passed: %d", pass_count))
print(string.format("Failed: %d", fail_count))
print(string.format("========================================"))

if fail_count > 0 then
  os.exit(1)
else
  os.exit(0)
end
