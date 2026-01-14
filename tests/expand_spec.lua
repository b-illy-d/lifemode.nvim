-- Test expand/collapse functionality

-- Add project lua directory to path
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

-- Test harness
local tests = {}
local test_count = 0
local pass_count = 0

local function test(name, fn)
  table.insert(tests, {name = name, fn = fn})
end

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s\nExpected: %s\nActual: %s", msg or "Assertion failed", vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_true(value, msg)
  if not value then
    error(msg or "Expected true, got false")
  end
end

local function assert_false(value, msg)
  if value then
    error(msg or "Expected false, got true")
  end
end

local function assert_error(fn, expected_pattern)
  local ok, err = pcall(fn)
  if ok then
    error("Expected error but function succeeded")
  end
  if expected_pattern and not string.match(tostring(err), expected_pattern) then
    error(string.format("Error message '%s' does not match pattern '%s'", tostring(err), expected_pattern))
  end
end

-- Reset lifemode before each test
local function reset_lifemode()
  package.loaded['lifemode'] = nil
  package.loaded['lifemode.render'] = nil
  package.loaded['lifemode.node'] = nil
  package.loaded['lifemode.lens'] = nil
  package.loaded['lifemode.parser'] = nil
  package.loaded['lifemode.extmarks'] = nil

  local lifemode = require('lifemode')
  lifemode._reset_for_testing()
  lifemode.setup({
    vault_root = '/tmp/test_vault',
    leader = '<Space>',
  })
end

-- Helper to create buffer with test content
local function create_test_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '- [ ] Task 1 ^task-1',
    '- [ ] Task 2 ^task-2',
    '  - [ ] Subtask 2.1 ^task-2-1',
    '  - [ ] Subtask 2.2 ^task-2-2',
    '- [ ] Task 3 ^task-3',
  })
  return bufnr
end

-- Tests
test("expand_instance() expands node with children", function()
  reset_lifemode()
  local render = require('lifemode.render')
  local extmarks = require('lifemode.extmarks')

  -- Create source buffer with parent-child structure
  local source_bufnr = create_test_buffer()

  -- Render page view (only roots initially)
  local view_bufnr = render.render_page_view(source_bufnr)

  -- Get initial line count
  local initial_lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  local initial_count = #initial_lines

  -- Find line with "Task 2" (which has children)
  local task2_line = nil
  for i, line in ipairs(initial_lines) do
    if line:match("Task 2") then
      task2_line = i - 1  -- Convert to 0-indexed
      break
    end
  end

  assert_true(task2_line ~= nil, "Task 2 should be in view")

  -- Expand Task 2
  render.expand_instance(view_bufnr, task2_line)

  -- Get new line count
  local expanded_lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)

  -- Should have more lines now (children added)
  assert_true(#expanded_lines > initial_count, "Line count should increase after expand")

  -- Check that children are present
  local has_subtask_21 = false
  local has_subtask_22 = false
  for _, line in ipairs(expanded_lines) do
    if line:match("Subtask 2%.1") then has_subtask_21 = true end
    if line:match("Subtask 2%.2") then has_subtask_22 = true end
  end

  assert_true(has_subtask_21, "Subtask 2.1 should be visible after expand")
  assert_true(has_subtask_22, "Subtask 2.2 should be visible after expand")
end)

test("collapse_instance() removes expanded children", function()
  reset_lifemode()
  local render = require('lifemode.render')

  -- Create source buffer
  local source_bufnr = create_test_buffer()

  -- Render page view
  local view_bufnr = render.render_page_view(source_bufnr)

  -- Find Task 2 line
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  local task2_line = nil
  for i, line in ipairs(lines) do
    if line:match("Task 2") then
      task2_line = i - 1
      break
    end
  end

  -- Expand Task 2
  render.expand_instance(view_bufnr, task2_line)

  local expanded_count = #vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)

  -- Collapse Task 2
  render.collapse_instance(view_bufnr, task2_line)

  local collapsed_lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)

  -- Line count should be back to original
  assert_true(#collapsed_lines < expanded_count, "Line count should decrease after collapse")

  -- Children should be gone
  local has_subtask = false
  for _, line in ipairs(collapsed_lines) do
    if line:match("Subtask") then
      has_subtask = true
      break
    end
  end

  assert_false(has_subtask, "Subtasks should not be visible after collapse")
end)

test("repeated expand does not duplicate children", function()
  reset_lifemode()
  local render = require('lifemode.render')

  -- Create source buffer
  local source_bufnr = create_test_buffer()

  -- Render page view
  local view_bufnr = render.render_page_view(source_bufnr)

  -- Find Task 2 line
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  local task2_line = nil
  for i, line in ipairs(lines) do
    if line:match("Task 2") then
      task2_line = i - 1
      break
    end
  end

  -- Expand Task 2 twice
  render.expand_instance(view_bufnr, task2_line)
  local first_expand_count = #vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)

  render.expand_instance(view_bufnr, task2_line)
  local second_expand_count = #vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)

  -- Line count should be same (no duplication)
  assert_eq(second_expand_count, first_expand_count, "Repeated expand should not add more lines")
end)

test("expand on node without children does nothing", function()
  reset_lifemode()
  local render = require('lifemode.render')

  -- Create source buffer
  local source_bufnr = create_test_buffer()

  -- Render page view
  local view_bufnr = render.render_page_view(source_bufnr)

  -- Find Task 1 line (no children)
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  local task1_line = nil
  for i, line in ipairs(lines) do
    if line:match("Task 1") then
      task1_line = i - 1
      break
    end
  end

  local initial_count = #lines

  -- Expand Task 1 (no children)
  render.expand_instance(view_bufnr, task1_line)

  local after_count = #vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)

  -- Line count should be same
  assert_eq(after_count, initial_count, "Expanding node without children should not add lines")
end)

test("is_expanded() tracks expansion state", function()
  reset_lifemode()
  local render = require('lifemode.render')
  local extmarks = require('lifemode.extmarks')

  -- Create source buffer
  local source_bufnr = create_test_buffer()

  -- Render page view
  local view_bufnr = render.render_page_view(source_bufnr)

  -- Find Task 2 line
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  local task2_line = nil
  for i, line in ipairs(lines) do
    if line:match("Task 2") then
      task2_line = i - 1
      break
    end
  end

  -- Get instance_id
  local span = extmarks.get_span_at_line(view_bufnr, task2_line)
  assert_true(span ~= nil, "Should have span at Task 2 line")

  -- Initially not expanded
  assert_false(render.is_expanded(view_bufnr, span.instance_id), "Should not be expanded initially")

  -- Expand
  render.expand_instance(view_bufnr, task2_line)

  -- Now expanded
  assert_true(render.is_expanded(view_bufnr, span.instance_id), "Should be expanded after expand_instance")

  -- Collapse
  render.collapse_instance(view_bufnr, task2_line)

  -- Not expanded anymore
  assert_false(render.is_expanded(view_bufnr, span.instance_id), "Should not be expanded after collapse")
end)

test("keymaps <Space>e and <Space>E are registered", function()
  reset_lifemode()
  local render = require('lifemode.render')

  -- Create source buffer
  local source_bufnr = create_test_buffer()

  -- Render page view
  local view_bufnr = render.render_page_view(source_bufnr)

  -- Check for keymaps
  local keymaps = vim.api.nvim_buf_get_keymap(view_bufnr, 'n')

  local has_expand = false
  local has_collapse = false

  for _, map in ipairs(keymaps) do
    if map.lhs == ' e' then has_expand = true end
    if map.lhs == ' E' then has_collapse = true end
  end

  assert_true(has_expand, "<Space>e keymap should be registered")
  assert_true(has_collapse, "<Space>E keymap should be registered")
end)

-- Run all tests
local function run_tests()
  for _, t in ipairs(tests) do
    test_count = test_count + 1
    local ok, err = pcall(t.fn)
    if ok then
      pass_count = pass_count + 1
      print(string.format("✓ %s", t.name))
    else
      print(string.format("✗ %s", t.name))
      print(string.format("  Error: %s", err))
    end
  end

  print(string.format("\n%d/%d tests passed", pass_count, test_count))

  if pass_count < test_count then
    os.exit(1)
  end
end

run_tests()
