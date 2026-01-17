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
  if not str or not str:match(pattern) then
    print('FAIL: ' .. label)
    print('  pattern: ' .. pattern)
    print('  string: ' .. vim.inspect(str))
    vim.cmd('cq 1')
  end
end

local test_vault = vim.fn.tempname()
vim.fn.mkdir(test_vault, 'p')

local test_file = test_vault .. '/test.md'
vim.fn.writefile({
  '# Test file',
  '',
  '- [ ] Task one',
  '- [x] Task two',
  '- [ ] Task three',
}, test_file)

local stat = vim.loop.fs_stat(test_file)
local mtime = stat.mtime.sec

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
  daily_view_expanded_depth = 3,
})

print('TEST: :LifeMode creates buffer with daily view')
lifemode.open_view()
local bufnr = vim.api.nvim_get_current_buf()
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

assert_truthy(#lines > 0, 'buffer has lines')

local found_year = false
for _, line in ipairs(lines) do
  if line:match('%d%d%d%d') then
    found_year = true
    break
  end
end
assert_truthy(found_year, 'buffer contains a year')
print('PASS')

print('TEST: buffer is read-only')
assert_equal(vim.bo[bufnr].modifiable, false, 'buffer is not modifiable')
assert_equal(vim.bo[bufnr].readonly, true, 'buffer is readonly')
print('PASS')

print('TEST: buffer has lifemode filetype')
assert_equal(vim.bo[bufnr].filetype, 'lifemode', 'buffer filetype')
print('PASS')

print('TEST: current view state is stored')
local cv = lifemode._get_current_view()
assert_truthy(cv, 'current view exists')
assert_equal(cv.bufnr, bufnr, 'bufnr matches')
assert_truthy(cv.tree, 'tree exists')
assert_truthy(cv.index, 'index exists')
assert_truthy(cv.spans, 'spans exist')
print('PASS')

print('TEST: keymaps are set up')
local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
local found_expand = false
local found_collapse = false
local found_next_day = false
local found_prev_day = false
local found_next_month = false
local found_prev_month = false
local found_quit = false

for _, km in ipairs(keymaps) do
  if km.lhs == ' e' then found_expand = true end
  if km.lhs == ' E' then found_collapse = true end
  if km.lhs == ']d' then found_next_day = true end
  if km.lhs == '[d' then found_prev_day = true end
  if km.lhs == ']m' then found_next_month = true end
  if km.lhs == '[m' then found_prev_month = true end
  if km.lhs == 'q' then found_quit = true end
end

assert_truthy(found_expand, 'expand keymap exists')
assert_truthy(found_collapse, 'collapse keymap exists')
assert_truthy(found_next_day, 'next day keymap exists')
assert_truthy(found_prev_day, 'prev day keymap exists')
assert_truthy(found_next_month, 'next month keymap exists')
assert_truthy(found_prev_month, 'prev month keymap exists')
assert_truthy(found_quit, 'quit keymap exists')
print('PASS')

print('TEST: spans are set up with extmarks')
local extmarks = require('lifemode.extmarks')
local ns = extmarks.create_namespace()
local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {details = true})
assert_truthy(#marks > 0, 'extmarks exist')
print('PASS')

vim.cmd('bdelete!')

vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
