#!/usr/bin/env -S nvim -l

-- Test: Due date extraction and manipulation

local tasks = require('lifemode.tasks')
local parser = require('lifemode.parser')

-- Minimal test helpers
local function test(name, fn)
  local success, err = pcall(fn)
  if success then
    print('✓ ' .. name)
  else
    print('✗ ' .. name)
    print('  Error: ' .. tostring(err))
    os.exit(1)
  end
end

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format('%s\nExpected: %s\nActual: %s', msg or 'Assertion failed', vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_true(value, msg)
  if not value then
    error(msg or 'Expected true, got false')
  end
end

local function assert_false(value, msg)
  if value then
    error(msg or 'Expected false, got true')
  end
end

local function assert_nil(value, msg)
  if value ~= nil then
    error(string.format('%s\nExpected: nil\nActual: %s', msg or 'Expected nil', vim.inspect(value)))
  end
end

local function assert_error(fn, pattern)
  local success, err = pcall(fn)
  if success then
    error('Expected error but function succeeded')
  end
  if pattern and not string.find(tostring(err), pattern, 1, true) then
    error(string.format('Error message does not match pattern\nPattern: %s\nActual: %s', pattern, tostring(err)))
  end
end

local function assert_no_error(fn)
  local success, err = pcall(fn)
  if not success then
    error('Expected no error but got: ' .. tostring(err))
  end
end

print('Due date extraction and manipulation tests')

-- Test get_due
test('get_due extracts due date from line', function()
  local line = '- [ ] Task with due @due(2026-02-15) ^id'
  local due = tasks.get_due(line)
  assert_eq(due, '2026-02-15', 'Should extract due date')
end)

test('get_due returns nil when no due date', function()
  local line = '- [ ] Task without due ^id'
  local due = tasks.get_due(line)
  assert_nil(due, 'Should return nil when no due date')
end)

test('get_due handles due at end of line', function()
  local line = '- [ ] Task @due(2026-12-31)'
  local due = tasks.get_due(line)
  assert_eq(due, '2026-12-31', 'Should extract due at end')
end)

test('get_due handles due in middle of line', function()
  local line = '- [ ] Task @due(2026-01-01) with more text ^id'
  local due = tasks.get_due(line)
  assert_eq(due, '2026-01-01', 'Should extract due in middle')
end)

test('get_due validates YYYY-MM-DD format', function()
  local line = '- [ ] Task @due(2026-1-1) ^id'  -- Invalid: single digit month/day
  local due = tasks.get_due(line)
  assert_nil(due, 'Should return nil for invalid format')
end)

-- Test set_due (string manipulation)
test('set_due adds due date to line without due', function()
  local line = '- [ ] Task ^id'
  local result = tasks.set_due(line, '2026-03-20')
  assert_eq(result, '- [ ] Task @due(2026-03-20) ^id', 'Should add due before ID')
end)

test('set_due updates existing due date', function()
  local line = '- [ ] Task @due(2026-01-01) ^id'
  local result = tasks.set_due(line, '2026-12-31')
  assert_eq(result, '- [ ] Task @due(2026-12-31) ^id', 'Should update existing due')
end)

test('set_due removes due when date is nil', function()
  local line = '- [ ] Task @due(2026-01-01) ^id'
  local result = tasks.set_due(line, nil)
  assert_eq(result, '- [ ] Task ^id', 'Should remove due date')
end)

test('set_due adds due at end when no ID', function()
  local line = '- [ ] Task without ID'
  local result = tasks.set_due(line, '2026-06-15')
  assert_eq(result, '- [ ] Task without ID @due(2026-06-15)', 'Should add due at end')
end)

test('set_due preserves priority and tags', function()
  local line = '- [ ] Task !2 #work @due(2026-01-01) ^id'
  local result = tasks.set_due(line, '2026-02-01')
  assert_eq(result, '- [ ] Task !2 #work @due(2026-02-01) ^id', 'Should preserve priority and tags')
end)

test('set_due removes due preserves spacing', function()
  local line = '- [ ] Task @due(2026-01-01) #tag ^id'
  local result = tasks.set_due(line, nil)
  assert_eq(result, '- [ ] Task #tag ^id', 'Should clean up spacing')
end)

-- Test buffer operations
test('set_due_buffer updates task in buffer', function()
  -- Create test buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '- [ ] Task one @due(2026-01-01) ^task-1',
    '- [ ] Task two ^task-2',
  })

  -- Set due on task-2
  local success = tasks.set_due_buffer(bufnr, 'task-2', '2026-07-04')
  assert_true(success, 'Should succeed')

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  assert_eq(lines[2], '- [ ] Task two @due(2026-07-04) ^task-2', 'Should add due to task-2')

  -- Clean up
  vim.api.nvim_buf_delete(bufnr, {force = true})
end)

test('set_due_buffer returns false for non-task', function()
  -- Create test buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# Heading ^heading-1',
  })

  local success = tasks.set_due_buffer(bufnr, 'heading-1', '2026-01-01')
  assert_false(success, 'Should fail for non-task')

  -- Clean up
  vim.api.nvim_buf_delete(bufnr, {force = true})
end)

test('set_due_buffer returns false for missing node', function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '- [ ] Task ^task-1',
  })

  local success = tasks.set_due_buffer(bufnr, 'nonexistent', '2026-01-01')
  assert_false(success, 'Should fail for missing node')

  -- Clean up
  vim.api.nvim_buf_delete(bufnr, {force = true})
end)

test('clear_due_buffer removes due date', function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '- [ ] Task @due(2026-12-25) ^task-1',
  })

  local success = tasks.clear_due_buffer(bufnr, 'task-1')
  assert_true(success, 'Should succeed')

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  assert_eq(lines[1], '- [ ] Task ^task-1', 'Should remove due date')

  -- Clean up
  vim.api.nvim_buf_delete(bufnr, {force = true})
end)

test('set_due_buffer validates date format', function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '- [ ] Task ^task-1',
  })

  -- Invalid format: single digit month
  local success = tasks.set_due_buffer(bufnr, 'task-1', '2026-1-15')
  assert_false(success, 'Should reject invalid format')

  -- Clean up
  vim.api.nvim_buf_delete(bufnr, {force = true})
end)

-- Test interactive prompt (minimal - actual prompting requires UI)
test('set_due_interactive function exists', function()
  assert_true(type(tasks.set_due_interactive) == 'function', 'Should have set_due_interactive')
end)

test('clear_due_interactive function exists', function()
  assert_true(type(tasks.clear_due_interactive) == 'function', 'Should have clear_due_interactive')
end)

-- Edge cases
test('get_due ignores invalid date patterns', function()
  local line = '- [ ] Task @due(not-a-date) ^id'
  local due = tasks.get_due(line)
  assert_nil(due, 'Should return nil for invalid pattern')
end)

test('set_due handles multiple spaces', function()
  local line = '- [ ] Task  @due(2026-01-01)  ^id'
  local result = tasks.set_due(line, '2026-02-01')
  -- Should preserve some spacing but clean up doubles
  assert_true(result:match('@due%(2026%-02%-01%)'), 'Should contain updated due')
  assert_true(result:match('%^id'), 'Should preserve ID')
end)

test('set_due with empty date string removes due', function()
  local line = '- [ ] Task @due(2026-01-01) ^id'
  local result = tasks.set_due(line, '')
  assert_eq(result, '- [ ] Task ^id', 'Empty string should remove due')
end)

print('\nAll tests passed!')
