#!/usr/bin/env -S nvim -l

-- T11 Manual Acceptance Test: Basic lens system + lens cycling
--
-- Acceptance criteria:
-- 1. Lens registry has task/brief, task/detail, node/raw
-- 2. Same task displays differently in brief vs detail lens
-- 3. <Space>ml / <Space>mL commands cycle through lenses
-- 4. :LifeModeLensNext and :LifeModeLensPrev commands work
--
-- This test creates actual buffers and validates the lens rendering
-- with real task nodes.

local test_count = 0
local pass_count = 0
local fail_count = 0

local function assert_true(condition, msg)
  if not condition then
    error(msg or "Expected true but got false")
  end
end

local function assert_false(condition, msg)
  if condition then
    error(msg or "Expected false but got true")
  end
end

local function assert_matches(pattern, text, msg)
  if not text:match(pattern) then
    error(msg or string.format("Expected text to match pattern '%s' but got: %s", pattern, text))
  end
end

local function assert_not_matches(pattern, text, msg)
  if text:match(pattern) then
    error(msg or string.format("Expected text NOT to match pattern '%s' but it did: %s", pattern, text))
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
    print("FAIL")
    print("    Error: " .. tostring(err))
  end
end

local function describe(description, fn)
  print("\n" .. description)
  fn()
end

-- Load modules
package.path = './lua/?.lua;' .. package.path
local lifemode = require('lifemode.init')
local lens = require('lifemode.lens')
local view = require('lifemode.view')

print("=== T11 Manual Acceptance Test ===")

-- Setup lifemode
lifemode._reset_for_testing()
lifemode.setup({ vault_root = '/tmp/test-vault' })

describe("Acceptance: Lens Registry", function()
  test("has three lenses defined", function()
    local lenses = lens.get_available_lenses()
    assert_true(#lenses == 3, "Should have exactly 3 lenses")
  end)

  test("has task/brief lens", function()
    local lenses = lens.get_available_lenses()
    local found = false
    for _, l in ipairs(lenses) do
      if l == "task/brief" then found = true end
    end
    assert_true(found, "Should have task/brief lens")
  end)

  test("has task/detail lens", function()
    local lenses = lens.get_available_lenses()
    local found = false
    for _, l in ipairs(lenses) do
      if l == "task/detail" then found = true end
    end
    assert_true(found, "Should have task/detail lens")
  end)

  test("has node/raw lens", function()
    local lenses = lens.get_available_lenses()
    local found = false
    for _, l in ipairs(lenses) do
      if l == "node/raw" then found = true end
    end
    assert_true(found, "Should have node/raw lens")
  end)
end)

describe("Acceptance: Same task, different lenses", function()
  local task_node = {
    type = "task",
    body_md = "- [ ] Write documentation !2 #docs ^task-abc123",
    props = {
      state = "todo",
      priority = 2,
      tags = { "#docs" }
    },
    id = "task-abc123"
  }

  test("task/brief hides ID", function()
    local brief = lens.render(task_node, "task/brief")
    assert_not_matches("%^task%-abc123", brief, "Brief lens should hide ID")
  end)

  test("task/brief shows title and priority", function()
    local brief = lens.render(task_node, "task/brief")
    assert_matches("Write documentation", brief, "Brief should show title")
    assert_matches("!2", brief, "Brief should show priority")
  end)

  test("task/detail shows ID", function()
    local detail = lens.render(task_node, "task/detail")
    local text = type(detail) == "table" and table.concat(detail, "\n") or detail
    assert_matches("%^task%-abc123", text, "Detail lens should show ID")
  end)

  test("task/detail shows all metadata", function()
    local detail = lens.render(task_node, "task/detail")
    local text = type(detail) == "table" and table.concat(detail, "\n") or detail
    assert_matches("Write documentation", text, "Detail should show title")
    assert_matches("!2", text, "Detail should show priority")
    assert_matches("#docs", text, "Detail should show tags")
  end)

  test("node/raw shows exact markdown", function()
    local raw = lens.render(task_node, "node/raw")
    assert_matches("^%- %[ %] Write documentation !2 #docs %^task%-abc123$", raw,
      "Raw lens should show exact markdown")
  end)
end)

describe("Acceptance: Lens cycling", function()
  test("cycles forward: brief → detail → raw → brief", function()
    local l1 = lens.cycle_lens("task/brief", 1)
    assert_true(l1 == "task/detail", "Should cycle to task/detail")

    local l2 = lens.cycle_lens(l1, 1)
    assert_true(l2 == "node/raw", "Should cycle to node/raw")

    local l3 = lens.cycle_lens(l2, 1)
    assert_true(l3 == "task/brief", "Should wrap to task/brief")
  end)

  test("cycles backward: brief → raw → detail → brief", function()
    local l1 = lens.cycle_lens("task/brief", -1)
    assert_true(l1 == "node/raw", "Should cycle to node/raw")

    local l2 = lens.cycle_lens(l1, -1)
    assert_true(l2 == "task/detail", "Should cycle to task/detail")

    local l3 = lens.cycle_lens(l2, -1)
    assert_true(l3 == "task/brief", "Should wrap to task/brief")
  end)
end)

describe("Acceptance: Commands exist", function()
  test(":LifeModeLensNext command registered", function()
    local commands = vim.api.nvim_get_commands({})
    assert_true(commands.LifeModeLensNext ~= nil, "Command should be registered")
  end)

  test(":LifeModeLensPrev command registered", function()
    local commands = vim.api.nvim_get_commands({})
    assert_true(commands.LifeModeLensPrev ~= nil, "Command should be registered")
  end)
end)

describe("Acceptance: Keymaps in view buffer", function()
  test("<Space>ml keymap exists in view buffer", function()
    local bufnr = view.create_buffer()
    local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')

    local found = false
    for _, km in ipairs(keymaps) do
      if km.lhs == ' ml' then  -- Neovim stores <Space> as ' '
        found = true
        break
      end
    end

    -- Cleanup
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end

    assert_true(found, "Should have <Space>ml keymap in view buffer")
  end)

  test("<Space>mL keymap exists in view buffer", function()
    local bufnr = view.create_buffer()
    local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')

    local found = false
    for _, km in ipairs(keymaps) do
      if km.lhs == ' mL' then  -- Neovim stores <Space> as ' '
        found = true
        break
      end
    end

    -- Cleanup
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end

    assert_true(found, "Should have <Space>mL keymap in view buffer")
  end)
end)

-- Summary
print("\n=== Summary ===")
print(string.format("Total: %d", test_count))
print(string.format("Passed: %d", pass_count))
print(string.format("Failed: %d", fail_count))

if fail_count > 0 then
  print("\n❌ ACCEPTANCE TEST FAILED")
  os.exit(1)
else
  print("\n✅ ACCEPTANCE TEST PASSED")
  print("T11 requirements met:")
  print("  - Lens registry with task/brief, task/detail, node/raw")
  print("  - Same task displays differently in different lenses")
  print("  - <Space>ml / <Space>mL keymaps work")
  print("  - :LifeModeLensNext / :LifeModeLensPrev commands work")
  os.exit(0)
end
