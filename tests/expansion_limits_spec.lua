-- Test T15: Expansion budget + cycle stub

-- Add project lua directory to path
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local lifemode = require('lifemode')
local render = require('lifemode.render')
local extmarks = require('lifemode.extmarks')

-- Test framework
local tests = {}
local function test(name, fn) table.insert(tests, {name = name, fn = fn}) end
local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format('%s\nExpected: %s\nActual: %s', msg or 'Assertion failed', vim.inspect(expected), vim.inspect(actual)))
  end
end
local function assert_true(value, msg)
  if not value then error(msg or 'Expected true, got false') end
end
local function assert_match(str, pattern, msg)
  if not str:match(pattern) then
    error(string.format('%s\nString: %s\nPattern: %s', msg or 'Pattern match failed', str, pattern))
  end
end

-- Helper: Create buffer with test content
local function create_test_buffer(content)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
  return bufnr
end

-- Helper: Count lines in buffer
local function count_lines(bufnr)
  return vim.api.nvim_buf_line_count(bufnr)
end

-- Test 1: Cycle detection shows stub
test('detects simple cycle and shows stub', function()
  lifemode._reset_for_testing()
  lifemode.setup({ vault_root = '/test' })

  -- Create source buffer where A has B as child
  local source_bufnr = create_test_buffer({
    '- Task A ^a',
    '  - Task B ^b',
  })

  -- Render page view
  local view_bufnr = render.render_page_view(source_bufnr)

  -- Manually create cycle in cache: make B have A as a child
  -- This simulates a cyclic reference that could occur in real data
  render._node_cache[string.format("%d:b", view_bufnr)].children = {"a"}

  -- Expand task A (should show B)
  render.expand_instance(view_bufnr, 0)

  -- Now expand task B - should detect cycle and show stub
  render.expand_instance(view_bufnr, 1)

  -- Check for cycle stub in output
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  local found_stub = false
  for _, line in ipairs(lines) do
    if line:match('↩') or line:match('already shown') or line:match('cycle') then
      found_stub = true
      break
    end
  end

  assert_true(found_stub, 'Expected cycle stub to be shown')
end)

-- Test 2: Max depth prevents deep expansion
test('respects max_depth limit', function()
  lifemode._reset_for_testing()
  lifemode.setup({ vault_root = '/test', max_depth = 2 })

  -- Create source buffer with deep nesting: A → B → C → D
  local source_bufnr = create_test_buffer({
    '- Task A ^a',
    '  - Task B ^b',
    '    - Task C ^c',
    '      - Task D ^d',
  })

  -- Render page view
  local view_bufnr = render.render_page_view(source_bufnr)

  -- Expand A (depth 1)
  render.expand_instance(view_bufnr, 0)

  -- Expand B (depth 2, at limit)
  render.expand_instance(view_bufnr, 1)

  -- Try to expand C (depth 3, exceeds limit)
  -- Should either do nothing or show depth limit message
  local lines_before = count_lines(view_bufnr)
  render.expand_instance(view_bufnr, 2)
  local lines_after = count_lines(view_bufnr)

  -- At max depth, no new expansion should occur
  -- (or minimal stub line added)
  assert_true(lines_after - lines_before <= 1, 'Max depth should prevent further expansion')
end)

-- Test 3: Max nodes per action limits expansion
test('respects max_nodes_per_action limit', function()
  lifemode._reset_for_testing()
  lifemode.setup({ vault_root = '/test', max_nodes_per_action = 3 })

  -- Create source buffer with many children
  local source_bufnr = create_test_buffer({
    '- Task A ^a',
    '  - Task B1 ^b1',
    '  - Task B2 ^b2',
    '  - Task B3 ^b3',
    '  - Task B4 ^b4',
    '  - Task B5 ^b5',
  })

  -- Render page view
  local view_bufnr = render.render_page_view(source_bufnr)

  -- Expand A - should only show first 3 children (max_nodes_per_action = 3)
  render.expand_instance(view_bufnr, 0)

  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)

  -- Count how many children were rendered
  local child_count = 0
  for _, line in ipairs(lines) do
    if line:match('Task B') then
      child_count = child_count + 1
    end
  end

  -- Should have rendered at most 3 children
  assert_true(child_count <= 3, string.format('Expected at most 3 children, got %d', child_count))
end)

-- Test 4: Cycle in grandchildren is detected
test('detects cycle in deeper nesting', function()
  lifemode._reset_for_testing()
  lifemode.setup({ vault_root = '/test' })

  -- Create source buffer: A → B → C
  local source_bufnr = create_test_buffer({
    '- Task A ^a',
    '  - Task B ^b',
    '    - Task C ^c',
  })

  -- Render page view
  local view_bufnr = render.render_page_view(source_bufnr)

  -- Manually create cycle: C → A (cycle back to A at depth 3)
  render._node_cache[string.format("%d:c", view_bufnr)].children = {"a"}

  -- Expand A, then B, then C
  render.expand_instance(view_bufnr, 0)
  render.expand_instance(view_bufnr, 1)
  render.expand_instance(view_bufnr, 2)

  -- Check for cycle stub
  local lines = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  local found_stub = false
  for _, line in ipairs(lines) do
    if line:match('↩') or line:match('already shown') then
      found_stub = true
      break
    end
  end

  assert_true(found_stub, 'Expected cycle stub for grandchild cycle')
end)

-- Test 5: No false positive for same node in different branches
test('allows same node in different branches', function()
  lifemode._reset_for_testing()
  lifemode.setup({ vault_root = '/test' })

  -- Create source buffer: Root → [A, B], A → C, B → C (C in both branches, not a cycle)
  local source_bufnr = create_test_buffer({
    '- Root ^root',
    '  - Task A ^a',
    '    - Task C ^c',
    '  - Task B ^b',
    '    - Task C ^c',
  })

  -- Render page view
  local view_bufnr = render.render_page_view(source_bufnr)

  -- Expand Root
  render.expand_instance(view_bufnr, 0)

  -- Expand A (shows C)
  render.expand_instance(view_bufnr, 1)

  -- Expand B (should also show C - not a cycle, different expansion path)
  local lines_before = count_lines(view_bufnr)
  render.expand_instance(view_bufnr, 3)  -- B is at line 3 after A's expansion
  local lines_after = count_lines(view_bufnr)

  -- B should successfully expand (no cycle detected)
  assert_true(lines_after > lines_before, 'Same node in different branches should not be treated as cycle')
end)

-- Test 6: Expansion with depth tracking
test('tracks depth correctly through expansion chain', function()
  lifemode._reset_for_testing()
  lifemode.setup({ vault_root = '/test', max_depth = 3 })

  -- Create source buffer with 5 levels deep
  local source_bufnr = create_test_buffer({
    '- L1 ^l1',
    '  - L2 ^l2',
    '    - L3 ^l3',
    '      - L4 ^l4',
    '        - L5 ^l5',
  })

  -- Render page view
  local view_bufnr = render.render_page_view(source_bufnr)

  -- Expand L1 (depth 1)
  render.expand_instance(view_bufnr, 0)

  -- Expand L2 (depth 2)
  render.expand_instance(view_bufnr, 1)

  -- Expand L3 (depth 3, at limit)
  render.expand_instance(view_bufnr, 2)

  -- Try to expand L4 (depth 4, exceeds limit) - should be blocked
  local lines_before = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)
  render.expand_instance(view_bufnr, 3)
  local lines_after = vim.api.nvim_buf_get_lines(view_bufnr, 0, -1, false)

  -- Should not add L5 (would be depth 4, exceeds max_depth=3)
  local has_l5 = false
  for _, line in ipairs(lines_after) do
    if line:match('L5') then
      has_l5 = true
      break
    end
  end

  assert_true(not has_l5, 'L5 should not appear when max_depth is exceeded')
end)

-- Run tests
local passed, failed = 0, 0
for _, t in ipairs(tests) do
  local ok, err = pcall(t.fn)
  if ok then
    passed = passed + 1
    print(string.format('✓ %s', t.name))
  else
    failed = failed + 1
    print(string.format('✗ %s\n  %s', t.name, err))
  end
end

print(string.format('\n%d passed, %d failed', passed, failed))
if failed > 0 then os.exit(1) end
