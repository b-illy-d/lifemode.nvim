#!/usr/bin/env -S nvim -l

-- Manual acceptance test for T18: Multi-file index (vault scan MVP)
-- Tests that gr works across files

-- Add lua directory to package path
package.path = package.path .. ';lua/?.lua;lua/?/init.lua'

local lifemode = require('lifemode')
local index = require('lifemode.index')

local test_count = 0
local pass_count = 0
local fail_count = 0

local function assert_true(condition, msg)
  if not condition then
    error(msg or "Expected true but got false")
  end
end

local function assert_equals(expected, actual, msg)
  if expected ~= actual then
    error(string.format("%s: expected %s, got %s", msg or "Assertion failed", tostring(expected), tostring(actual)))
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

-- Create test vault
local vault_root = "/tmp/lifemode_t18_vault_" .. os.time()
os.execute("mkdir -p " .. vault_root)

-- File 1: main.md with wikilink
local f1 = io.open(vault_root .. "/main.md", "w")
f1:write("# Main Page ^main-heading\n- This is the main page with a reference to [[target]] page. ^main-1\n- Another reference to [[target]] here too. ^main-2\n\n## Bible Reference\n- Key verse: John 3:16 is important. ^main-3\n")
f1:close()

-- File 2: notes.md with wikilink and Bible ref
local f2 = io.open(vault_root .. "/notes.md", "w")
f2:write("# Notes\n- Note about [[target]] ^note-1\n- Another mention of John 3:16 ^note-2\n")
f2:close()

-- File 3: target.md (the referenced page)
local f3 = io.open(vault_root .. "/target.md", "w")
f3:write("# Target\nThis is the target page. ^target-1\n")
f3:close()

-- Setup lifemode
lifemode._reset_for_testing()
lifemode.setup({ vault_root = vault_root })

describe("T18 Acceptance: Multi-file index", function()
  test("scan_vault finds all test files", function()
    local files = index.scan_vault(vault_root)
    assert_equals(3, #files, "Should find 3 markdown files")
  end)

  test("build_vault_index creates node locations", function()
    local idx = index.build_vault_index(vault_root)

    -- Check nodes are indexed
    assert_true(idx.node_locations["main-1"] ~= nil, "Should index main-1")
    assert_true(idx.node_locations["main-2"] ~= nil, "Should index main-2")
    assert_true(idx.node_locations["main-3"] ~= nil, "Should index main-3")
    assert_true(idx.node_locations["note-1"] ~= nil, "Should index note-1")
    assert_true(idx.node_locations["note-2"] ~= nil, "Should index note-2")
  end)

  test("build_vault_index creates backlinks for wikilinks", function()
    local idx = index.build_vault_index(vault_root)

    -- Check wikilink backlinks
    local backlinks = index.get_backlinks(idx, "target")
    assert_true(#backlinks >= 2, "Should have at least 2 backlinks to target")
  end)

  test("build_vault_index creates backlinks for Bible verses", function()
    local idx = index.build_vault_index(vault_root)

    -- Check Bible verse backlinks
    local backlinks = index.get_backlinks(idx, "bible:john:3:16")
    assert_equals(2, #backlinks, "Should have 2 backlinks to John 3:16")
  end)

  test(":LifeModeRebuildIndex command works", function()
    -- Execute rebuild command
    vim.cmd('LifeModeRebuildIndex')

    -- Check config has index
    local config = lifemode.get_config()
    assert_true(config.vault_index ~= nil, "Config should have vault_index")
    assert_true(config.vault_index.node_locations ~= nil, "Index should have node_locations")
    assert_true(config.vault_index.backlinks ~= nil, "Index should have backlinks")
  end)

  test("gr finds references across multiple files for wikilinks", function()
    -- Rebuild index first
    vim.cmd('LifeModeRebuildIndex')

    -- Load main.md into buffer
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, vault_root .. "/main.md")
    local lines = {}
    local f = io.open(vault_root .. "/main.md", "r")
    for line in f:lines() do
      table.insert(lines, line)
    end
    f:close()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_current_buf(buf)

    -- Position cursor on [[target]] wikilink (line 2, col 41)
    vim.api.nvim_win_set_cursor(0, {2, 41})

    -- Call find_references_at_cursor
    local references = require('lifemode.references')
    local config = lifemode.get_config()
    local refs = references.find_references_in_vault("target", "wikilink", config.vault_index)

    -- Should find references from both main.md and notes.md
    assert_true(#refs >= 2, "Should find at least 2 references across files")
  end)

  test("gr finds references across multiple files for Bible verses", function()
    -- Rebuild index first
    vim.cmd('LifeModeRebuildIndex')

    -- Call find_references_in_vault directly (no need to load buffer)
    local references = require('lifemode.references')
    local config = lifemode.get_config()
    local refs = references.find_references_in_vault("bible:john:3:16", "bible_verse", config.vault_index)

    -- Should find references from both main.md and notes.md
    assert_equals(2, #refs, "Should find 2 references to John 3:16 across files")
  end)

  test("get_node_location returns correct file and line", function()
    local idx = index.build_vault_index(vault_root)

    local loc = index.get_node_location(idx, "main-1")
    assert_true(loc ~= nil, "Should find main-1")
    assert_true(loc.file:match("main.md") ~= nil, "Should be in main.md")
    assert_equals(2, loc.line, "Should be on line 2")
  end)

  test("Vault index survives config updates", function()
    vim.cmd('LifeModeRebuildIndex')
    local config1 = lifemode.get_config()
    local idx1 = config1.vault_index

    -- Reconfigure (without rebuilding index)
    lifemode.setup({ vault_root = vault_root, leader = '<leader>' })
    local config2 = lifemode.get_config()

    -- Index should be lost (expected - setup replaces config)
    assert_true(config2.vault_index == nil, "Index lost on setup (expected)")

    -- Rebuild again
    vim.cmd('LifeModeRebuildIndex')
    local config3 = lifemode.get_config()
    assert_true(config3.vault_index ~= nil, "Index restored after rebuild")
  end)
end)

-- Cleanup
os.execute("rm -rf " .. vault_root)

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
