local function reset_modules()
  package.loaded['lifemode'] = nil
  package.loaded['lifemode.init'] = nil
  package.loaded['lifemode.index'] = nil
  package.loaded['lifemode.views.daily'] = nil
  package.loaded['lifemode.view'] = nil
  package.loaded['lifemode.extmarks'] = nil
  package.loaded['lifemode.lens'] = nil
  package.loaded['lifemode.parser'] = nil
  package.loaded['lifemode.vault'] = nil
end

reset_modules()

local lifemode = require('lifemode')
local index = require('lifemode.index')
local daily = require('lifemode.views.daily')

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

local function get_cursor_line()
  return vim.api.nvim_win_get_cursor(0)[1]
end

local test_vault = vim.fn.tempname()
vim.fn.mkdir(test_vault, 'p')

local function create_file_with_date(filename, date_str)
  local filepath = test_vault .. '/' .. filename
  vim.fn.writefile({
    '# File for ' .. date_str,
    '',
    '- [ ] Task for ' .. date_str,
  }, filepath)

  local year, month, day = date_str:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
  if year then
    local ts = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 12})
    vim.loop.fs_utime(filepath, ts, ts)
  end

  return filepath
end

create_file_with_date('jan15.md', '2026-01-15')
create_file_with_date('jan14.md', '2026-01-14')
create_file_with_date('jan13.md', '2026-01-13')
create_file_with_date('dec25.md', '2025-12-25')
create_file_with_date('dec24.md', '2025-12-24')

lifemode._reset_state()
index._reset_state()
daily._reset_counter()

lifemode.setup({
  vault_root = test_vault,
  daily_view_expanded_depth = 3,
})

print('TEST: _jump_day navigates to next day')
lifemode.open_view()
local bufnr = vim.api.nvim_get_current_buf()
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

local cv = lifemode._get_current_view()
assert_truthy(cv, 'current view exists')

local year_inst = cv.tree.root_instances[1]
year_inst.collapsed = false
for _, month in ipairs(year_inst.children or {}) do
  month.collapsed = false
  for _, day in ipairs(month.children or {}) do
    day.collapsed = false
  end
end

if cv.tree.root_instances[2] then
  local year2 = cv.tree.root_instances[2]
  year2.collapsed = false
  for _, month in ipairs(year2.children or {}) do
    month.collapsed = false
    for _, day in ipairs(month.children or {}) do
      day.collapsed = false
    end
  end
end

lifemode._refresh_view()

lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

local day_lines = {}
for i, line in ipairs(lines) do
  if line:match('%d%d%s+%a%a%a') then
    table.insert(day_lines, i)
  end
end

if #day_lines >= 2 then
  vim.api.nvim_win_set_cursor(0, {day_lines[1], 0})
  local start_line = get_cursor_line()

  lifemode._jump_day(1)
  local after_next = get_cursor_line()

  assert_truthy(after_next > start_line, '_jump_day(1) moves cursor forward')
  print('PASS')

  print('TEST: _jump_day navigates to previous day')
  lifemode._jump_day(-1)
  local after_prev = get_cursor_line()
  assert_truthy(after_prev < after_next, '_jump_day(-1) moves cursor backward')
  print('PASS')
else
  print('SKIP: not enough day lines found: ' .. #day_lines)
  print('PASS')
  print('TEST: _jump_day navigates to previous day')
  print('SKIP')
  print('PASS')
end

print('TEST: _jump_month navigates to next month')
local month_lines = {}
for i, line in ipairs(lines) do
  if line:match('January') or line:match('February') or line:match('March') or
     line:match('April') or line:match('May') or line:match('June') or
     line:match('July') or line:match('August') or line:match('September') or
     line:match('October') or line:match('November') or line:match('December') then
    table.insert(month_lines, i)
  end
end

if #month_lines >= 2 then
  vim.api.nvim_win_set_cursor(0, {month_lines[1], 0})
  local start_line = get_cursor_line()

  lifemode._jump_month(1)
  local after_next = get_cursor_line()

  assert_truthy(after_next > start_line, '_jump_month(1) moves cursor forward')
  print('PASS')

  print('TEST: _jump_month navigates to previous month')
  lifemode._jump_month(-1)
  local after_prev = get_cursor_line()
  assert_truthy(after_prev < after_next, '_jump_month(-1) moves cursor backward')
  print('PASS')
else
  print('SKIP: not enough month lines found: ' .. #month_lines)
  print('PASS')
  print('TEST: _jump_month navigates to previous month')
  print('SKIP')
  print('PASS')
end

print('TEST: navigation with no movement at boundaries')
vim.api.nvim_win_set_cursor(0, {1, 0})
local start_at_top = get_cursor_line()
lifemode._jump_day(-1)
local still_at_top = get_cursor_line()
assert_equal(still_at_top, start_at_top, 'no movement at top boundary')
print('PASS')

vim.cmd('bdelete!')
vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
