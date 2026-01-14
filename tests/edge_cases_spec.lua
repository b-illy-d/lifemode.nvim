#!/usr/bin/env -S nvim -l

-- Edge case tests to hunt for silent failures
-- Usage: nvim -l tests/edge_cases_spec.lua

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

describe("Edge Case: Empty Strings", function()
  test("rejects empty string for vault_root", function()
    lifemode._reset_for_testing()
    assert_error(function()
      lifemode.setup({ vault_root = '' })
    end)
  end)

  test("rejects whitespace-only vault_root", function()
    lifemode._reset_for_testing()
    assert_error(function()
      lifemode.setup({ vault_root = '   ' })
    end)
  end)

  test("accepts empty leader (edge case: user wants no leader)", function()
    lifemode._reset_for_testing()
    assert_no_error(function()
      lifemode.setup({ vault_root = '/test', leader = '' })
    end)
  end)

  test("accepts empty bible_version (edge case: disable bible features)", function()
    lifemode._reset_for_testing()
    assert_no_error(function()
      lifemode.setup({ vault_root = '/test', bible_version = '' })
    end)
  end)
end)

describe("Edge Case: Nil Values", function()
  test("explicitly nil vault_root is treated as missing", function()
    lifemode._reset_for_testing()
    assert_error(function()
      lifemode.setup({ vault_root = nil })
    end, "vault_root is required")
  end)

  test("explicitly nil optional config uses defaults", function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '/test', leader = nil })
    local config = lifemode.get_config()
    assert_equals('<Space>', config.leader)
  end)
end)

describe("Edge Case: Invalid Types", function()
  test("rejects table for vault_root", function()
    lifemode._reset_for_testing()
    assert_error(function()
      lifemode.setup({ vault_root = {} })
    end, "vault_root must be a string")
  end)

  test("rejects function for vault_root", function()
    lifemode._reset_for_testing()
    assert_error(function()
      lifemode.setup({ vault_root = function() return '/test' end })
    end, "vault_root must be a string")
  end)

  test("rejects wrong type for leader", function()
    lifemode._reset_for_testing()
    assert_error(function()
      lifemode.setup({ vault_root = '/test', leader = 123 })
    end, "leader must be a string")
  end)

  test("rejects wrong type for max_depth", function()
    lifemode._reset_for_testing()
    assert_error(function()
      lifemode.setup({ vault_root = '/test', max_depth = '5' })
    end, "max_depth must be a number")
  end)

  test("rejects wrong type for bible_version", function()
    lifemode._reset_for_testing()
    assert_error(function()
      lifemode.setup({ vault_root = '/test', bible_version = 123 })
    end, "bible_version must be a string")
  end)
end)

describe("Edge Case: Special Characters in vault_root", function()
  test("accepts path with spaces", function()
    lifemode._reset_for_testing()
    assert_no_error(function()
      lifemode.setup({ vault_root = '/path with spaces/vault' })
    end)
  end)

  test("accepts path with special chars", function()
    lifemode._reset_for_testing()
    assert_no_error(function()
      lifemode.setup({ vault_root = '/path-with_special.chars/vault' })
    end)
  end)

  test("accepts path with unicode", function()
    lifemode._reset_for_testing()
    assert_no_error(function()
      lifemode.setup({ vault_root = '/path/with/日本語/vault' })
    end)
  end)
end)

describe("Edge Case: Command Registration", function()
  test("command can be executed multiple times", function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '/test' })

    -- Execute command multiple times
    assert_no_error(function()
      vim.cmd('LifeModeHello')
      vim.cmd('LifeModeHello')
      vim.cmd('LifeModeHello')
    end)
  end)

  test("command survives config updates", function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '/first' })
    lifemode.setup({ vault_root = '/second' })

    assert_no_error(function()
      vim.cmd('LifeModeHello')
    end)
  end)
end)

describe("Edge Case: get_config() Without setup()", function()
  test("get_config fails gracefully when setup not called", function()
    lifemode._reset_for_testing()
    assert_error(function()
      lifemode.get_config()
    end, "not configured")
  end)
end)

describe("Edge Case: Unknown Config Keys", function()
  test("unknown config keys are silently stored (future extension)", function()
    lifemode._reset_for_testing()
    assert_no_error(function()
      lifemode.setup({
        vault_root = '/test',
        unknown_key = 'value',
        another_unknown = 123
      })
    end)
    local config = lifemode.get_config()
    -- Unknown keys should be stored (forward compatibility)
    assert_equals('value', config.unknown_key)
    assert_equals(123, config.another_unknown)
  end)
end)

describe("Edge Case: Boundary Values", function()
  test("rejects max_depth = 0", function()
    lifemode._reset_for_testing()
    assert_error(function()
      lifemode.setup({ vault_root = '/test', max_depth = 0 })
    end, "max_depth must be between 1 and 100")
  end)

  test("rejects negative max_depth", function()
    lifemode._reset_for_testing()
    assert_error(function()
      lifemode.setup({ vault_root = '/test', max_depth = -1 })
    end, "max_depth must be between 1 and 100")
  end)

  test("rejects very large max_depth", function()
    lifemode._reset_for_testing()
    assert_error(function()
      lifemode.setup({ vault_root = '/test', max_depth = 999999 })
    end, "max_depth must be between 1 and 100")
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
