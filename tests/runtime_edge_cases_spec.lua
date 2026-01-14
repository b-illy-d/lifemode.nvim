#!/usr/bin/env -S nvim -l

-- Runtime edge case tests - testing plugin behavior in different environments
-- Usage: nvim -l tests/runtime_edge_cases_spec.lua

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

describe("Runtime: Path Existence Validation", function()
  test("accepts non-existent vault_root (lazy validation)", function()
    lifemode._reset_for_testing()
    -- Plugin should not validate path existence at setup time
    -- (user might create it later, or it might be mounted later)
    assert_no_error(function()
      lifemode.setup({ vault_root = '/nonexistent/path/to/vault' })
    end)
  end)

  test("accepts relative path (user's choice)", function()
    lifemode._reset_for_testing()
    -- Relative paths might be valid in some contexts
    assert_no_error(function()
      lifemode.setup({ vault_root = './relative/path' })
    end)
  end)

  test("accepts home directory expansion pattern", function()
    lifemode._reset_for_testing()
    assert_no_error(function()
      lifemode.setup({ vault_root = '~/Documents/vault' })
    end)
  end)
end)

describe("Runtime: Path Normalization", function()
  test("does not normalize trailing slashes (stored as-is)", function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '/path/to/vault/' })
    local config = lifemode.get_config()
    -- Check if trailing slash is preserved
    if config.vault_root ~= '/path/to/vault/' then
      error("trailing slash not preserved: " .. config.vault_root)
    end
  end)

  test("does not normalize path separators (stored as-is)", function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '/path//with///multiple////slashes' })
    local config = lifemode.get_config()
    -- Check if path is stored as-is
    if config.vault_root ~= '/path//with///multiple////slashes' then
      error("path separators normalized: " .. config.vault_root)
    end
  end)

  test("does not expand home directory at setup (stored as-is)", function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '~/vault' })
    local config = lifemode.get_config()
    -- Check if tilde is preserved
    if config.vault_root ~= '~/vault' then
      error("home directory expanded at setup: " .. config.vault_root)
    end
  end)
end)

describe("Runtime: Command Name Conflicts", function()
  test("command registration does not conflict with existing commands", function()
    -- Create a dummy command with different name first
    pcall(function()
      vim.api.nvim_del_user_command('TestCommand')
    end)
    vim.api.nvim_create_user_command('TestCommand', function() end, {})

    lifemode._reset_for_testing()
    assert_no_error(function()
      lifemode.setup({ vault_root = '/test' })
    end)

    -- Cleanup
    pcall(function()
      vim.api.nvim_del_user_command('TestCommand')
    end)
  end)

  test("re-registering LifeModeHello does not error (silent override)", function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '/first' })

    -- Setup again should override command
    assert_no_error(function()
      lifemode.setup({ vault_root = '/second' })
    end)
  end)
end)

describe("Runtime: Config Merging Behavior", function()
  test("partial config update preserves unspecified defaults", function()
    lifemode._reset_for_testing()
    lifemode.setup({ vault_root = '/first', leader = '<leader>x' })
    -- Update only vault_root
    lifemode.setup({ vault_root = '/second' })
    local config = lifemode.get_config()

    -- Does it preserve the previous leader or reset to default?
    -- This tests vim.tbl_extend behavior
    if config.leader ~= '<leader>x' and config.leader ~= '<Space>' then
      error("unexpected leader: " .. config.leader)
    end
    -- Actually it should reset to default based on current implementation
    assert_equals('<Space>', config.leader)
  end)

  test("empty table for user_config uses all defaults", function()
    lifemode._reset_for_testing()
    -- This should fail due to missing vault_root
    assert_error(function()
      lifemode.setup({})
    end, "vault_root is required")
  end)
end)

describe("Runtime: Neovim API Edge Cases", function()
  test("nvim_echo handles long output without error", function()
    lifemode._reset_for_testing()
    local very_long_path = string.rep('/very/long/path', 50)
    lifemode.setup({ vault_root = very_long_path })

    assert_no_error(function()
      vim.cmd('LifeModeHello')
    end)
  end)

  test("nvim_echo handles special characters without error", function()
    lifemode._reset_for_testing()
    lifemode.setup({
      vault_root = '/path/with/special/chars/"quotes"/and/\\backslashes\\',
    })

    assert_no_error(function()
      vim.cmd('LifeModeHello')
    end)
  end)
end)

describe("Runtime: Multiple setup() Calls Memory Leak", function()
  test("multiple setup calls do not accumulate commands", function()
    lifemode._reset_for_testing()

    -- Call setup many times
    for i = 1, 10 do
      lifemode.setup({ vault_root = '/test' .. i })
    end

    -- Check that only one command exists
    local commands = vim.api.nvim_get_commands({})
    local lifemode_commands = 0
    for name, _ in pairs(commands) do
      if name:match('^LifeMode') then
        lifemode_commands = lifemode_commands + 1
      end
    end

    if lifemode_commands ~= 1 then
      error("expected 1 LifeMode command, found " .. lifemode_commands)
    end
  end)
end)

describe("Runtime: Type Coercion in Output", function()
  test("command output handles numeric types gracefully", function()
    lifemode._reset_for_testing()
    lifemode.setup({
      vault_root = '/test',
      max_depth = 100  -- numeric
    })

    assert_no_error(function()
      vim.cmd('LifeModeHello')
    end)
  end)

  -- Test removed: Type validation now prevents invalid types at setup()
  -- Previously this tested that the command wouldn't crash with wrong types,
  -- but now setup() correctly rejects them (tested in edge_cases_spec.lua)
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
