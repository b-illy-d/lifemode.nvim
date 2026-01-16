local test_cases = {
  { text = 'text ^id_with_underscore', expected_id = 'id_with_underscore' },
  { text = 'text ^id-with-hyphen', expected_id = 'id-with-hyphen' },
  { text = 'text ^id123numeric', expected_id = 'id123numeric' },
}

for i, test in ipairs(test_cases) do
  local before_id, id = test.text:match('^(.-)%s*%^([%w%-]+)%s*$')

  print(string.format('Test %d: "%s"', i, test.text))
  print(string.format('  Expected ID: %s', test.expected_id))
  print(string.format('  Actual ID: %s', id or 'nil'))
  print(string.format('  Match: %s', (id == test.expected_id) and 'PASS' or 'FAIL'))
  print('')
end

print('Testing %w character class:')
local test_id = 'id_test'
local match = test_id:match('^([%w]+)$')
print(string.format('Does %w match "id_test"? %s', match or 'NO'))

local test_id2 = 'idtest'
local match2 = test_id2:match('^([%w]+)$')
print(string.format('Does %w match "idtest"? %s', match2 or 'NO'))
