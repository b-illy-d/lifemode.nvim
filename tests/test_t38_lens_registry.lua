local function reset_modules()
  package.loaded['lifemode.lens'] = nil
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

local lens = require('lifemode.lens')

print('TEST: get_available_lenses returns lenses for task')
local lenses = lens.get_available_lenses('task')
assert_truthy(#lenses >= 2, 'at least 2 lenses for task')
assert_truthy(vim.tbl_contains(lenses, 'task/brief'), 'has task/brief')
assert_truthy(vim.tbl_contains(lenses, 'node/raw'), 'has node/raw')
print('PASS')

print('TEST: get_available_lenses returns lenses for heading')
lenses = lens.get_available_lenses('heading')
assert_truthy(#lenses >= 2, 'at least 2 lenses for heading')
assert_truthy(vim.tbl_contains(lenses, 'heading/brief'), 'has heading/brief')
print('PASS')

print('TEST: cycle returns next lens')
local next_lens = lens.cycle('task/brief', 'task')
assert_truthy(next_lens, 'next lens returned')
assert_truthy(next_lens ~= 'task/brief', 'different from current')
print('PASS')

print('TEST: cycle wraps around')
local current = 'task/brief'
local seen = {current}
for i = 1, 10 do
  current = lens.cycle(current, 'task')
  if vim.tbl_contains(seen, current) then
    break
  end
  table.insert(seen, current)
end
assert_truthy(vim.tbl_contains(seen, 'task/brief'), 'cycles back to start')
print('PASS')

print('TEST: cycle backwards')
next_lens = lens.cycle('task/brief', 'task', -1)
assert_truthy(next_lens, 'prev lens returned')
print('PASS')

print('TEST: cycle with unknown lens returns first')
next_lens = lens.cycle('unknown/lens', 'task')
assert_equal(next_lens, 'task/brief', 'returns first lens')
print('PASS')

print('\nAll tests passed')
vim.cmd('quit')
