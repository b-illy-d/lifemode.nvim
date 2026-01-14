#!/usr/bin/env -S nvim -l

-- Extmark-based span mapping tests

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

-- Add lua directory to package path
package.path = package.path .. ';lua/?.lua;lua/?/init.lua'

-- Run tests
local extmarks = require('lifemode.extmarks')

describe("extmarks.get_namespace", function()
  test("returns a valid namespace id", function()
    local ns = extmarks.get_namespace()
    assert_equals('number', type(ns))
    assert_true(ns >= 0, "Namespace ID should be non-negative")
  end)

  test("returns same namespace on multiple calls", function()
    local ns1 = extmarks.get_namespace()
    local ns2 = extmarks.get_namespace()
    assert_equals(ns1, ns2)
  end)
end)

describe("extmarks.set_span_metadata", function()
  local bufnr

  local function setup_buffer()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'Line 1',
      'Line 2',
      'Line 3',
      'Line 4',
      'Line 5',
    })
  end

  test("sets metadata for a single line span", function()
    setup_buffer()
    local metadata = {
      instance_id = 'inst-1',
      node_id = 'node-1',
      lens = 'task/brief',
      span_start = 0,
      span_end = 0,
    }

    assert_no_error(function()
      extmarks.set_span_metadata(bufnr, 0, 0, metadata)
    end)
  end)

  test("sets metadata for a multi-line span", function()
    setup_buffer()
    local metadata = {
      instance_id = 'inst-2',
      node_id = 'node-2',
      lens = 'task/detail',
      span_start = 1,
      span_end = 3,
    }

    assert_no_error(function()
      extmarks.set_span_metadata(bufnr, 1, 3, metadata)
    end)
  end)

  test("overwrites existing metadata on same line", function()
    setup_buffer()
    local metadata1 = {
      instance_id = 'inst-1',
      node_id = 'node-1',
      lens = 'task/brief',
      span_start = 0,
      span_end = 0,
    }
    local metadata2 = {
      instance_id = 'inst-2',
      node_id = 'node-2',
      lens = 'task/detail',
      span_start = 0,
      span_end = 0,
    }

    extmarks.set_span_metadata(bufnr, 0, 0, metadata1)
    extmarks.set_span_metadata(bufnr, 0, 0, metadata2)

    local retrieved = extmarks.get_span_at_line(bufnr, 0)
    assert_equals('inst-2', retrieved.instance_id)
    assert_equals('node-2', retrieved.node_id)
  end)
end)

describe("extmarks.get_span_at_line", function()
  local bufnr

  local function setup_buffer()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'Line 1',
      'Line 2',
      'Line 3',
      'Line 4',
      'Line 5',
    })
  end

  test("retrieves metadata for line with single span", function()
    setup_buffer()
    local metadata = {
      instance_id = 'inst-1',
      node_id = 'node-1',
      lens = 'task/brief',
      span_start = 0,
      span_end = 0,
    }

    extmarks.set_span_metadata(bufnr, 0, 0, metadata)
    local retrieved = extmarks.get_span_at_line(bufnr, 0)

    assert_equals('inst-1', retrieved.instance_id)
    assert_equals('node-1', retrieved.node_id)
    assert_equals('task/brief', retrieved.lens)
    assert_equals(0, retrieved.span_start)
    assert_equals(0, retrieved.span_end)
  end)

  test("retrieves metadata for line within multi-line span", function()
    setup_buffer()
    local metadata = {
      instance_id = 'inst-2',
      node_id = 'node-2',
      lens = 'task/detail',
      span_start = 1,
      span_end = 3,
    }

    extmarks.set_span_metadata(bufnr, 1, 3, metadata)

    -- Check all lines in the span
    local retrieved1 = extmarks.get_span_at_line(bufnr, 1)
    local retrieved2 = extmarks.get_span_at_line(bufnr, 2)
    local retrieved3 = extmarks.get_span_at_line(bufnr, 3)

    assert_equals('inst-2', retrieved1.instance_id)
    assert_equals('inst-2', retrieved2.instance_id)
    assert_equals('inst-2', retrieved3.instance_id)
  end)

  test("returns nil for line with no metadata", function()
    setup_buffer()
    local retrieved = extmarks.get_span_at_line(bufnr, 0)
    assert_nil(retrieved, "Should return nil for line with no metadata")
  end)

  test("returns nil for invalid buffer", function()
    local retrieved = extmarks.get_span_at_line(9999, 0)
    assert_nil(retrieved, "Should return nil for invalid buffer")
  end)

  test("returns nil for out-of-range line", function()
    setup_buffer()
    local retrieved = extmarks.get_span_at_line(bufnr, 999)
    assert_nil(retrieved, "Should return nil for out-of-range line")
  end)
end)

describe("extmarks.get_span_at_cursor", function()
  local bufnr

  local function setup_buffer()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'Line 1',
      'Line 2',
      'Line 3',
    })
    vim.api.nvim_set_current_buf(bufnr)
  end

  test("retrieves metadata at cursor position", function()
    setup_buffer()
    local metadata = {
      instance_id = 'inst-1',
      node_id = 'node-1',
      lens = 'task/brief',
      span_start = 1,
      span_end = 1,
    }

    extmarks.set_span_metadata(bufnr, 1, 1, metadata)
    vim.api.nvim_win_set_cursor(0, {2, 0}) -- Line 2 (1-indexed for cursor)

    local retrieved = extmarks.get_span_at_cursor()
    assert_equals('inst-1', retrieved.instance_id)
    assert_equals('node-1', retrieved.node_id)
  end)

  test("returns nil when cursor on line with no metadata", function()
    setup_buffer()
    vim.api.nvim_win_set_cursor(0, {1, 0}) -- Line 1 (no metadata)

    local retrieved = extmarks.get_span_at_cursor()
    assert_nil(retrieved, "Should return nil when cursor on line with no metadata")
  end)
end)

describe(":LifeModeDebugSpan command", function()
  local lifemode = require('lifemode')

  test("is defined after setup", function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '/test/vault' })

    local cmd = vim.api.nvim_get_commands({})['LifeModeDebugSpan']
    assert_true(cmd ~= nil, "LifeModeDebugSpan command should be defined")
  end)

  test("executes without error when no metadata at cursor", function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '/test/vault' })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {'Line 1'})
    vim.api.nvim_set_current_buf(bufnr)

    assert_no_error(function()
      vim.cmd('LifeModeDebugSpan')
    end)
  end)

  test("executes without error when metadata exists at cursor", function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '/test/vault' })

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {'Line 1', 'Line 2'})
    vim.api.nvim_set_current_buf(bufnr)

    local metadata = {
      instance_id = 'test-inst',
      node_id = 'test-node',
      lens = 'task/brief',
      span_start = 0,
      span_end = 0,
    }
    extmarks.set_span_metadata(bufnr, 0, 0, metadata)
    vim.api.nvim_win_set_cursor(0, {1, 0})

    assert_no_error(function()
      vim.cmd('LifeModeDebugSpan')
    end)
  end)
end)

-- Print summary
print(string.format("\n%s", string.rep("=", 50)))
print(string.format("Tests: %d | Pass: %d | Fail: %d", test_count, pass_count, fail_count))
print(string.rep("=", 50))

-- Exit with appropriate code
if fail_count > 0 then
  os.exit(1)
else
  os.exit(0)
end
