local function reset_modules()
  package.loaded['lifemode'] = nil
  package.loaded['lifemode.init'] = nil
  package.loaded['lifemode.bible'] = nil
  package.loaded['lifemode.index'] = nil
  package.loaded['lifemode.parser'] = nil
  package.loaded['lifemode.vault'] = nil
end

reset_modules()

local function assert_truthy(value, label)
  if not value then
    print('FAIL: ' .. label)
    vim.cmd('cq 1')
  end
end

local function assert_equal(actual, expected, label)
  if actual ~= expected then
    print('FAIL: ' .. label)
    print('  expected: ' .. vim.inspect(expected))
    print('  got: ' .. vim.inspect(actual))
    vim.cmd('cq 1')
  end
end

local test_vault = vim.fn.tempname()
vim.fn.mkdir(test_vault, 'p')

vim.fn.writefile({
  '# Notes on John 17:20',
  '- [ ] Study John 17:20 deeply ^study-1',
}, test_vault .. '/notes.md')

vim.fn.writefile({
  '# Extended passage',
  '- Reading John 17:18-23 today',
}, test_vault .. '/passage.md')

vim.fn.writefile({
  '# Cross reference',
  '- John 17:20',
}, test_vault .. '/source.md')

local lifemode = require('lifemode')
local index = require('lifemode.index')

lifemode._reset_state()
index._reset_state()

lifemode.setup({
  vault_root = test_vault,
})

print('TEST: show_bible_backlinks populates quickfix')
vim.fn.setqflist({})
lifemode._show_bible_backlinks('bible:john:17:20')

local qflist = vim.fn.getqflist()
assert_truthy(#qflist >= 3, 'quickfix has backlinks')
print('PASS')

print('TEST: quickfix includes direct and range references')
local found_notes = false
local found_passage = false
local found_source = false
for _, item in ipairs(qflist) do
  local fname = vim.fn.bufname(item.bufnr)
  if fname:match('notes%.md') then found_notes = true end
  if fname:match('passage%.md') then found_passage = true end
  if fname:match('source%.md') then found_source = true end
end
assert_truthy(found_notes, 'notes.md found (direct ref)')
assert_truthy(found_passage, 'passage.md found (range ref)')
assert_truthy(found_source, 'source.md found (direct ref)')
print('PASS')

print('TEST: bible_backlinks_at_cursor works')
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  'Looking at John 17:20',
})
vim.api.nvim_win_set_buf(0, bufnr)
vim.api.nvim_win_set_cursor(0, {1, 15})

vim.fn.setqflist({})
lifemode._bible_backlinks_at_cursor()
qflist = vim.fn.getqflist()
assert_truthy(#qflist >= 3, 'found backlinks from cursor')
print('PASS')

vim.api.nvim_buf_delete(bufnr, {force = true})
vim.fn.delete(test_vault, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
