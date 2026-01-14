#!/usr/bin/env -S nvim -l

-- Manual acceptance test for T16: Tag add/remove
-- This creates a test file and demonstrates tag operations

local test_count = 0
local pass_count = 0

local function test(name, fn)
  test_count = test_count + 1
  io.write(string.format("  [%d] %s ... ", test_count, name))
  io.flush()

  local ok, err = pcall(fn)
  if ok then
    pass_count = pass_count + 1
    print("PASS")
  else
    print(string.format("FAIL\n      %s", err))
  end
end

local function describe(name, fn)
  print(string.format("\n%s:", name))
  fn()
end

local function assert_true(condition, msg)
  if not condition then
    error(msg or "Expected true but got false")
  end
end

local function assert_contains(str, pattern, msg)
  if not str:match(pattern) then
    error(msg or string.format("Expected string to contain pattern %s but got: %s", pattern, str))
  end
end

local function assert_not_contains(str, pattern, msg)
  if str:match(pattern) then
    error(msg or string.format("Expected string not to contain pattern %s but it did: %s", pattern, str))
  end
end

-- Setup
package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
local lifemode = require('lifemode')

lifemode._reset_for_testing()
lifemode.setup({
  vault_root = '/tmp/lifemode_test',
})

describe("T16 Acceptance: Tag add/remove (commanded edit)", function()
  test("get_tags extracts tags from line", function()
    local tasks = require('lifemode.tasks')
    local line = "- [ ] Task #urgent #project/lifemode #work ^test-id"
    local tags = tasks.get_tags(line)

    assert_true(#tags == 3, "Should extract 3 tags")
    assert_true(tags[1] == "urgent" or tags[2] == "urgent" or tags[3] == "urgent", "Should have urgent tag")
    assert_true(tags[1] == "project/lifemode" or tags[2] == "project/lifemode" or tags[3] == "project/lifemode", "Should have hierarchical tag")
  end)

  test("add_tag adds tag to task", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task without tags ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    local tasks = require('lifemode.tasks')
    local success = tasks.add_tag(bufnr, "test-id", "urgent")
    assert_true(success, "add_tag should succeed")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    assert_contains(lines[1], "#urgent", "Tag should be added")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("add_tag adds hierarchical tag", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task without tags ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    local tasks = require('lifemode.tasks')
    tasks.add_tag(bufnr, "test-id", "project/lifemode")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    assert_contains(lines[1], "#project/lifemode", "Hierarchical tag should be added")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("add_tag places tag before ID", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    local tasks = require('lifemode.tasks')
    tasks.add_tag(bufnr, "test-id", "urgent")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    assert_contains(lines[1], "#urgent.*%^test%-id", "Tag should appear before ID")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("add_tag does not add duplicate", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task #urgent ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    local tasks = require('lifemode.tasks')
    tasks.add_tag(bufnr, "test-id", "urgent")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    local tags = tasks.get_tags(lines[1])
    assert_true(#tags == 1, "Should not duplicate tag")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("remove_tag removes tag from task", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task #urgent #project ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    local tasks = require('lifemode.tasks')
    local success = tasks.remove_tag(bufnr, "test-id", "urgent")
    assert_true(success, "remove_tag should succeed")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    assert_not_contains(lines[1], "#urgent", "Tag should be removed")
    assert_contains(lines[1], "#project", "Other tag should remain")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("remove_tag handles hierarchical tags", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task #project/lifemode #area/coding ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    local tasks = require('lifemode.tasks')
    tasks.remove_tag(bufnr, "test-id", "project/lifemode")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    assert_not_contains(lines[1], "#project/lifemode", "Hierarchical tag should be removed")
    assert_contains(lines[1], "#area/coding", "Other tag should remain")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("remove_tag cleans up spacing", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local content = {
      "# Test",
      "- [ ] Task #urgent #project #work ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    local tasks = require('lifemode.tasks')
    tasks.remove_tag(bufnr, "test-id", "project")

    local lines = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)
    assert_not_contains(lines[1], "%s%s", "Should not have double spaces")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)

  test("commands are registered", function()
    local commands = vim.api.nvim_get_commands({})
    assert_true(commands.LifeModeAddTag ~= nil, ":LifeModeAddTag should be registered")
    assert_true(commands.LifeModeRemoveTag ~= nil, ":LifeModeRemoveTag should be registered")
  end)

  test("keymaps work in vault files", function()
    -- Create a markdown buffer in vault
    local bufnr = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_name(bufnr, "/tmp/lifemode_test/test.md")

    local content = {
      "# Test",
      "- [ ] Task ^test-id"
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

    -- Set filetype (this triggers the FileType autocmd)
    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')

    -- Check that keymap exists
    local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
    local has_tt = false
    for _, map in ipairs(keymaps) do
      if map.lhs == ' tt' then
        has_tt = true
        break
      end
    end

    assert_true(has_tt, "<Space>tt keymap should be set in vault files")

    vim.api.nvim_buf_delete(bufnr, {force = true})
  end)
end)

-- Print summary
print(string.format("\n\nSummary: %d tests, %d passed, %d failed", test_count, pass_count, test_count - pass_count))

-- Exit with appropriate code
if pass_count < test_count then
  os.exit(1)
else
  os.exit(0)
end
