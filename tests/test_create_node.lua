local files = require('lifemode.core.files')
local patch = require('lifemode.patch')

local test_dir = '/tmp/lifemode_test_create_' .. os.time()
os.execute('mkdir -p ' .. test_dir)

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    print('PASS: ' .. name)
  else
    print('FAIL: ' .. name .. ' - ' .. tostring(err))
    os.exit(1)
  end
end

test('create_node appends to existing file', function()
  local file = test_dir .. '/tasks.md'
  files.write_lines(file, {'# Tasks', '- [ ] Existing task'})

  patch.create_node('- [ ] New task @due(2024-01-01)', file)

  local lines = files.read_lines(file)
  assert(#lines == 3, 'Expected 3 lines, got ' .. #lines)
  assert(lines[3] == '- [ ] New task @due(2024-01-01)', 'Expected new task on line 3')
end)

test('create_node creates file if not exists', function()
  local file = test_dir .. '/inbox.md'

  patch.create_node('- [ ] First task', file)

  local lines = files.read_lines(file)
  assert(lines, 'File should exist')
  assert(#lines == 1, 'Expected 1 line, got ' .. #lines)
  assert(lines[1] == '- [ ] First task', 'Expected task content')
end)

test('create_node handles notes', function()
  local file = test_dir .. '/notes.md'
  files.write_lines(file, {'# Notes'})

  patch.create_node('This is a plain note', file)

  local lines = files.read_lines(file)
  assert(#lines == 2, 'Expected 2 lines, got ' .. #lines)
  assert(lines[2] == 'This is a plain note', 'Expected note content')
end)

os.execute('rm -rf ' .. test_dir)
print('\nAll create_node tests passed!')
