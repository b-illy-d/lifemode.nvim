#!/usr/bin/env -S nvim -l

-- View buffer creation tests

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
local lifemode = require('lifemode')
local view = require('lifemode.view')

describe("lifemode.view.create_buffer", function()
  test("creates a valid buffer", function()
    local bufnr = view.create_buffer()
    assert_true(bufnr > 0, "Buffer number should be positive")
    assert_true(vim.api.nvim_buf_is_valid(bufnr), "Buffer should be valid")
  end)

  test("sets buftype to nofile", function()
    local bufnr = view.create_buffer()
    local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
    assert_equals('nofile', buftype)
  end)

  test("disables swapfile", function()
    local bufnr = view.create_buffer()
    local swapfile = vim.api.nvim_buf_get_option(bufnr, 'swapfile')
    assert_equals(false, swapfile)
  end)

  test("sets bufhidden to wipe", function()
    local bufnr = view.create_buffer()
    local bufhidden = vim.api.nvim_buf_get_option(bufnr, 'bufhidden')
    assert_equals('wipe', bufhidden)
  end)

  test("sets buffer name to [LifeMode] or [LifeMode:N]", function()
    local bufnr = view.create_buffer()
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    -- Get just the basename (may include full path)
    local basename = bufname:match("([^/]+)$") or bufname
    -- Accept either [LifeMode] or [LifeMode:N] format
    local matches = basename == '[LifeMode]' or basename:match('^%[LifeMode:%d+%]$')
    assert_true(matches, "Buffer name should be [LifeMode] or [LifeMode:N], got: " .. basename)
  end)

  test("sets filetype to lifemode", function()
    local bufnr = view.create_buffer()
    local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
    assert_equals('lifemode', filetype)
  end)

  test("opens buffer in current window", function()
    local initial_bufnr = vim.api.nvim_get_current_buf()
    local bufnr = view.create_buffer()
    local current_bufnr = vim.api.nvim_get_current_buf()
    assert_equals(bufnr, current_bufnr)
  end)

  test("returns buffer number", function()
    local bufnr = view.create_buffer()
    assert_equals('number', type(bufnr))
    assert_true(bufnr > 0, "Buffer number should be positive")
  end)
end)

describe(":LifeModeOpen command", function()
  test("is defined after setup", function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '/test/vault' })

    local cmd = vim.api.nvim_get_commands({})['LifeModeOpen']
    assert_true(cmd ~= nil, "LifeModeOpen command should be defined")
  end)

  test("creates a view buffer when executed", function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '/test/vault' })

    local initial_bufnr = vim.api.nvim_get_current_buf()
    vim.cmd('LifeModeOpen')
    local current_bufnr = vim.api.nvim_get_current_buf()

    assert_true(current_bufnr ~= initial_bufnr, "Should switch to new buffer")
    assert_true(vim.api.nvim_buf_is_valid(current_bufnr), "Buffer should be valid")

    local filetype = vim.api.nvim_buf_get_option(current_bufnr, 'filetype')
    assert_equals('lifemode', filetype)
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
