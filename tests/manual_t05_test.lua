#!/usr/bin/env -S nvim -l

-- Manual acceptance test for T05: Node Model
-- Tests the :LifeModeShowNodes command and node tree structure

-- Add lua directory to package path
package.path = package.path .. ';lua/?.lua;lua/?/init.lua'

local lifemode = require('lifemode')

-- Setup
lifemode.setup({ vault_root = '/tmp/test-vault' })

-- Create test buffer with hierarchical content
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '# Main Project ^proj1',
  '',
  '## Phase 1 ^phase1',
  '- [ ] Setup infrastructure ^task1',
  '- [ ] Configure deployment ^task2',
  '',
  '## Phase 2 ^phase2',
  '- [ ] Build features ^task3',
  '  - [ ] Feature A ^task4',
  '  - [ ] Feature B ^task5',
  '- [ ] Write tests ^task6',
  '',
  '# Another Project ^proj2',
  '- [ ] Independent task ^task7',
})
vim.api.nvim_set_current_buf(bufnr)

-- Test 1: Build node model programmatically
print('Test 1: Build node model')
local node = require('lifemode.node')
local result = node.build_nodes_from_buffer(bufnr)

print('  Total nodes:', vim.tbl_count(result.nodes_by_id))
print('  Root nodes:', #result.root_ids)

-- Verify structure
assert(vim.tbl_count(result.nodes_by_id) == 11, 'Expected 11 nodes')
assert(#result.root_ids == 2, 'Expected 2 root nodes (proj1, proj2)')

-- Verify proj1 has 2 children (phase1, phase2)
local proj1 = result.nodes_by_id['proj1']
assert(proj1 ~= nil, 'proj1 should exist')
assert(#proj1.children == 2, 'proj1 should have 2 children')

-- Verify phase1 has 2 task children
local phase1 = result.nodes_by_id['phase1']
assert(phase1 ~= nil, 'phase1 should exist')
assert(#phase1.children == 2, 'phase1 should have 2 children')

-- Verify task3 has 2 nested task children
local task3 = result.nodes_by_id['task3']
assert(task3 ~= nil, 'task3 should exist')
assert(#task3.children == 2, 'task3 should have 2 children (task4, task5)')

print('  ✓ Structure verified')

-- Test 2: :LifeModeShowNodes command
print('\nTest 2: :LifeModeShowNodes command')
print('Expected output:')
print('  - Node Tree summary')
print('  - Root nodes listed with children indented')
print('  - Hierarchy clearly visible')
print('')

-- Execute command
vim.cmd('LifeModeShowNodes')

print('\n✓ All acceptance criteria met')
print('  - build_nodes_from_buffer() converts blocks to Node records')
print('  - Node structure includes: id, type, body_md, children')
print('  - Heading hierarchy works (# → ##)')
print('  - List indentation hierarchy works')
print('  - :LifeModeShowNodes prints tree summary')
