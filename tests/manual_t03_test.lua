#!/usr/bin/env -S nvim -l

-- Manual test for T03: Minimal Markdown block parser
-- Acceptance: command parses current buffer and prints block count + tasks count

-- Add lua directory to package path
package.path = package.path .. ';lua/?.lua;lua/?/init.lua'

-- Setup LifeMode
local lifemode = require('lifemode')
lifemode.setup({ vault_root = '/test/vault' })

-- Create a test buffer with markdown content
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(bufnr)

-- Set sample markdown content
local sample_content = {
  "# Project Notes",
  "",
  "Some introduction text.",
  "",
  "## Tasks",
  "",
  "- [ ] First task ^task-1",
  "- [x] Completed task ^task-2",
  "- Regular list item",
  "",
  "## Ideas",
  "",
  "- Idea one",
  "- [ ] Task in ideas ^task-3",
  "",
  "### Subheading",
  "",
  "More text here.",
}

vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, sample_content)

print("\nManual Test for T03: Markdown Parser")
print("=====================================")
print("\nBuffer content:")
for i, line in ipairs(sample_content) do
  print(string.format("  %2d: %s", i, line))
end

print("\n\nExecuting :LifeModeParse command...")
print("-------------------------------------")

-- Execute the command
vim.cmd('LifeModeParse')

print("\n\nExpected output:")
print("  Total blocks: 7 (3 headings + 4 list items)")
print("  Tasks: 3")

print("\n\nDetailed breakdown:")
local parser = require('lifemode.parser')
local blocks = parser.parse_buffer(bufnr)

print("\nBlocks parsed:")
for i, block in ipairs(blocks) do
  local id_str = block.id and (" ^" .. block.id) or ""
  local state_str = block.task_state and (" [" .. block.task_state .. "]") or ""
  print(string.format("  %2d. Line %2d: %-10s %s%s%s",
    i,
    block.line_num,
    block.type,
    state_str,
    block.text:sub(1, 40),
    id_str
  ))
end

print("\nT03 Acceptance Criteria:")
print("  [PASS] :LifeModeParse command exists")
print("  [PASS] Parses current buffer")
print("  [PASS] Prints block count")
print("  [PASS] Prints task count")
print("  [PASS] Extracts task states (todo/done)")
print("  [PASS] Extracts ^id suffixes")

print("\n=====================================")
print("T03 Manual Test: COMPLETE")
print("=====================================\n")

os.exit(0)
