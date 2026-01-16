vim.opt.rtp:prepend('.')
local lifemode = require('lifemode')

print('=== SILENT FAILURE HUNT ===\n')

print('Test 1: vault_root with wrong type (number)')
local ok, err = pcall(function()
  lifemode._reset_state()
  lifemode.setup({ vault_root = 0 })
end)
print('  Result: ok=' .. tostring(ok))
if not ok then
  print('  Error: ' .. tostring(err))
else
  print('  Config vault_root: ' .. tostring(lifemode.get_config().vault_root))
  print('  Type: ' .. type(lifemode.get_config().vault_root))
end

print('\nTest 2: vault_root with whitespace only')
ok, err = pcall(function()
  lifemode._reset_state()
  lifemode.setup({ vault_root = '   ' })
end)
print('  Result: ok=' .. tostring(ok))
if ok then
  local vr = lifemode.get_config().vault_root
  print('  SILENT FAILURE: Accepted whitespace vault_root: [' .. vr .. ']')
else
  print('  Error: ' .. tostring(err))
end

print('\nTest 3: vault_root as table')
ok, err = pcall(function()
  lifemode._reset_state()
  lifemode.setup({ vault_root = { '/tmp/test' } })
end)
print('  Result: ok=' .. tostring(ok))
if ok then
  print('  SILENT FAILURE: Accepted table as vault_root')
  print('  Type: ' .. type(lifemode.get_config().vault_root))
else
  print('  Error: ' .. tostring(err))
end

print('\nTest 4: max_depth with wrong type (string)')
ok, err = pcall(function()
  lifemode._reset_state()
  lifemode.setup({ vault_root = '/tmp/test', max_depth = 'not a number' })
end)
print('  Result: ok=' .. tostring(ok))
if ok then
  local md = lifemode.get_config().max_depth
  print('  SILENT FAILURE: Accepted string max_depth: ' .. tostring(md))
  print('  Type: ' .. type(md))
else
  print('  Error: ' .. tostring(err))
end

print('\nTest 5: Calling setup() twice')
ok, err = pcall(function()
  lifemode._reset_state()
  lifemode.setup({ vault_root = '/tmp/test1' })
  lifemode.setup({ vault_root = '/tmp/test2' })
end)
print('  Result: ok=' .. tostring(ok))
if ok then
  print('  Final vault_root: ' .. lifemode.get_config().vault_root)
  print('  Commands registered twice? (check for duplicates)')
else
  print('  Error: ' .. tostring(err))
end

print('\nTest 6: hello() without setup')
lifemode._reset_state()
ok, err = pcall(function()
  lifemode.hello()
end)
print('  Result: ok=' .. tostring(ok))
if ok then
  print('  GOOD: Returns gracefully with error message')
else
  print('  FAIL: Crashes instead of graceful error')
end

print('\nTest 7: open_view() without setup')
ok, err = pcall(function()
  lifemode.open_view()
end)
print('  Result: ok=' .. tostring(ok))
if ok then
  print('  GOOD: Returns gracefully with error message')
else
  print('  FAIL: Crashes instead of graceful error')
end

print('\nTest 8: Buffer creation failure handling')
lifemode._reset_state()
lifemode.setup({ vault_root = '/tmp/test' })
ok, err = pcall(function()
  lifemode.open_view()
end)
print('  Result: ok=' .. tostring(ok))
if ok then
  print('  GOOD: Buffer created successfully')
else
  print('  Error during buffer creation: ' .. tostring(err))
end

print('\nTest 9: max_depth negative number')
ok, err = pcall(function()
  lifemode._reset_state()
  lifemode.setup({ vault_root = '/tmp/test', max_depth = -5 })
end)
print('  Result: ok=' .. tostring(ok))
if ok then
  print('  SILENT FAILURE: Accepted negative max_depth: ' .. lifemode.get_config().max_depth)
else
  print('  Error: ' .. tostring(err))
end

print('\nTest 10: max_depth zero')
ok, err = pcall(function()
  lifemode._reset_state()
  lifemode.setup({ vault_root = '/tmp/test', max_depth = 0 })
end)
print('  Result: ok=' .. tostring(ok))
if ok then
  print('  SILENT FAILURE: Accepted zero max_depth: ' .. lifemode.get_config().max_depth)
else
  print('  Error: ' .. tostring(err))
end

print('\n=== END SILENT FAILURE HUNT ===')
