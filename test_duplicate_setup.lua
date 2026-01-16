local lifemode = require('lifemode')

print('=== DUPLICATE SETUP TEST ===\n')

print('Test 1: First setup() should succeed')
lifemode._reset_state()
local ok1, err1 = pcall(function()
  lifemode.setup({ vault_root = '/tmp/test1' })
end)

if ok1 then
  print('  PASS - First setup succeeded')
else
  print('  FAIL - First setup failed: ' .. tostring(err1))
  os.exit(1)
end

print('\nTest 2: Second setup() should fail')
local ok2, err2 = pcall(function()
  lifemode.setup({ vault_root = '/tmp/test2' })
end)

if not ok2 then
  print('  PASS - Second setup rejected: ' .. tostring(err2))
else
  print('  FAIL - Second setup was accepted (should have been rejected)')
  os.exit(1)
end

print('\nTest 3: After _reset_state(), setup() should work again')
lifemode._reset_state()
local ok3, err3 = pcall(function()
  lifemode.setup({ vault_root = '/tmp/test3' })
end)

if ok3 then
  print('  PASS - Setup after reset succeeded')
else
  print('  FAIL - Setup after reset failed: ' .. tostring(err3))
  os.exit(1)
end

print('\n=== ALL DUPLICATE SETUP TESTS PASSED ===')
os.exit(0)
