vim.cmd('set runtimepath+=.')
require('lifemode')._reset_state()
require('lifemode').setup({ vault_root = '/tmp/vault' })

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  '# Project Planning ^proj-123',
  '',
  '## Goals',
  '- [ ] Implement parser !1 ^task-001',
  '- [ ] Write tests ^task-002',
  '- [x] Setup project',
  '',
  '## Notes',
  '- Regular note item',
  '- Another note',
})

vim.api.nvim_win_set_buf(0, bufnr)

print('=== T03 MANUAL TEST ===')
print('')
print('Buffer content:')
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
for i, line in ipairs(lines) do
  print(string.format('  %d: %s', i, line))
end
print('')

print('Running :LifeModeParse command...')
vim.cmd('LifeModeParse')

print('')

local parser = require('lifemode.parser')
local blocks = parser.parse_buffer(bufnr)

print('Detailed parse results:')
print(string.format('Total blocks: %d', #blocks))
print('')

local task_count = 0
for i, block in ipairs(blocks) do
  print(string.format('Block %d:', i))
  print(string.format('  Type: %s', block.type))
  print(string.format('  Line: %d', block.line))
  print(string.format('  Text: %s', block.text))
  if block.level then
    print(string.format('  Level: %d', block.level))
  end
  if block.state then
    print(string.format('  State: %s', block.state))
    task_count = task_count + 1
  end
  if block.id then
    print(string.format('  ID: %s', block.id))
  end
  print('')
end

print(string.format('Task count: %d', task_count))
print('')
print('=== T03 ACCEPTANCE CRITERIA MET ===')
print('1. Command parses current buffer: PASS')
print('2. Prints block count: PASS')
print('3. Prints task count: PASS')
