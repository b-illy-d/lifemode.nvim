local success, daily = pcall(require, 'lifemode.views.daily')
if not success then
  print('FAIL: Could not load lifemode.views.daily module')
  print('Error: ' .. tostring(daily))
  vim.cmd('cq 1')
end

local function assert_equal(actual, expected, label)
  if actual ~= expected then
    print('FAIL: ' .. label)
    print('  expected: ' .. tostring(expected))
    print('  got: ' .. tostring(actual))
    vim.cmd('cq 1')
  end
end

local function assert_truthy(value, label)
  if not value then
    print('FAIL: ' .. label)
    vim.cmd('cq 1')
  end
end

daily._reset_counter()

print('TEST: build_tree creates year/month/day hierarchy')
local idx = {
  nodes_by_date = {
    ['2026-01-15'] = {
      { id = 'task1', file = '/vault/a.md' },
      { id = 'task2', file = '/vault/a.md' },
    },
    ['2026-01-14'] = {
      { id = 'task3', file = '/vault/b.md' },
    },
    ['2025-12-25'] = {
      { id = 'task4', file = '/vault/c.md' },
    },
  },
}
local tree = daily.build_tree(idx)
assert_equal(#tree.root_instances, 2, 'should have 2 years')
assert_equal(tree.root_instances[1].date, '2026', 'first year is 2026 (descending)')
assert_equal(tree.root_instances[2].date, '2025', 'second year is 2025')
assert_equal(tree.root_instances[1].lens, 'date/year', 'year lens')
assert_equal(tree.root_instances[1].depth, 0, 'year depth is 0')
print('PASS')

print('TEST: months are nested under years')
local year_2026 = tree.root_instances[1]
assert_equal(#year_2026.children, 1, '2026 should have 1 month')
local jan_2026 = year_2026.children[1]
assert_equal(jan_2026.date, '2026-01', 'month is 2026-01')
assert_equal(jan_2026.lens, 'date/month', 'month lens')
assert_equal(jan_2026.depth, 1, 'month depth is 1')
assert_equal(jan_2026.display, 'January', 'month display name')
print('PASS')

print('TEST: days are nested under months')
assert_equal(#jan_2026.children, 2, 'January has 2 days')
local jan_15 = jan_2026.children[1]
local jan_14 = jan_2026.children[2]
assert_equal(jan_15.date, '2026-01-15', 'first day is 15th (descending)')
assert_equal(jan_14.date, '2026-01-14', 'second day is 14th')
assert_equal(jan_15.lens, 'date/day', 'day lens')
assert_equal(jan_15.depth, 2, 'day depth is 2')
print('PASS')

print('TEST: leaf nodes are nested under days')
assert_equal(#jan_15.children, 2, 'Jan 15 has 2 tasks')
local leaf1 = jan_15.children[1]
assert_equal(leaf1.target_id, 'task1', 'first leaf target_id')
assert_equal(leaf1.depth, 3, 'leaf depth is 3')
assert_equal(leaf1.lens, 'task/brief', 'leaf lens')
print('PASS')

print('TEST: instance_id is unique for each node')
local ids = {}
local function collect_ids(instances)
  for _, inst in ipairs(instances) do
    assert_truthy(inst.instance_id, 'instance should have instance_id')
    assert_truthy(not ids[inst.instance_id], 'instance_id should be unique: ' .. inst.instance_id)
    ids[inst.instance_id] = true
    if inst.children then
      collect_ids(inst.children)
    end
  end
end
collect_ids(tree.root_instances)
print('PASS')

daily._reset_counter()

print('TEST: today is expanded by default')
local today = os.date('%Y-%m-%d')
local today_year = today:sub(1, 4)
local today_month = today:sub(1, 7)

local today_idx = {
  nodes_by_date = {
    [today] = {{ id = 'today_task', file = '/vault/today.md' }},
    ['2020-01-01'] = {{ id = 'old_task', file = '/vault/old.md' }},
  },
}
local today_tree = daily.build_tree(today_idx, { daily_view_expanded_depth = 3 })

local today_year_inst = nil
local old_year_inst = nil
for _, y in ipairs(today_tree.root_instances) do
  if y.date == today_year then today_year_inst = y end
  if y.date == '2020' then old_year_inst = y end
end

assert_truthy(today_year_inst, 'today year exists')
assert_equal(today_year_inst.collapsed, false, 'today year is expanded')
assert_truthy(old_year_inst, 'old year exists')
assert_equal(old_year_inst.collapsed, true, 'old year is collapsed')
print('PASS')

print('TEST: nodes without ID use node field')
daily._reset_counter()
local node_without_id = { type = 'task', text = 'Inline task' }
local idx_with_inline = {
  nodes_by_date = {
    ['2026-01-10'] = {{ node = node_without_id, file = '/vault/inline.md' }},
  },
}
local inline_tree = daily.build_tree(idx_with_inline)
local leaf = inline_tree.root_instances[1].children[1].children[1].children[1]
assert_equal(leaf.target_id, nil, 'leaf without ID has no target_id')
assert_equal(leaf.node, node_without_id, 'leaf has node reference')
print('PASS')

print('TEST: empty index produces empty tree')
daily._reset_counter()
local empty_idx = { nodes_by_date = {} }
local empty_tree = daily.build_tree(empty_idx)
assert_equal(#empty_tree.root_instances, 0, 'empty tree has no root instances')
print('PASS')

print('TEST: day display includes weekday')
daily._reset_counter()
local wed_idx = {
  nodes_by_date = {
    ['2026-01-14'] = {{ id = 'task', file = '/vault/a.md' }},
  },
}
local wed_tree = daily.build_tree(wed_idx)
local day_inst = wed_tree.root_instances[1].children[1].children[1]
assert_truthy(day_inst.display:match('Wed'), 'day display includes Wed: ' .. day_inst.display)
print('PASS')

print('\nAll tests passed')
vim.cmd('quit')
