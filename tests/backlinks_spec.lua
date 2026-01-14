#!/usr/bin/env -S nvim -l

-- Tests for backlinks view

-- Add lua directory to package path
package.path = package.path .. ';lua/?.lua;lua/?/init.lua'

local function test(name, fn)
  local status, err = pcall(fn)
  if not status then
    print(string.format("✗ %s\n  %s", name, err))
    os.exit(1)
  else
    print(string.format("✓ %s", name))
  end
end

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", message or "Assertion failed", vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_true(condition, message)
  if not condition then
    error(message or "Expected condition to be true")
  end
end

local function assert_error(fn, expected_pattern)
  local status, err = pcall(fn)
  if status then
    error("Expected function to throw error")
  end
  if expected_pattern and not string.match(err, expected_pattern) then
    error(string.format("Error message doesn't match pattern: %s", err))
  end
end

local function assert_no_error(fn)
  local status, err = pcall(fn)
  if not status then
    error(string.format("Expected no error, got: %s", err))
  end
end

local function describe(name, fn)
  print(string.format("\n=== %s ===", name))
  fn()
end

-- Setup
package.loaded['lifemode'] = nil
package.loaded['lifemode.backlinks'] = nil
package.loaded['lifemode.index'] = nil
package.loaded['lifemode.references'] = nil
package.loaded['lifemode.node'] = nil

local lifemode = require('lifemode')

-- Initialize with test vault
lifemode.setup({
  vault_root = '/tmp/test_vault_backlinks'
})

local backlinks = require('lifemode.backlinks')
local index = require('lifemode.index')

describe("Backlinks Module", function()
  test("module loads successfully", function()
    assert_true(backlinks ~= nil, "Module should load")
    assert_true(type(backlinks.get_target_for_backlinks) == "function", "get_target_for_backlinks should be a function")
    assert_true(type(backlinks.render_backlinks_view) == "function", "render_backlinks_view should be a function")
  end)

  test("get_target_for_backlinks: extracts wikilink under cursor", function()
    -- Create buffer with wikilink
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "See [[Page]] for details"
    })

    -- Position cursor on wikilink (col 4 is inside [[Page]])
    local target, target_type = backlinks.get_target_for_backlinks(bufnr, 1, 6)

    assert_equal(target, "Page", "Should extract wikilink target")
    assert_equal(target_type, "wikilink", "Should identify as wikilink")

    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  test("get_target_for_backlinks: extracts Bible ref under cursor", function()
    -- Create buffer with Bible reference
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "See John 3:16 for details"
    })

    -- Position cursor on Bible ref (col 4 is inside "John 3:16")
    local target, target_type = backlinks.get_target_for_backlinks(bufnr, 1, 6)

    assert_equal(target, "bible:john:3:16", "Should extract Bible verse ID")
    assert_equal(target_type, "bible_verse", "Should identify as Bible verse")

    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  test("get_target_for_backlinks: returns nil when no target", function()
    -- Create buffer without links
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "Plain text without links"
    })

    -- Position cursor on plain text
    local target, target_type = backlinks.get_target_for_backlinks(bufnr, 1, 0)

    assert_equal(target, nil, "Should return nil when no target")
    assert_equal(target_type, nil, "Should return nil type")

    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  test("get_target_for_backlinks: uses filename when no cursor target", function()
    -- Create named buffer
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, "/tmp/test.md")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "Plain text"
    })

    -- No target at cursor - should use filename
    local target, target_type = backlinks.get_target_for_backlinks(bufnr, 1, 0)

    assert_equal(target, "test.md", "Should use filename as target")
    assert_equal(target_type, "page", "Should identify as page")

    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)

  test("render_backlinks_view: creates view buffer with backlinks", function()
    -- Create mock vault index
    local mock_index = {
      backlinks = {
        ["TestPage"] = { "node-1", "node-2" }
      },
      node_locations = {
        ["node-1"] = { file = "/tmp/file1.md", line = 5 },
        ["node-2"] = { file = "/tmp/file2.md", line = 10 }
      }
    }

    -- Create test files with content
    local f1 = io.open("/tmp/file1.md", "w")
    if f1 then
      f1:write("Line 1\n")
      f1:write("Line 2\n")
      f1:write("Line 3\n")
      f1:write("Line 4\n")
      f1:write("See [[TestPage]] here\n")  -- Line 5
      f1:write("Line 6\n")
      f1:close()
    end

    local f2 = io.open("/tmp/file2.md", "w")
    if f2 then
      for i = 1, 9 do
        f2:write("Line " .. i .. "\n")
      end
      f2:write("Reference to [[TestPage]]\n")  -- Line 10
      f2:write("Line 11\n")
      f2:close()
    end

    -- Render backlinks view
    local view_bufnr = backlinks.render_backlinks_view("TestPage", mock_index)

    assert_true(view_bufnr ~= nil, "Should return buffer number")
    assert_true(view_bufnr > 0, "Buffer number should be valid")

    -- Check buffer content
    local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
    assert_true(#lines > 0, "Buffer should have content")

    -- Should have header
    assert_true(lines[1]:match("Backlinks.*TestPage"), "Should have header with target")

    -- Clean up
    vim.api.nvim_buf_delete(view_bufnr, { force = true })
    os.remove("/tmp/file1.md")
    os.remove("/tmp/file2.md")
  end)

  test("render_backlinks_view: handles no backlinks gracefully", function()
    -- Create mock vault index with no backlinks
    local mock_index = {
      backlinks = {},
      node_locations = {}
    }

    -- Render backlinks view
    local view_bufnr = backlinks.render_backlinks_view("NoBacklinks", mock_index)

    assert_true(view_bufnr ~= nil, "Should return buffer number")
    assert_true(view_bufnr > 0, "Buffer number should be valid")

    -- Check buffer content
    local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
    assert_true(#lines > 0, "Buffer should have content")

    -- Should show "no backlinks" message
    local content = table.concat(lines, "\n")
    assert_true(content:match("[Nn]o backlinks") ~= nil, "Should show no backlinks message")

    -- Clean up
    vim.api.nvim_buf_delete(view_bufnr, { force = true })
  end)

  test("render_backlinks_view: shows context snippets", function()
    -- Create mock vault index
    local mock_index = {
      backlinks = {
        ["TargetNode"] = { "source-1" }
      },
      node_locations = {
        ["source-1"] = { file = "/tmp/context_test.md", line = 5 }
      }
    }

    -- Create test file with context
    local f = io.open("/tmp/context_test.md", "w")
    if f then
      f:write("Line 1\n")
      f:write("Line 2\n")
      f:write("Line 3 - before context\n")
      f:write("Line 4 - closer context\n")
      f:write("Line 5 - reference to [[TargetNode]] here\n")
      f:write("Line 6 - after context\n")
      f:write("Line 7 - more after\n")
      f:close()
    end

    -- Render backlinks view
    local view_bufnr = backlinks.render_backlinks_view("TargetNode", mock_index)

    -- Check buffer shows context
    local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
    local content = table.concat(lines, "\n")

    -- Should show file path
    assert_true(content:match("context_test%.md") ~= nil, "Should show filename")

    -- Should show reference line
    assert_true(content:match("%[%[TargetNode%]%]") ~= nil, "Should show reference")

    -- Clean up
    vim.api.nvim_buf_delete(view_bufnr, { force = true })
    os.remove("/tmp/context_test.md")
  end)

  test("render_backlinks_view: handles missing files gracefully", function()
    -- Create mock vault index with non-existent file
    local mock_index = {
      backlinks = {
        ["Target"] = { "missing-node" }
      },
      node_locations = {
        ["missing-node"] = { file = "/tmp/nonexistent.md", line = 5 }
      }
    }

    -- Render backlinks view - should not error
    local view_bufnr = backlinks.render_backlinks_view("Target", mock_index)

    assert_true(view_bufnr ~= nil, "Should return buffer number")
    assert_true(view_bufnr > 0, "Buffer number should be valid")

    -- Clean up
    vim.api.nvim_buf_delete(view_bufnr, { force = true })
  end)

  test("format_backlink_entry: creates readable entry", function()
    local entry = backlinks.format_backlink_entry(
      "/Users/test/vault/notes/page.md",
      5,
      "- [ ] Task about [[Target]] here",
      "/Users/test/vault"
    )

    assert_true(type(entry) == "table", "Should return table of lines")
    assert_true(#entry > 0, "Should have at least one line")

    -- Should contain relative path
    local content = table.concat(entry, "\n")
    assert_true(content:match("notes/page%.md") ~= nil, "Should show relative path")
    assert_true(content:match("%[%[Target%]%]") ~= nil, "Should show reference")
  end)

  test("show_backlinks: opens backlinks view for target under cursor", function()
    -- Create buffer with wikilink
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, "/tmp/test_vault_backlinks/test.md")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "See [[TestTarget]] for details"
    })
    vim.api.nvim_set_current_buf(bufnr)

    -- Create mock index
    local mock_index = {
      backlinks = {
        ["TestTarget"] = { "source-1" }
      },
      node_locations = {
        ["source-1"] = { file = "/tmp/source.md", line = 3 }
      }
    }

    -- Create source file
    local f = io.open("/tmp/source.md", "w")
    if f then
      f:write("Line 1\n")
      f:write("Line 2\n")
      f:write("Reference [[TestTarget]] here\n")
      f:close()
    end

    -- Mock get_config to return our mock index
    local original_get_config = lifemode.get_config
    lifemode.get_config = function()
      return {
        vault_root = '/tmp/test_vault_backlinks',
        vault_index = mock_index
      }
    end

    -- Position cursor on wikilink and show backlinks
    vim.api.nvim_win_set_cursor(0, {1, 6})
    backlinks.show_backlinks()

    -- Check that a view buffer was created
    local current_buf = vim.api.nvim_get_current_buf()
    local buf_name = vim.api.nvim_buf_get_name(current_buf)
    assert_true(buf_name:match("LifeMode.*Backlinks") ~= nil, "Should open backlinks view buffer")

    -- Restore original get_config
    lifemode.get_config = original_get_config

    -- Clean up
    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.api.nvim_buf_delete(current_buf, { force = true })
    os.remove("/tmp/source.md")
  end)

  test("show_backlinks: handles no vault index gracefully", function()
    -- Create buffer
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "Plain text"
    })
    vim.api.nvim_set_current_buf(bufnr)

    -- Mock get_config to return no index
    local original_get_config = lifemode.get_config
    lifemode.get_config = function()
      return {
        vault_root = '/tmp/test_vault_backlinks',
        vault_index = nil
      }
    end

    -- Show backlinks - should show message about no index
    backlinks.show_backlinks()

    -- Restore original get_config
    lifemode.get_config = original_get_config

    -- Clean up
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
end)

print("\n=== All backlinks tests passed ===")
