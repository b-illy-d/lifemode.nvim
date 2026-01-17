local parser = require('lifemode.parser')

local test_cases = {
  { text = 'text ^550e8400-e29b-41d4-a716-446655440000', expected = '550e8400-e29b-41d4-a716-446655440000', desc = 'UUID v4' },
  { text = 'text ^abc123', expected = 'abc123', desc = 'Alphanumeric' },
  { text = 'text ^task-1', expected = 'task-1', desc = 'Hyphen' },
  { text = 'text ^t:indexer', expected = 't:indexer', desc = 'Colon (from SPEC)' },
  { text = 'text ^s:smith2019', expected = 's:smith2019', desc = 'Colon namespace' },
  { text = 'text ^c:001', expected = 'c:001', desc = 'Colon with numbers' },
  { text = 'text ^id_underscore', expected = 'id_underscore', desc = 'Underscore' },
  { text = 'text ^block-id', expected = 'block-id', desc = 'Hyphenated' },
}

print('Testing ID pattern: ^(.-)%s*%^([%w%-_:]+)%s*$')
print('')

local fail_count = 0
for i, test in ipairs(test_cases) do
  local before, actual_id = test.text:match('^(.-)%s*%^([%w%-_:]+)%s*$')

  local status = (actual_id == test.expected) and 'PASS' or 'FAIL'
  if status == 'FAIL' then
    fail_count = fail_count + 1
  end

  print(string.format('[%s] %s: "%s"', status, test.desc, test.text))
  print(string.format('      Expected: %s', test.expected))
  print(string.format('      Got:      %s', actual_id or 'nil'))
  print('')
end

print(string.format('Results: %d/%d PASS, %d FAIL', #test_cases - fail_count, #test_cases, fail_count))

if fail_count > 0 then
  os.exit(1)
end
