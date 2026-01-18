local parser = require('lifemode.parser')
local vault = require('lifemode.vault')

print('=== Comprehensive Feature Test (New Node Model) ===\n')

vim.fn.delete('test_comprehensive_vault', 'rf')

print('1. Testing vault file discovery...')
vim.fn.mkdir('test_comprehensive_vault/tasks', 'p')
vim.fn.mkdir('test_comprehensive_vault/notes', 'p')

vim.fn.writefile({
  'type:: task',
  'id:: morning-task',
  'created:: 2026-01-18',
  '',
  '- [ ] Morning task !1 #daily',
}, 'test_comprehensive_vault/tasks/task-morning.md')

vim.fn.writefile({
  'type:: task',
  'id:: feature-task',
  'created:: 2026-01-18',
  '',
  '- [ ] Implement feature !2 @due(2026-01-20) #work #urgent',
}, 'test_comprehensive_vault/tasks/task-feature.md')

vim.fn.writefile({
  'type:: note',
  'id:: daily-note',
  'created:: 2026-01-18',
  '',
  '# Daily Notes',
  '',
  'Some content here.',
}, 'test_comprehensive_vault/notes/note-daily.md')

local files = vault.list_files('test_comprehensive_vault')
assert(#files == 3, 'Expected 3 files, got ' .. #files)
print('  PASS: Found ' .. #files .. ' markdown files')

print('\n2. Testing single-node file parsing...')
local node = parser.parse_file('test_comprehensive_vault/tasks/task-morning.md')

assert(node.type == 'task', 'Node type should be task, got: ' .. tostring(node.type))
assert(node.id == 'morning-task', 'Node ID should be morning-task, got: ' .. tostring(node.id))
assert(node.created == '2026-01-18', 'Created should be 2026-01-18')
assert(node.state == 'todo', 'Task state should be todo')
assert(node.priority == 1, 'Priority should be 1')
assert(node.tags and #node.tags == 1, 'Should have 1 tag')
assert(node.tags[1] == 'daily', 'Tag should be daily')
print('  PASS: Task node parsed correctly')

print('\n3. Testing task with full metadata...')
local feature_node = parser.parse_file('test_comprehensive_vault/tasks/task-feature.md')

assert(feature_node.type == 'task', 'Should be task')
assert(feature_node.id == 'feature-task', 'ID should be feature-task')
assert(feature_node.state == 'todo', 'Should be todo')
assert(feature_node.priority == 2, 'Priority should be 2')
assert(feature_node.due == '2026-01-20', 'Due should be 2026-01-20')
assert(feature_node.tags and #feature_node.tags == 2, 'Should have 2 tags')
assert(feature_node.tags[1] == 'work', 'First tag should be work')
assert(feature_node.tags[2] == 'urgent', 'Second tag should be urgent')
print('  PASS: Full task metadata extraction works')

print('\n4. Testing note node...')
local note_node = parser.parse_file('test_comprehensive_vault/notes/note-daily.md')

assert(note_node.type == 'note', 'Should be note')
assert(note_node.id == 'daily-note', 'ID should be daily-note')
assert(note_node.content:match('# Daily Notes'), 'Content should include heading')
print('  PASS: Note node parsed correctly')

vim.fn.delete('test_comprehensive_vault', 'rf')

print('\n=== All Comprehensive Tests PASSED ===')
vim.cmd('quit')
