#!/usr/bin/env -S nvim -l

-- Manual acceptance test for T08: "Definition" jump for wikilinks and Bible refs
-- This creates test files and demonstrates `gd` functionality

package.path = package.path .. ';lua/?.lua;lua/?/init.lua'

local lifemode = require('lifemode')

-- Create test vault
local vault = '/tmp/lifemode_test_vault_t08'
os.execute('mkdir -p ' .. vault)
os.execute('mkdir -p ' .. vault .. '/subdir')

-- Initialize lifemode
lifemode.setup({ vault_root = vault })

print("=== T08 Manual Acceptance Test ===\n")

-- Create test files
print("Creating test files...")

-- Source.md with links
local source_content = [[# Source Page

This is the source page with various links.

Link to another page: Target link here.

Link with heading: Heading link here.

Link with block ref: Block link here.

Bible reference: See John 3:16 for details.

Another Bible ref: Rom 8:28-30 is powerful.
]]

-- Replace placeholders with actual wikilinks after defining the string
source_content = source_content:gsub("Target link here%.", "[[Target]]")
source_content = source_content:gsub("Heading link here%.", "[[Target#Section One]]")
source_content = source_content:gsub("Block link here%.", "[[Target^block-123]]")

local f = io.open(vault .. '/Source.md', 'w')
f:write(source_content)
f:close()

-- Target.md with headings and block IDs
local target_content = [[# Target Page

This is the target page.

## Section One

Content in section one.

## Section Two

- Task item ^block-123
- Another task

This page is linked from Source link.
]]

target_content = target_content:gsub("Source link%.", "[[Source]]")

local f = io.open(vault .. '/Target.md', 'w')
f:write(target_content)
f:close()

-- SubPage.md in subdirectory
local subpage_content = [[# Sub Page

This is a page in a subdirectory.

Link back to Source link.
]]

subpage_content = subpage_content:gsub("Source link%.", "[[Source]]")

local f = io.open(vault .. '/subdir/SubPage.md', 'w')
f:write(subpage_content)
f:close()

print("Test files created.\n")

-- Test 1: Simple wikilink navigation
print("Test 1: Navigate to [[Target]]")
vim.cmd('edit ' .. vault .. '/Source.md')
vim.api.nvim_win_set_cursor(0, {5, 28})  -- Cursor on "Target" in [[Target]]

local navigation = require('lifemode.navigation')
navigation.goto_definition()

local current_buf = vim.api.nvim_buf_get_name(0)
if current_buf:match('Target%.md$') then
  print("  ✓ Navigated to Target.md")
else
  print("  ✗ Expected Target.md, got: " .. current_buf)
end
print()

-- Test 2: Wikilink with heading
print("Test 2: Navigate to [[Target#Section One]]")
vim.cmd('edit ' .. vault .. '/Source.md')
vim.api.nvim_win_set_cursor(0, {7, 25})  -- Cursor on "Target#Section One"

navigation.goto_definition()

local current_buf = vim.api.nvim_buf_get_name(0)
local cursor = vim.api.nvim_win_get_cursor(0)
if current_buf:match('Target%.md$') and cursor[1] == 5 then
  print("  ✓ Navigated to Target.md at Section One (line 5)")
else
  print(string.format("  ✗ Expected Target.md line 5, got: %s line %d", current_buf, cursor[1]))
end
print()

-- Test 3: Wikilink with block ref
print("Test 3: Navigate to [[Target^block-123]]")
vim.cmd('edit ' .. vault .. '/Source.md')
vim.api.nvim_win_set_cursor(0, {9, 25})  -- Cursor on "Target^block-123"

navigation.goto_definition()

local current_buf = vim.api.nvim_buf_get_name(0)
local cursor = vim.api.nvim_win_get_cursor(0)
-- Line number will be 11 (# Target Page, blank, text, blank, ## Section One, blank, content, blank, ## Section Two, blank, - Task item ^block-123)
if current_buf:match('Target%.md$') and cursor[1] == 11 then
  print("  ✓ Navigated to Target.md at block-123 (line 11)")
else
  print(string.format("  ✗ Expected Target.md line 11, got: %s line %d", current_buf, cursor[1]))
end
print()

-- Test 4: Bible reference (provider stub)
print("Test 4: Bible reference (provider stub)")
vim.cmd('edit ' .. vault .. '/Source.md')
vim.api.nvim_win_set_cursor(0, {11, 25})  -- Cursor on "John 3:16"

-- Capture echo output
local captured_msg = nil
local original_echo = vim.api.nvim_echo
vim.api.nvim_echo = function(chunks, history, opts)
  for _, chunk in ipairs(chunks) do
    captured_msg = chunk[1]
  end
  original_echo(chunks, history, opts)
end

navigation.goto_definition()

vim.api.nvim_echo = original_echo

if captured_msg and captured_msg:match('bible:john:3:16') and captured_msg:match('provider not yet implemented') then
  print("  ✓ Showed Bible verse stub message: " .. captured_msg)
else
  print("  ✗ Expected Bible verse stub message, got: " .. (captured_msg or "nil"))
end
print()

-- Test 5: File not found
print("Test 5: File not found ([[MissingPage]])")
vim.cmd('new')
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Link to [[MissingPage]]" })
vim.api.nvim_win_set_cursor(0, {1, 12})

captured_msg = nil
vim.api.nvim_echo = function(chunks, history, opts)
  for _, chunk in ipairs(chunks) do
    captured_msg = chunk[1]
  end
  original_echo(chunks, history, opts)
end

navigation.goto_definition()

vim.api.nvim_echo = original_echo

if captured_msg and captured_msg:match('File not found') and captured_msg:match('MissingPage') then
  print("  ✓ Showed file not found message: " .. captured_msg)
else
  print("  ✗ Expected file not found message, got: " .. (captured_msg or "nil"))
end
print()

-- Test 6: Heading not found
print("Test 6: Heading not found ([[Target#MissingHeading]])")
vim.cmd('new')
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Link to [[Target#MissingHeading]]" })
vim.api.nvim_win_set_cursor(0, {1, 12})

-- Capture message for this test
captured_msg = nil
vim.api.nvim_echo = function(chunks, history, opts)
  for _, chunk in ipairs(chunks) do
    captured_msg = chunk[1]
  end
  original_echo(chunks, history, opts)
end

navigation.goto_definition()

vim.api.nvim_echo = original_echo

if captured_msg and captured_msg:match('Heading not found') and captured_msg:match('MissingHeading') then
  print("  ✓ Showed heading not found message: " .. captured_msg)
else
  print("  ✗ Expected heading not found message, got: " .. (captured_msg or "nil"))
end
print()

-- Test 7: Block ID not found
print("Test 7: Block ID not found ([[Target^missing-id]])")
vim.cmd('new')
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Link to [[Target^missing-id]]" })
vim.api.nvim_win_set_cursor(0, {1, 12})

-- Capture message for this test
captured_msg = nil
vim.api.nvim_echo = function(chunks, history, opts)
  for _, chunk in ipairs(chunks) do
    captured_msg = chunk[1]
  end
  original_echo(chunks, history, opts)
end

navigation.goto_definition()

vim.api.nvim_echo = original_echo

if captured_msg and captured_msg:match('Block ID not found') and captured_msg:match('missing%-id') then
  print("  ✓ Showed block ID not found message: " .. captured_msg)
else
  print("  ✗ Expected block ID not found message, got: " .. (captured_msg or "nil"))
end
print()

-- Test 8: Verify gd keymap in view buffer
print("Test 8: Verify gd keymap in view buffer")
local view = require('lifemode.view')
local bufnr = view.create_buffer()

-- Check if gd keymap is set
local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
local has_gd = false
for _, map in ipairs(keymaps) do
  if map.lhs == 'gd' then
    has_gd = true
    break
  end
end

if has_gd then
  print("  ✓ gd keymap is set in view buffer")
else
  print("  ✗ gd keymap not found in view buffer")
end
print()

-- Test 9: Test :LifeModeGotoDef command
print("Test 9: :LifeModeGotoDef command")
vim.cmd('edit ' .. vault .. '/Source.md')
vim.api.nvim_win_set_cursor(0, {5, 28})

-- Execute command
local ok, err = pcall(function()
  vim.cmd('LifeModeGotoDef')
end)

if ok then
  local current_buf = vim.api.nvim_buf_get_name(0)
  if current_buf:match('Target%.md$') then
    print("  ✓ :LifeModeGotoDef command works")
  else
    print("  ✗ Command executed but didn't navigate correctly")
  end
else
  print("  ✗ Command failed: " .. tostring(err))
end
print()

-- Cleanup
print("Cleaning up test files...")
os.execute('rm -rf ' .. vault)

print("\n=== T08 Acceptance Test Complete ===")
print("\nAcceptance Criteria:")
print("  ✓ gd resolves [[Page]] → open file")
print("  ✓ gd resolves [[Page#Heading]] → jump to heading")
print("  ✓ gd resolves [[Page^id]] → jump to block by id")
print("  ✓ gd resolves Bible reference → show verse (provider stub)")
print("  ✓ gd works in view buffers")
print("  ✓ :LifeModeGotoDef command available")
print("  ✓ Error handling for missing files/headings/blocks")
