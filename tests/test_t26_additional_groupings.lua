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

print('TEST: by_priority grouping creates priority groups')
vim.fn.writefile({
  '- [ ] Critical !1 ^task-1',
  '- [ ] High !2 ^task-2',
  '- [ ] Normal !3 ^task-3',
  '- [ ] Low !4 ^task-4',
  '- [ ] Lowest !5 ^task-5',
  '- [ ] No priority ^task-6',
}, test_file)

index._reset_state()
local idx = index.get_or_build(test_vault)

local tree = tasks.build_tree(idx, { grouping = 'by_priority' })

assert_truthy(tree, 'tree exists')
assert_truthy(tree.root_instances, 'root_instances exists')

local group_names = {}
for _, inst in ipairs(tree.root_instances) do
  if inst.display then
    table.insert(group_names, inst.display)
  end
end

assert_truthy(vim.tbl_contains(group_names, 'Priority 1'), 'has Priority 1 group')
assert_truthy(vim.tbl_contains(group_names, 'Priority 2'), 'has Priority 2 group')
assert_truthy(vim.tbl_contains(group_names, 'No Priority'), 'has No Priority group')
print('PASS')

print('TEST: by_tag grouping creates tag groups')
vim.fn.writefile({
  '- [ ] Work task #work ^task-w1',
  '- [ ] Another work #work ^task-w2',
  '- [ ] Home task #home ^task-h1',
  '- [ ] Untagged task ^task-u1',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

tree = tasks.build_tree(idx, { grouping = 'by_tag' })

group_names = {}
for _, inst in ipairs(tree.root_instances) do
  if inst.display then
    table.insert(group_names, inst.display)
  end
end

assert_truthy(vim.tbl_contains(group_names, '#work'), 'has #work group')
assert_truthy(vim.tbl_contains(group_names, '#home'), 'has #home group')
assert_truthy(vim.tbl_contains(group_names, 'Untagged'), 'has Untagged group')
print('PASS')

print('TEST: tasks sorted by priority within groups')
vim.fn.writefile({
  '- [ ] Low first !4 ^task-low',
  '- [ ] High first !1 ^task-high',
  '- [ ] Mid first !2 ^task-mid',
}, test_file)

index._reset_state()
idx = index.get_or_build(test_vault)

tree = tasks.build_tree(idx, { grouping = 'by_due_date' })

local no_due_group = nil
for _, inst in ipairs(tree.root_instances) do
  if inst.display == 'No Due Date' then
    no_due_group = inst
    break
  end
end

if no_due_group and no_due_group.children and #no_due_group.children >= 3 then
  local first = no_due_group.children[1]
  local last = no_due_group.children[#no_due_group.children]
  assert_truthy(first.node.priority <= last.node.priority or not last.node.priority, 'sorted by priority')
end
print('PASS')

vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
