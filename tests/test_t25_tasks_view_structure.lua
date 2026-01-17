local function reset_modules()
  package.loaded['lifemode'] = nil
  package.loaded['lifemode.init'] = nil
  package.loaded['lifemode.index'] = nil
  package.loaded['lifemode.parser'] = nil
  package.loaded['lifemode.vault'] = nil
  package.loaded['lifemode.views.tasks'] = nil
end

reset_modules()

local function assert_equal(actual, expected, label)
  if actual ~= expected then
    print('FAIL: ' .. label)
    print('  expected: ' .. vim.inspect(expected))
    print('  got: ' .. vim.inspect(actual))
    vim.cmd('cq 1')
  end
end

local function assert_truthy(value, label)
  if not value then
    print('FAIL: ' .. label)
    vim.cmd('cq 1')
  end
end

local test_vault = vim.fn.tempname()
vim.fn.mkdir(test_vault, 'p')

local test_file = test_vault .. '/tasks.md'

local lifemode = require('lifemode')
local index = require('lifemode.index')
local tasks = require('lifemode.views.tasks')

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
})

local today = os.date('%Y-%m-%d')
local tomorrow = os.date('%Y-%m-%d', os.time() + 86400)
local yesterday = os.date('%Y-%m-%d', os.time() - 86400)
local next_week = os.date('%Y-%m-%d', os.time() + 86400 * 8)

print('TEST: build_tree with by_due_date grouping creates groups')
vim.fn.writefile({
  '- [ ] Overdue task @due(' .. yesterday .. ') ^task-1',
  '- [ ] Today task @due(' .. today .. ') ^task-2',
  '- [ ] Tomorrow task @due(' .. tomorrow .. ') ^task-3',
  '- [ ] Next week task @due(' .. next_week .. ') ^task-4',
  '- [ ] No due task ^task-5',
}, test_file)

index._reset_state()
local idx = index.get_or_build(test_vault)

local tree = tasks.build_tree(idx, { grouping = 'by_due_date' })

assert_truthy(tree, 'tree exists')
assert_truthy(tree.root_instances, 'root_instances exists')
assert_truthy(#tree.root_instances > 0, 'has groups')

local group_names = {}
for _, inst in ipairs(tree.root_instances) do
  if inst.display then
    table.insert(group_names, inst.display)
  end
end

assert_truthy(vim.tbl_contains(group_names, 'Overdue'), 'has Overdue group')
assert_truthy(vim.tbl_contains(group_names, 'Today'), 'has Today group')
assert_truthy(vim.tbl_contains(group_names, 'This Week'), 'has This Week group')
assert_truthy(vim.tbl_contains(group_names, 'Later'), 'has Later group')
assert_truthy(vim.tbl_contains(group_names, 'No Due Date'), 'has No Due Date group')
print('PASS')

print('TEST: tasks are assigned to correct groups')
local overdue_group = nil
local today_group = nil
local no_due_group = nil

for _, inst in ipairs(tree.root_instances) do
  if inst.display == 'Overdue' then overdue_group = inst end
  if inst.display == 'Today' then today_group = inst end
  if inst.display == 'No Due Date' then no_due_group = inst end
end

if overdue_group and overdue_group.children then
  local found = false
  for _, child in ipairs(overdue_group.children) do
    if child.node and child.node.text and child.node.text:match('Overdue task') then
      found = true
    end
  end
  assert_truthy(found, 'Overdue task in Overdue group')
end

if today_group and today_group.children then
  local found = false
  for _, child in ipairs(today_group.children) do
    if child.node and child.node.text and child.node.text:match('Today task') then
      found = true
    end
  end
  assert_truthy(found, 'Today task in Today group')
end

if no_due_group and no_due_group.children then
  local found = false
  for _, child in ipairs(no_due_group.children) do
    if child.node and child.node.text and child.node.text:match('No due task') then
      found = true
    end
  end
  assert_truthy(found, 'No due task in No Due Date group')
end
print('PASS')

print('TEST: empty groups are not included')
vim.fn.writefile({
  '- [ ] Only today task @due(' .. today .. ') ^task-only',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

tree = tasks.build_tree(idx, { grouping = 'by_due_date' })

local has_overdue = false
for _, inst in ipairs(tree.root_instances) do
  if inst.display == 'Overdue' then has_overdue = true end
end
assert_truthy(not has_overdue, 'Overdue group not included when empty')
print('PASS')

print('TEST: only todo tasks included by default')
vim.fn.writefile({
  '- [ ] Todo task ^task-todo',
  '- [x] Done task ^task-done',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

tree = tasks.build_tree(idx, { grouping = 'by_due_date' })

local task_count = 0
for _, group in ipairs(tree.root_instances) do
  if group.children then
    task_count = task_count + #group.children
  end
end
assert_equal(task_count, 1, 'only todo task included')
print('PASS')

vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
