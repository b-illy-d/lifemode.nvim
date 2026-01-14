#!/usr/bin/env -S nvim -l

-- UUID generation tests

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

local function describe(name, fn)
  print(string.format("\n%s:", name))
  fn()
end

-- Load the module
package.path = './lua/?.lua;' .. package.path
local uuid = require('lifemode.uuid')

describe("UUID Generation", function()
  test("generates UUID v4 format", function()
    local id = uuid.generate()
    -- UUID v4 format: 8-4-4-4-12 hex characters
    local pattern = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
    assert_true(id:match(pattern) ~= nil, "UUID does not match v4 format: " .. id)
  end)

  test("generates lowercase UUIDs", function()
    local id = uuid.generate()
    assert_equals(id, id:lower())
  end)

  test("generates unique UUIDs", function()
    local id1 = uuid.generate()
    local id2 = uuid.generate()
    assert_true(id1 ~= id2, "Generated duplicate UUIDs")
  end)

  test("generates UUIDs without leading/trailing whitespace", function()
    local id = uuid.generate()
    assert_equals(id, id:match("^%s*(.-)%s*$"))
  end)

  test("generates UUIDs with correct length (36 chars)", function()
    local id = uuid.generate()
    assert_equals(36, #id)
  end)
end)

-- Summary
print(string.format("\n=== UUID Tests Summary ==="))
print(string.format("Total: %d | Pass: %d | Fail: %d", test_count, pass_count, fail_count))

if fail_count > 0 then
  os.exit(1)
else
  os.exit(0)
end
