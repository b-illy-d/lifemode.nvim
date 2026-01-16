local lifemode = require('lifemode')

print('=== VERIFYING SILENT FAILURES ===\n')

-- Test 1: Type validation for vault_root (non-string)
print('Test 1: vault_root accepts number')
local ok1 = pcall(function()
  lifemode._reset_state()
  lifemode.setup({ vault_root = 12345 })
end)
print('  Result: ' .. (ok1 and 'SILENT FAILURE - accepted' or 'GOOD - error thrown'))

-- Test 2: Whitespace-only vault_root
print('\nTest 2: vault_root accepts whitespace')
local ok2 = pcall(function()
  lifemode._reset_state()
  lifemode.setup({ vault_root = '   ' })
end)
print('  Result: ' .. (ok2 and 'SILENT FAILURE - accepted' or 'GOOD - error thrown'))

-- Test 3: Wrong type for max_depth
print('\nTest 3: max_depth accepts string')
local ok3 = pcall(function()
  lifemode._reset_state()
  lifemode.setup({ vault_root = '/tmp/test', max_depth = 'not a number' })
end)
print('  Result: ' .. (ok3 and 'SILENT FAILURE - accepted' or 'GOOD - error thrown'))

-- Test 4: Negative max_depth
print('\nTest 4: max_depth accepts negative value')
local ok4 = pcall(function()
  lifemode._reset_state()
  lifemode.setup({ vault_root = '/tmp/test', max_depth = -5 })
end)
print('  Result: ' .. (ok4 and 'SILENT FAILURE - accepted' or 'GOOD - error thrown'))

-- Test 5: Zero max_depth
print('\nTest 5: max_depth accepts zero')
local ok5 = pcall(function()
  lifemode._reset_state()
  lifemode.setup({ vault_root = '/tmp/test', max_depth = 0 })
end)
print('  Result: ' .. (ok5 and 'SILENT FAILURE - accepted' or 'GOOD - error thrown'))

print('\n=== VERIFICATION COMPLETE ===')
local failures = 0
if ok1 then failures = failures + 1 end
if ok2 then failures = failures + 1 end
if ok3 then failures = failures + 1 end
if ok4 then failures = failures + 1 end
if ok5 then failures = failures + 1 end

print(string.format('%d / 5 silent failures confirmed', failures))
if failures > 0 then
  os.exit(1)
else
  os.exit(0)
end
