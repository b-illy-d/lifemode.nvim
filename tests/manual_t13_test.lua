-- Manual acceptance test for T13: Compiled view render
-- Run: nvim -l tests/manual_t13_test.lua

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

local lifemode = require('lifemode')
lifemode.setup({ vault_root = '/tmp/test-vault' })

local render = require('lifemode.render')
local extmarks = require('lifemode.extmarks')

print("\n=== T13 Manual Acceptance Tests ===\n")

test("Acceptance: :LifeModePageView command exists", function()
  -- Check command exists
  local commands = vim.api.nvim_get_commands({})
  assert_not_nil(commands['LifeModePageView'], ":LifeModePageView command should exist")
end)

test("Acceptance: Simple file with root tasks renders correctly", function()
  -- Create test buffer with tasks
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Buy groceries ^task-1",
    "- [ ] Call dentist !2 ^task-2",
    "- [x] Finish report ^task-3",
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Check content
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  assert_equal(#lines, 3, "should have 3 lines")
  assert_match(lines[1], "Buy groceries", "line 1 should contain task text")
  assert_match(lines[2], "Call dentist", "line 2 should contain task text")
  assert_match(lines[3], "Finish report", "line 3 should contain task text")

  -- Check IDs are hidden (task/brief lens)
  if lines[1]:match("%^task%-1") then
    error("IDs should be hidden in task/brief lens")
  end

  -- Check metadata
  local meta1 = extmarks.get_span_at_line(view_bufnr, 0)
  assert_equal(meta1.node_id, "task-1", "node_id should be task-1")
  assert_equal(meta1.lens, "task/brief", "should use task/brief lens")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("Acceptance: File with heading and nested tasks shows only heading", function()
  -- Create test buffer with hierarchy
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "# Project A ^heading-1",
    "- [ ] Task 1 ^task-1",
    "- [ ] Task 2 ^task-2",
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Check content - should only show heading (root node)
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  assert_equal(#lines, 1, "should only show root node (heading)")
  assert_match(lines[1], "Project A", "should contain heading text")

  -- Check metadata
  local meta = extmarks.get_span_at_line(view_bufnr, 0)
  assert_equal(meta.node_id, "heading-1", "should be heading node")
  assert_equal(meta.lens, "node/raw", "headings use node/raw lens")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("Acceptance: File with multiple root nodes renders all", function()
  -- Create test buffer with multiple truly root-level items
  -- All at same level (no hierarchy)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task 1 ^task-1",
    "- [ ] Task 2 ^task-2",
    "- [ ] Task 3 ^task-3",
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Check content - should show all root nodes
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  assert_equal(#lines, 3, "should show all 3 root nodes")

  -- Check metadata for each
  local meta1 = extmarks.get_span_at_line(view_bufnr, 0)
  assert_equal(meta1.node_id, "task-1", "first root should be task-1")

  local meta2 = extmarks.get_span_at_line(view_bufnr, 1)
  assert_equal(meta2.node_id, "task-2", "second root should be task-2")

  local meta3 = extmarks.get_span_at_line(view_bufnr, 2)
  assert_equal(meta3.node_id, "task-3", "third root should be task-3")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("Acceptance: View buffer has correct options", function()
  -- Create test buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task ^task-1"
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Check buffer options
  assert_equal(vim.api.nvim_buf_get_option(view_bufnr, 'buftype'), 'nofile', "buftype should be nofile")
  assert_equal(vim.api.nvim_buf_get_option(view_bufnr, 'swapfile'), false, "swapfile should be false")
  assert_equal(vim.api.nvim_buf_get_option(view_bufnr, 'bufhidden'), 'wipe', "bufhidden should be wipe")
  assert_equal(vim.api.nvim_buf_get_option(view_bufnr, 'filetype'), 'lifemode', "filetype should be lifemode")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("Acceptance: Instance metadata includes all required fields", function()
  -- Create test buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task ^task-1"
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Check metadata
  local meta = extmarks.get_span_at_line(view_bufnr, 0)
  assert_not_nil(meta.instance_id, "should have instance_id")
  assert_not_nil(meta.node_id, "should have node_id")
  assert_not_nil(meta.lens, "should have lens")
  assert_not_nil(meta.span_start, "should have span_start")
  assert_not_nil(meta.span_end, "should have span_end")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("Acceptance: Tasks use task/brief lens by default", function()
  -- Create test buffer with task
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Buy milk ^task-1"
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Check lens
  local meta = extmarks.get_span_at_line(view_bufnr, 0)
  assert_equal(meta.lens, "task/brief", "tasks should use task/brief lens")

  -- Check ID is hidden
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  if lines[1]:match("%^task%-1") then
    error("task/brief lens should hide ID")
  end

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("Acceptance: Non-task nodes use node/raw lens", function()
  -- Create test buffer with heading (non-task node)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "# Heading ^heading-1",
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Check lens for heading
  local meta = extmarks.get_span_at_line(view_bufnr, 0)
  assert_equal(meta.lens, "node/raw", "headings should use node/raw lens")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("Acceptance: Empty file renders empty view", function()
  -- Create empty buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  local view_bufnr = render.render_page_view(bufnr)

  -- Check content
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  assert_equal(#lines, 1, "empty file should have 1 empty line")
  assert_equal(lines[1], "", "line should be empty")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("Acceptance: File with only prose renders empty view", function()
  -- Create buffer with only prose (no parseable blocks)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "This is just some text.",
    "More text here.",
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Check content
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  assert_equal(#lines, 1, "should have 1 empty line")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

test("Acceptance: Instance IDs are unique across multiple nodes", function()
  -- Create test buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "- [ ] Task 1 ^task-1",
    "- [ ] Task 2 ^task-2",
    "- [ ] Task 3 ^task-3",
  })

  local view_bufnr = render.render_page_view(bufnr)

  -- Check all instance IDs are unique
  local meta1 = extmarks.get_span_at_line(view_bufnr, 0)
  local meta2 = extmarks.get_span_at_line(view_bufnr, 1)
  local meta3 = extmarks.get_span_at_line(view_bufnr, 2)

  local ids = {
    [meta1.instance_id] = true,
    [meta2.instance_id] = true,
    [meta3.instance_id] = true,
  }

  -- Should have 3 unique IDs
  local count = 0
  for _ in pairs(ids) do
    count = count + 1
  end
  assert_equal(count, 3, "all instance IDs should be unique")

  vim.api.nvim_buf_delete(bufnr, { force = true })
  vim.api.nvim_buf_delete(view_bufnr, { force = true })
end)

-- Summary
print(string.format("\nTests: %d/%d passed\n", pass_count, test_count))

if pass_count == test_count then
  print("✓ Acceptance criteria MET: :LifeModePageView shows file as compiled interactive view")
else
  print("✗ Acceptance criteria NOT MET")
end

os.exit(pass_count == test_count and 0 or 1)
