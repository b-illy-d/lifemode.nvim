#!/usr/bin/env -S nvim -l

-- Minimal test runner for LifeMode MVP
-- Usage: nvim -l tests/run_tests.lua

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

describe("lifemode.setup", function()
  test("requires vault_root to be provided", function()
    lifemode._reset_for_testing()
    assert_error(function()
      lifemode.setup({})
    end, "vault_root is required")
  end)

  test("requires vault_root to be a string", function()
    lifemode._reset_for_testing()
    assert_error(function()
      lifemode.setup({ vault_root = 123 })
    end, "vault_root must be a string")
  end)

  test("accepts valid vault_root", function()
    lifemode._reset_for_testing()
    assert_no_error(function()
      lifemode.setup({ vault_root = '/path/to/vault' })
    end)
  end)

  test("sets default values for optional config", function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '/path/to/vault' })
    local config = lifemode.get_config()

    assert_equals('/path/to/vault', config.vault_root)
    assert_equals('<Space>', config.leader)
    assert_equals(10, config.max_depth)
    assert_equals('ESV', config.bible_version)
  end)

  test("allows overriding optional config", function()
    lifemode._reset_for_testing()
    lifemode.setup({
      vault_root = '/path/to/vault',
      leader = '<leader>m',
      max_depth = 5,
      bible_version = 'NIV'
    })
    local config = lifemode.get_config()

    assert_equals('<leader>m', config.leader)
    assert_equals(5, config.max_depth)
    assert_equals('NIV', config.bible_version)
  end)

  test("updates config when setup called multiple times", function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '/first' })
    lifemode.setup({ vault_root = '/second', leader = '<leader>x' })
    local config = lifemode.get_config()

    assert_equals('/second', config.vault_root)
    assert_equals('<leader>x', config.leader)
  end)
end)

describe(":LifeModeHello command", function()
  test("is defined after setup", function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '/test/vault' })

    local cmd = vim.api.nvim_get_commands({})['LifeModeHello']
    if not cmd then
      error("LifeModeHello command not defined")
    end
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
