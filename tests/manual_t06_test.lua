#!/usr/bin/env -S nvim -l

-- Manual acceptance test for T06: Basic wikilink extraction
-- Requirement: :LifeModeRefs shows refs for node under cursor

-- Setup
package.path = package.path .. ';lua/?.lua;lua/?/init.lua'

local lifemode = require('lifemode')

-- Configure
lifemode.setup({
  vault_root = '/tmp/test-vault',
  leader = '<Space>',
})

print("\n=== T06: Basic Wikilink Extraction - Manual Test ===\n")

-- Create test buffer with wikilinks
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(bufnr)

local lines = {
  "# Project Overview ^h1",
  "",
  "- See [[Introduction]] for context ^t1",
  "- Read [[Setup#Installation]] for setup ^t2",
  "- Check [[Tasks^task-list]] for TODOs ^t3",
  "",
  "# Related Pages ^h2",
  "",
  "- [[Introduction]] has background info ^t4",
  "- [[Setup]] contains configuration ^t5",
}

vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

-- Test 1: Show refs for node with single link
print("Test 1: Position cursor on line with [[Introduction]]")
vim.api.nvim_win_set_cursor(0, {3, 0})  -- Line 3: "- See [[Introduction]]..."
print("  Line: " .. lines[3])
print("  Run: :LifeModeRefs")
print("  Expected:")
print("    - Outbound links (1): -> Introduction (wikilink)")
print("    - Backlinks (1): <- t4 (from 'Introduction has background info')")
print("")

-- Test 2: Show refs for node with heading link
print("Test 2: Position cursor on line with [[Setup#Installation]]")
vim.api.nvim_win_set_cursor(0, {4, 0})  -- Line 4
print("  Line: " .. lines[4])
print("  Run: :LifeModeRefs")
print("  Expected:")
print("    - Outbound links (1): -> Setup#Installation (wikilink)")
print("    - Backlinks (0): (none)")
print("")

-- Test 3: Show refs for node with block reference
print("Test 3: Position cursor on line with [[Tasks^task-list]]")
vim.api.nvim_win_set_cursor(0, {5, 0})  -- Line 5
print("  Line: " .. lines[5])
print("  Run: :LifeModeRefs")
print("  Expected:")
print("    - Outbound links (1): -> Tasks^task-list (wikilink)")
print("    - Backlinks (0): (none)")
print("")

-- Test 4: Show refs for node with multiple backlinks
print("Test 4: Position cursor on line 9 (has [[Introduction]] link)")
vim.api.nvim_win_set_cursor(0, {9, 0})  -- Line 9
print("  Line: " .. lines[9])
print("  Run: :LifeModeRefs")
print("  Expected:")
print("    - Outbound links (1): -> Introduction (wikilink)")
print("    - Backlinks (1): <- t1 (from 'See [[Introduction]] for context')")
print("")

-- Test 5: Show refs for node without links
print("Test 5: Position cursor on heading without links")
vim.api.nvim_win_set_cursor(0, {1, 0})  -- Line 1: heading
print("  Line: " .. lines[1])
print("  Run: :LifeModeRefs")
print("  Expected:")
print("    - Outbound links (0): (none)")
print("    - Backlinks (0): (none)")
print("")

print("=== Acceptance Criteria ===")
print("1. :LifeModeRefs command exists")
print("2. Shows outbound links for node at cursor")
print("3. Shows backlinks (nodes referencing current node)")
print("4. Handles all wikilink formats: [[Page]], [[Page#Heading]], [[Page^id]]")
print("5. Reports 'No node found at cursor' if cursor not on a node")
print("")

print("=== Manual Steps ===")
print("1. Run this file: nvim -l tests/manual_t06_test.lua")
print("2. Buffer with test content will be displayed")
print("3. Follow Test 1-5 instructions above")
print("4. Verify command output matches expected results")
print("")

-- Stay in Neovim for manual testing
print("Ready for manual testing. Cursor is at line 3.")
print("Run :LifeModeRefs to test the command.")
print("Use :quit to exit when done.\n")

-- Enter command mode (simulate)
vim.cmd("redraw")
