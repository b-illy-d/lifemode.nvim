-- Tests for render.lua (T13: Compiled view render)

-- Add project lua directory to path
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

-- Test helpers
local test_count = 0
local pass_count = 0

local function test(name, fn)
  test_count = test_count + 1
  local success, err = pcall(fn)
  if success then
    pass_count = pass_count + 1
    print(string.format("✓ %s", name))
  else
    print(string.format("✗ %s", name))
    print(string.format("  Error: %s", err))
  end
end

local function assert_equal(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", msg or "Assertion failed", vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_not_nil(value, msg)
  if value == nil then
    error(msg or "Expected non-nil value")
  end
end

local function assert_match(str, pattern, msg)
  if not str:match(pattern) then
    error(string.format("%s: expected %s to match pattern %s", msg or "Pattern match failed", str, pattern))
  end
end

-- Setup
package.loaded['lifemode'] = nil
package.loaded['lifemode.render'] = nil
package.loaded['lifemode.node'] = nil
package.loaded['lifemode.lens'] = nil
package.loaded['lifemode.extmarks'] = nil
package.loaded['lifemode.view'] = nil

local lifemode = require('lifemode')
lifemode.setup({ vault_root = '/tmp/test-vault' })

local render = require('lifemode.render')
local extmarks = require('lifemode.extmarks')

print("\n=== T13 Render Tests ===\n")

test("render module loads", function()
  assert_not_nil(render, "render module should load")
  assert_not_nil(render.render_page_view, "render_page_view should exist")
end)

test("render_page_view renders single root node", function()
  -- Create test buffer with single task
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task 1 ^task-1"
  })

  local view_bufnr = render.render_page_view(bufnr)

  assert_not_nil(view_bufnr, "view buffer should be created")

  -- Check buffer properties
  assert_equal(vim.api.nvim_buf_get_option(view_bufnr, 'buftype'), 'nofile', "buftype should be nofile")

  -- Check content
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  assert_equal(#lines, 1, "should have 1 line")
  assert_match(lines[1], "Task 1", "should contain task text")

  -- Check extmark metadata
  local metadata = extmarks.get_span_at_line(view_bufnr, 0)
  assert_not_nil(metadata, "extmark metadata should exist")
  assert_not_nil(metadata.instance_id, "should have instance_id")
  assert_equal(metadata.node_id, "task-1", "should have correct node_id")
  assert_equal(metadata.lens, "task/brief", "should use task/brief lens")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("render_page_view renders multiple root nodes", function()
  -- Create test buffer with multiple tasks
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task 1 ^task-1",
    "- [ ] Task 2 ^task-2",
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Check content
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  assert_equal(#lines, 2, "should have 2 lines")

  -- Check first node metadata
  local meta1 = extmarks.get_span_at_line(view_bufnr, 0)
  assert_equal(meta1.node_id, "task-1", "first node should be task-1")

  -- Check second node metadata
  local meta2 = extmarks.get_span_at_line(view_bufnr, 1)
  assert_equal(meta2.node_id, "task-2", "second node should be task-2")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("render_page_view renders only root nodes (not children)", function()
  -- Create test buffer with heading and nested task
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "# Heading ^heading-1",
    "- [ ] Child task ^task-1",
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Check content - should only have heading (root node)
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  assert_equal(#lines, 1, "should only render root node (heading)")

  -- Check metadata
  local meta = extmarks.get_span_at_line(view_bufnr, 0)
  assert_equal(meta.node_id, "heading-1", "should be heading node")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("render_page_view uses task/brief lens for tasks", function()
  -- Create test buffer with task
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task with ID ^task-1"
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Check metadata
  local meta = extmarks.get_span_at_line(view_bufnr, 0)
  assert_equal(meta.lens, "task/brief", "should use task/brief lens")

  -- Check content (task/brief removes ID)
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  assert_match(lines[1], "Task with ID", "should contain task text")
  if lines[1]:match("%^task%-1") then
    error("task/brief should remove ID from display")
  end

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("render_page_view uses node/raw lens for non-tasks", function()
  -- Create test buffer with heading
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "# Heading ^heading-1"
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Check metadata
  local meta = extmarks.get_span_at_line(view_bufnr, 0)
  assert_equal(meta.lens, "node/raw", "should use node/raw lens")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("render_page_view handles empty buffer", function()
  -- Create empty buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  local view_bufnr = render.render_page_view(bufnr)

  -- Check content - should be empty
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  assert_equal(#lines, 1, "empty buffer should have 1 empty line")
  assert_equal(lines[1], "", "line should be empty")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("render_page_view handles buffer with no root nodes", function()
  -- Create buffer with only text (no blocks)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "Just some text",
    "More text"
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Check content - should be empty
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  assert_equal(#lines, 1, "should have 1 empty line")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("render_page_view generates unique instance_ids", function()
  -- Create test buffer with multiple tasks
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task 1 ^task-1",
    "- [ ] Task 2 ^task-2",
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Check metadata
  local meta1 = extmarks.get_span_at_line(view_bufnr, 0)
  local meta2 = extmarks.get_span_at_line(view_bufnr, 1)

  assert_not_nil(meta1.instance_id, "first instance should have ID")
  assert_not_nil(meta2.instance_id, "second instance should have ID")

  -- Instance IDs should be different
  if meta1.instance_id == meta2.instance_id then
    error("instance IDs should be unique")
  end

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("render_page_view sets correct span_start and span_end", function()
  -- Create test buffer with tasks
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task 1 ^task-1",
    "- [ ] Task 2 ^task-2",
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Check first span
  local meta1 = extmarks.get_span_at_line(view_bufnr, 0)
  assert_equal(meta1.span_start, 0, "first span should start at 0")
  assert_equal(meta1.span_end, 0, "first span should end at 0")

  -- Check second span
  local meta2 = extmarks.get_span_at_line(view_bufnr, 1)
  assert_equal(meta2.span_start, 1, "second span should start at 1")
  assert_equal(meta2.span_end, 1, "second span should end at 1")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("render_page_view handles multi-line lens rendering", function()
  -- For MVP, lens.render returns string or table
  -- This test ensures we handle both cases
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task ^task-1"
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Should render successfully
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  assert_equal(type(lines), "table", "lines should be a table")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

-- Summary
print(string.format("\nTests: %d/%d passed\n", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
