#!/usr/bin/env -S nvim -l

-- Navigation (goto definition) tests

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

-- Helper to create temporary test file
local function create_temp_file(path, content)
  local f = io.open(path, 'w')
  f:write(content)
  f:close()
end

-- Helper to remove file
local function remove_file(path)
  os.remove(path)
end

-- Add lua directory to package path
package.path = package.path .. ';lua/?.lua;lua/?/init.lua'

-- Initialize lifemode with test vault
local lifemode = require('lifemode')
lifemode.setup({ vault_root = '/tmp/lifemode_test_vault' })

-- Run tests
local navigation = require('lifemode.navigation')

describe("Parse Wikilink Target", function()
  test("parses simple page name", function()
    local page, heading, block_id = navigation.parse_wikilink_target("Page")
    assert_equals("Page", page)
    assert_nil(heading)
    assert_nil(block_id)
  end)

  test("parses page with heading", function()
    local page, heading, block_id = navigation.parse_wikilink_target("Page#Heading")
    assert_equals("Page", page)
    assert_equals("Heading", heading)
    assert_nil(block_id)
  end)

  test("parses page with block ref", function()
    local page, heading, block_id = navigation.parse_wikilink_target("Page^block-123")
    assert_equals("Page", page)
    assert_nil(heading)
    assert_equals("block-123", block_id)
  end)

  test("handles page with spaces", function()
    local page, heading, block_id = navigation.parse_wikilink_target("My Page Name")
    assert_equals("My Page Name", page)
    assert_nil(heading)
    assert_nil(block_id)
  end)

  test("handles heading with spaces", function()
    local page, heading, block_id = navigation.parse_wikilink_target("Page#My Heading")
    assert_equals("Page", page)
    assert_equals("My Heading", heading)
    assert_nil(block_id)
  end)
end)

describe("Find File in Vault", function()
  test("finds exact match .md file", function()
    -- Create test file
    os.execute('mkdir -p /tmp/lifemode_test_vault')
    create_temp_file('/tmp/lifemode_test_vault/TestPage.md', '# Test Page')

    local found = navigation.find_file_in_vault("TestPage")
    assert_equals("/tmp/lifemode_test_vault/TestPage.md", found)

    -- Cleanup
    remove_file('/tmp/lifemode_test_vault/TestPage.md')
  end)

  test("returns nil if file not found", function()
    local found = navigation.find_file_in_vault("NonExistentPage")
    assert_nil(found)
  end)

  test("finds file in subdirectory", function()
    -- Create test file in subdirectory
    os.execute('mkdir -p /tmp/lifemode_test_vault/subdir')
    create_temp_file('/tmp/lifemode_test_vault/subdir/SubPage.md', '# Sub Page')

    local found = navigation.find_file_in_vault("SubPage")
    assert_equals("/tmp/lifemode_test_vault/subdir/SubPage.md", found)

    -- Cleanup
    remove_file('/tmp/lifemode_test_vault/subdir/SubPage.md')
  end)

  test("handles page names with spaces", function()
    -- Create test file with spaces
    os.execute('mkdir -p /tmp/lifemode_test_vault')
    create_temp_file('/tmp/lifemode_test_vault/My Page.md', '# My Page')

    local found = navigation.find_file_in_vault("My Page")
    assert_equals("/tmp/lifemode_test_vault/My Page.md", found)

    -- Cleanup
    remove_file('/tmp/lifemode_test_vault/My Page.md')
  end)
end)

describe("Jump to Heading", function()
  test("jumps to heading in buffer", function()
    local bufnr = create_test_buffer({
      "# First Heading",
      "Content here",
      "## Second Heading",
      "More content",
    })

    local found = navigation.jump_to_heading(bufnr, "Second Heading")
    assert_true(found)

    -- Check cursor moved to line 3
    local cursor = vim.api.nvim_win_get_cursor(0)
    assert_equals(3, cursor[1])
  end)

  test("returns false if heading not found", function()
    local bufnr = create_test_buffer({
      "# First Heading",
      "Content here",
    })

    local found = navigation.jump_to_heading(bufnr, "Missing Heading")
    assert_true(not found)
  end)

  test("handles heading with special characters", function()
    local bufnr = create_test_buffer({
      "# Heading: With Special (Chars)",
      "Content",
    })

    local found = navigation.jump_to_heading(bufnr, "Heading: With Special (Chars)")
    assert_true(found)

    local cursor = vim.api.nvim_win_get_cursor(0)
    assert_equals(1, cursor[1])
  end)
end)

describe("Jump to Block ID", function()
  test("jumps to block with ID in buffer", function()
    local bufnr = create_test_buffer({
      "First line",
      "- Task item ^task-123",
      "Third line",
    })

    local found = navigation.jump_to_block_id(bufnr, "task-123")
    assert_true(found)

    -- Check cursor moved to line 2
    local cursor = vim.api.nvim_win_get_cursor(0)
    assert_equals(2, cursor[1])
  end)

  test("returns false if block ID not found", function()
    local bufnr = create_test_buffer({
      "First line",
      "- Task item ^task-123",
    })

    local found = navigation.jump_to_block_id(bufnr, "missing-id")
    assert_true(not found)
  end)

  test("handles UUID block IDs", function()
    local bufnr = create_test_buffer({
      "# Heading",
      "- Task with UUID ^550e8400-e29b-41d4-a716-446655440000",
      "More content",
    })

    local found = navigation.jump_to_block_id(bufnr, "550e8400-e29b-41d4-a716-446655440000")
    assert_true(found)

    local cursor = vim.api.nvim_win_get_cursor(0)
    assert_equals(2, cursor[1])
  end)
end)

describe("Goto Definition", function()
  test("handles simple wikilink navigation", function()
    -- Create test files
    os.execute('mkdir -p /tmp/lifemode_test_vault')
    create_temp_file('/tmp/lifemode_test_vault/Source.md', 'Link to [[Target]]')
    create_temp_file('/tmp/lifemode_test_vault/Target.md', '# Target Page')

    -- Create buffer with source content
    local bufnr = create_test_buffer({ "Link to [[Target]]" })
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_win_set_cursor(0, {1, 12})  -- Cursor inside [[Target]]

    -- Call goto_definition
    assert_no_error(function()
      navigation.goto_definition()
    end)

    -- Cleanup
    remove_file('/tmp/lifemode_test_vault/Source.md')
    remove_file('/tmp/lifemode_test_vault/Target.md')
  end)

  test("shows message if file not found", function()
    local bufnr = create_test_buffer({ "Link to [[MissingPage]]" })
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_win_set_cursor(0, {1, 12})

    -- Should not error, just show message
    assert_no_error(function()
      navigation.goto_definition()
    end)
  end)

  test("shows Bible verse message (provider stub)", function()
    local bufnr = create_test_buffer({ "See John 3:16 for details" })
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_win_set_cursor(0, {1, 6})  -- Cursor on "John 3:16"

    -- Should show message about Bible provider
    assert_no_error(function()
      navigation.goto_definition()
    end)
  end)

  test("shows message if no target under cursor", function()
    local bufnr = create_test_buffer({ "Plain text with no links" })
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_win_set_cursor(0, {1, 5})

    assert_no_error(function()
      navigation.goto_definition()
    end)
  end)
end)

-- Cleanup test vault directory
os.execute('rm -rf /tmp/lifemode_test_vault')

-- Print summary
print(string.format("\n%d tests: %d passed, %d failed", test_count, pass_count, fail_count))
if fail_count > 0 then
  os.exit(1)
end
