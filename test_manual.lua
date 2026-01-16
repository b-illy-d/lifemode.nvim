vim.opt.rtp:prepend('.')

local lifemode = require('lifemode')

print('Test 1: Missing vault_root should error')
local ok, err = pcall(function()
  lifemode.setup({})
end)
if not ok and string.match(err, 'vault_root is required') then
  print('  PASS')
else
  print('  FAIL: ' .. tostring(err))
end

print('\nTest 2: Empty vault_root should error')
ok, err = pcall(function()
  lifemode._reset_state()
  lifemode.setup({ vault_root = '' })
end)
if not ok and string.match(err, 'vault_root is required') then
  print('  PASS')
else
  print('  FAIL: ' .. tostring(err))
end

print('\nTest 3: Valid config should work with defaults')
lifemode._reset_state()
lifemode.setup({ vault_root = '/tmp/test_vault' })
local config = lifemode.get_config()
assert(config.vault_root == '/tmp/test_vault', 'vault_root mismatch')
assert(config.leader == '<Space>', 'leader default mismatch')
assert(config.max_depth == 10, 'max_depth default mismatch')
assert(config.bible_version == 'ESV', 'bible_version default mismatch')
assert(config.default_view == 'daily', 'default_view default mismatch')
assert(config.max_nodes_per_action == 100, 'max_nodes_per_action default mismatch')
print('  PASS')

print('\nTest 4: Config overrides should work')
lifemode._reset_state()
lifemode.setup({
  vault_root = '/tmp/test_vault',
  leader = '<leader>m',
  max_depth = 5,
  bible_version = 'RSVCE',
})
config = lifemode.get_config()
assert(config.vault_root == '/tmp/test_vault', 'vault_root mismatch')
assert(config.leader == '<leader>m', 'leader override mismatch')
assert(config.max_depth == 5, 'max_depth override mismatch')
assert(config.bible_version == 'RSVCE', 'bible_version override mismatch')
print('  PASS')

print('\nTest 5: Commands should exist')
assert(vim.fn.exists(':LifeModeHello') == 2, 'LifeModeHello command not found')
assert(vim.fn.exists(':LifeMode') == 2, 'LifeMode command not found')
print('  PASS')

print('\nAll tests passed!')
