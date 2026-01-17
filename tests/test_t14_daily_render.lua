local success, daily = pcall(require, 'lifemode.views.daily')
if not success then
  print('FAIL: Could not load lifemode.views.daily module')
  print('Error: ' .. tostring(daily))
  vim.cmd('cq 1')
end

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

local function assert_match(str, pattern, label)
  if not str:match(pattern) then
    print('FAIL: ' .. label)
    print('  pattern: ' .. pattern)
    print('  string: ' .. str)
    vim.cmd('cq 1')
  end
end

daily._reset_counter()

print('TEST: render produces lines for collapsed tree')
local idx = {
  nodes_by_date = {
    ['2026-01-15'] = {
      { node = { type = 'task', state = 'todo', text = 'Task A' }, file = '/vault/a.md' },
    },
  },
}
local tree = daily.build_tree(idx, { daily_view_expanded_depth = 0 })
local result = daily.render(tree)

assert_equal(#result.lines, 1, 'collapsed tree renders only year')
assert_match(result.lines[1], '2026', 'year line contains 2026')
assert_match(result.lines[1], '▸', 'collapsed year has ▸ icon')
print('PASS')

daily._reset_counter()

print('TEST: render expands tree based on collapsed state')
tree = daily.build_tree(idx, { daily_view_expanded_depth = 3 })
for _, inst in ipairs(tree.root_instances) do
  inst.collapsed = false
  for _, month in ipairs(inst.children) do
    month.collapsed = false
    for _, day in ipairs(month.children) do
      day.collapsed = false
    end
  end
end
result = daily.render(tree)

assert_truthy(#result.lines >= 4, 'expanded tree has multiple lines: ' .. #result.lines)
assert_match(result.lines[1], '2026', 'first line is year')
assert_match(result.lines[2], 'January', 'second line is month')
assert_match(result.lines[3], '15', 'third line is day')
assert_match(result.lines[4], 'Task A', 'fourth line is task')
print('PASS')

daily._reset_counter()

print('TEST: render applies indentation')
tree = daily.build_tree(idx, { daily_view_expanded_depth = 3 })
for _, inst in ipairs(tree.root_instances) do
  inst.collapsed = false
  for _, month in ipairs(inst.children) do
    month.collapsed = false
    for _, day in ipairs(month.children) do
      day.collapsed = false
    end
  end
end
result = daily.render(tree, { indent = '  ' })

assert_equal(result.lines[1]:match('^%s*'), '', 'year has no indent')
assert_equal(result.lines[2]:match('^(%s*)'), '  ', 'month has 2-space indent')
assert_equal(result.lines[3]:match('^(%s*)'), '    ', 'day has 4-space indent')
assert_equal(result.lines[4]:match('^(%s*)'), '      ', 'task has 6-space indent')
print('PASS')

daily._reset_counter()

print('TEST: render returns spans for each instance')
tree = daily.build_tree(idx, { daily_view_expanded_depth = 3 })
for _, inst in ipairs(tree.root_instances) do
  inst.collapsed = false
  for _, month in ipairs(inst.children) do
    month.collapsed = false
    for _, day in ipairs(month.children) do
      day.collapsed = false
    end
  end
end
result = daily.render(tree)

assert_equal(#result.spans, 4, 'should have 4 spans (year, month, day, task)')
assert_equal(result.spans[1].lens, 'date/year', 'first span is year')
assert_equal(result.spans[2].lens, 'date/month', 'second span is month')
assert_equal(result.spans[3].lens, 'date/day', 'third span is day')
assert_equal(result.spans[4].lens, 'task/brief', 'fourth span is task')
print('PASS')

daily._reset_counter()

print('TEST: span line_start and line_end are correct')
tree = daily.build_tree(idx, { daily_view_expanded_depth = 3 })
for _, inst in ipairs(tree.root_instances) do
  inst.collapsed = false
  for _, month in ipairs(inst.children) do
    month.collapsed = false
    for _, day in ipairs(month.children) do
      day.collapsed = false
    end
  end
end
result = daily.render(tree)

assert_equal(result.spans[1].line_start, 0, 'year starts at line 0')
assert_equal(result.spans[1].line_end, 0, 'year ends at line 0')
assert_equal(result.spans[2].line_start, 1, 'month starts at line 1')
assert_equal(result.spans[3].line_start, 2, 'day starts at line 2')
assert_equal(result.spans[4].line_start, 3, 'task starts at line 3')
print('PASS')

daily._reset_counter()

print('TEST: render returns highlights')
tree = daily.build_tree(idx, { daily_view_expanded_depth = 3 })
for _, inst in ipairs(tree.root_instances) do
  inst.collapsed = false
  for _, month in ipairs(inst.children) do
    month.collapsed = false
    for _, day in ipairs(month.children) do
      day.collapsed = false
    end
  end
end
result = daily.render(tree)

assert_truthy(#result.highlights > 0, 'should have highlights')
local year_hl = nil
for _, hl in ipairs(result.highlights) do
  if hl.hl_group == 'LifeModeDateYear' then
    year_hl = hl
    break
  end
end
assert_truthy(year_hl, 'should have year highlight')
assert_equal(year_hl.line, 0, 'year highlight on line 0')
print('PASS')

daily._reset_counter()

print('TEST: collapsed children are not rendered')
tree = daily.build_tree(idx, { daily_view_expanded_depth = 1 })
tree.root_instances[1].collapsed = false
tree.root_instances[1].children[1].collapsed = true
result = daily.render(tree)

assert_equal(#result.lines, 2, 'only year and month rendered when month collapsed')
assert_match(result.lines[1], '2026', 'year')
assert_match(result.lines[2], 'January', 'month')
assert_match(result.lines[2], '▸', 'month has collapsed icon')
print('PASS')

daily._reset_counter()

print('TEST: find_instance_by_id works')
tree = daily.build_tree(idx, { daily_view_expanded_depth = 3 })
local year_inst = tree.root_instances[1]
local found = daily.find_instance_by_id(tree, year_inst.instance_id)
assert_equal(found, year_inst, 'find_instance_by_id returns correct instance')

local day_inst = year_inst.children[1].children[1]
found = daily.find_instance_by_id(tree, day_inst.instance_id)
assert_equal(found, day_inst, 'find nested instance')
print('PASS')

daily._reset_counter()

print('TEST: find_today_line finds today')
local today = os.date('%Y-%m-%d')
local today_idx = {
  nodes_by_date = {
    [today] = {{ node = { type = 'task', text = 'Today' }, file = '/vault/a.md' }},
    ['2020-01-01'] = {{ node = { type = 'task', text = 'Old' }, file = '/vault/b.md' }},
  },
}
tree = daily.build_tree(today_idx, { daily_view_expanded_depth = 3 })
for _, inst in ipairs(tree.root_instances) do
  inst.collapsed = false
  for _, month in ipairs(inst.children) do
    month.collapsed = false
    for _, day in ipairs(month.children) do
      day.collapsed = false
    end
  end
end
result = daily.render(tree)
local today_line = daily.find_today_line(result.spans)
assert_truthy(today_line >= 0, 'find_today_line returns valid line')

local found_today_span = false
for _, span in ipairs(result.spans) do
  if span.date == today and span.line_start == today_line then
    found_today_span = true
    break
  end
end
assert_truthy(found_today_span, 'today line matches today span')
print('PASS')

daily._reset_counter()

print('TEST: empty tree produces empty output')
local empty_tree = { root_instances = {} }
result = daily.render(empty_tree)
assert_equal(#result.lines, 0, 'empty tree produces no lines')
assert_equal(#result.spans, 0, 'empty tree produces no spans')
print('PASS')

print('\nAll tests passed')
vim.cmd('quit')
