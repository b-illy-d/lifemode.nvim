local parser = require('lifemode.parser')
local vault = require('lifemode.vault')

print('=== Comprehensive Feature Test ===\n')

print('1. Testing vault file discovery...')
vim.fn.mkdir('test_comprehensive_vault/notes', 'p')
vim.fn.writefile({'# Daily Notes', '- [ ] Morning task !1', '- [x] Evening review @due(2026-01-16) #personal'}, 'test_comprehensive_vault/daily.md')
vim.fn.writefile({'# Project', '- [ ] Implement feature !2 @due(2026-01-20) #work #urgent ^abc123'}, 'test_comprehensive_vault/notes/project.md')

local files = vault.list_files('test_comprehensive_vault')
assert(#files == 2, 'Expected 2 files, got ' .. #files)
print('  PASS: Found ' .. #files .. ' markdown files')

print('\n2. Testing task metadata parsing...')
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '# Tasks',
  '- [ ] Simple task',
  '- [ ] Priority task !3',
  '- [ ] Due task @due(2026-02-01)',
  '- [ ] Tagged task #work',
  '- [x] Complete task !1 @due(2026-01-16) #urgent #work ^task-id',
})

local blocks = parser.parse_buffer(bufnr)
vim.api.nvim_buf_delete(bufnr, {force = true})

assert(#blocks == 6, 'Expected 6 blocks')
print('  PASS: Parsed ' .. #blocks .. ' blocks')

local heading = blocks[1]
assert(heading.type == 'heading', 'Block 1 should be heading')
assert(heading.level == 1, 'Heading level should be 1')
assert(heading.text == 'Tasks', 'Heading text should be Tasks')
print('  PASS: Heading parsed correctly')

local simple_task = blocks[2]
assert(simple_task.type == 'task', 'Block 2 should be task')
assert(simple_task.state == 'todo', 'Task should be todo')
assert(simple_task.text == 'Simple task', 'Task text should be "Simple task"')
assert(simple_task.priority == nil, 'No priority')
assert(simple_task.due == nil, 'No due date')
assert(simple_task.tags == nil, 'No tags')
print('  PASS: Simple task parsed correctly')

local priority_task = blocks[3]
assert(priority_task.priority == 3, 'Priority should be 3')
assert(priority_task.text == 'Priority task', 'Text should not contain !3')
print('  PASS: Priority extraction works')

local due_task = blocks[4]
assert(due_task.due == '2026-02-01', 'Due date should be 2026-02-01')
assert(due_task.text == 'Due task', 'Text should not contain @due')
print('  PASS: Due date extraction works')

local tagged_task = blocks[5]
assert(tagged_task.tags and #tagged_task.tags == 1, 'Should have 1 tag')
assert(tagged_task.tags[1] == 'work', 'Tag should be work')
assert(tagged_task.text == 'Tagged task', 'Text should not contain #work')
print('  PASS: Tag extraction works')

local complete_task = blocks[6]
assert(complete_task.state == 'done', 'Task should be done')
assert(complete_task.priority == 1, 'Priority should be 1')
assert(complete_task.due == '2026-01-16', 'Due should be 2026-01-16')
assert(complete_task.tags and #complete_task.tags == 2, 'Should have 2 tags')
assert(complete_task.tags[1] == 'urgent', 'First tag should be urgent')
assert(complete_task.tags[2] == 'work', 'Second tag should be work')
assert(complete_task.id == 'task-id', 'ID should be task-id')
assert(complete_task.text == 'Complete task', 'Text should not contain metadata')
print('  PASS: Complete metadata extraction works')

print('\n3. Testing SPEC.md example...')
local bufnr2 = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr2, 0, -1, false, {
  '- [ ] Implement indexer !2 @due(2026-02-01) #lifemode ^t:indexer',
})

local spec_blocks = parser.parse_buffer(bufnr2)
vim.api.nvim_buf_delete(bufnr2, {force = true})

local spec_task = spec_blocks[1]
assert(spec_task.type == 'task', 'Should be task')
assert(spec_task.state == 'todo', 'Should be todo')
assert(spec_task.priority == 2, 'Priority should be 2')
assert(spec_task.due == '2026-02-01', 'Due should be 2026-02-01')
assert(spec_task.tags and #spec_task.tags == 1, 'Should have 1 tag')
assert(spec_task.tags[1] == 'lifemode', 'Tag should be lifemode')
assert(spec_task.id == 't:indexer', 'ID should be t:indexer (colon allowed in ID)')
assert(spec_task.text == 'Implement indexer', 'Text should not contain metadata')
print('  PASS: SPEC.md example parses correctly')

vim.fn.delete('test_comprehensive_vault', 'rf')

print('\n=== All Comprehensive Tests PASSED ===')
vim.cmd('quit')
