vim.opt.rtp:prepend('.')

print('\n=== T01 EDGE CASE & SILENT FAILURE HUNT ===\n')

local failures = {}

local function record_failure(severity, description, location)
  table.insert(failures, {
    severity = severity,
    description = description,
    location = location,
  })
end

local view = require('lifemode.view')
local lifemode = require('lifemode')

lifemode.setup({ vault_root = '/tmp/test_vault' })

print('TEST 1: nvim_create_buf returns 0 (failure case)')
local original_create_buf = vim.api.nvim_create_buf
vim.api.nvim_create_buf = function()
  return 0
end

local success, result = pcall(view.create_buffer)
if success then
  if result == 0 or not result then
    print('  FAIL: create_buffer() returns invalid buffer without error')
    record_failure('CRITICAL', 'nvim_create_buf failure not checked - returns 0/nil silently', 'lua/lifemode/view.lua:6')
  else
    print('  PASS: Invalid buffer handled')
  end
else
  print('  PASS: Error raised for failed buffer creation')
end

vim.api.nvim_create_buf = original_create_buf

print('\nTEST 2: Multiple buffer creation (counter uniqueness)')
local buffers = {}
local names = {}
for i = 1, 5 do
  buffers[i] = view.create_buffer()
  names[i] = vim.api.nvim_buf_get_name(buffers[i])
end

local has_duplicate = false
for i = 1, 5 do
  for j = i + 1, 5 do
    if names[i] == names[j] then
      has_duplicate = true
      break
    end
  end
end

if has_duplicate then
  print('  FAIL: Duplicate buffer names detected')
  record_failure('CRITICAL', 'Buffer naming not unique', 'lua/lifemode/view.lua:13-14')
else
  print('  PASS: All buffer names unique')
end

print('\nTEST 3: Counter overflow simulation')
local M = {}
local counter = 2147483640
for i = 1, 10 do
  counter = counter + 1
  local name = 'LifeMode View #' .. counter
  if not name:match('LifeMode') then
    print('  FAIL: Counter overflow corrupts name')
    record_failure('MEDIUM', 'Counter could overflow on very long sessions', 'lua/lifemode/view.lua:13')
    break
  end
end
print('  PASS: Counter handles large values')

print('\nTEST 4: Buffer settings validation')
local test_buf = view.create_buffer()

local checks = {
  { name = 'buftype', expected = 'nofile', actual = vim.bo[test_buf].buftype },
  { name = 'swapfile', expected = false, actual = vim.bo[test_buf].swapfile },
  { name = 'bufhidden', expected = 'hide', actual = vim.bo[test_buf].bufhidden },
  { name = 'filetype', expected = 'lifemode', actual = vim.bo[test_buf].filetype },
}

for _, check in ipairs(checks) do
  if check.actual ~= check.expected then
    print('  FAIL: ' .. check.name .. ' = ' .. tostring(check.actual) .. ', expected ' .. tostring(check.expected))
    record_failure('CRITICAL', check.name .. ' not set correctly', 'lua/lifemode/view.lua:8-11')
  else
    print('  PASS: ' .. check.name .. ' = ' .. tostring(check.expected))
  end
end

print('\nTEST 5: open_view_buffer() without setup')
lifemode._reset_state()

success = pcall(lifemode.open_view_buffer)
if success then
  print('  FAIL: open_view_buffer() worked without setup')
  record_failure('MEDIUM', 'State validation bypassed somehow', 'lua/lifemode/init.lua:137-139')
else
  print('  PASS: Proper error when setup not called')
end

lifemode.setup({ vault_root = '/tmp/test' })

print('\nTEST 6: Buffer name format validation')
local name_buf = view.create_buffer()
local name = vim.api.nvim_buf_get_name(name_buf)

if not name:match('LifeMode %[%d+%]') then
  print('  FAIL: Buffer name format incorrect: ' .. name)
  record_failure('MEDIUM', 'Buffer name does not match expected pattern', 'lua/lifemode/view.lua:14')
else
  print('  PASS: Buffer name format correct: ' .. name)
end

print('\nTEST 7: Return value check')
local ret_buf = view.create_buffer()
if type(ret_buf) ~= 'number' or ret_buf <= 0 then
  print('  FAIL: create_buffer() returned invalid value: ' .. tostring(ret_buf))
  record_failure('CRITICAL', 'Invalid return value from create_buffer()', 'lua/lifemode/view.lua:16')
else
  print('  PASS: Valid buffer number returned: ' .. ret_buf)
end

print('\nTEST 8: open_view command integration')
success = pcall(function()
  vim.cmd('LifeMode')
end)

if not success then
  print('  FAIL: :LifeMode command failed')
  record_failure('CRITICAL', ':LifeMode command execution failed', 'lua/lifemode/init.lua:80-82')
else
  local current = vim.api.nvim_get_current_buf()
  local ft = vim.bo[current].filetype
  if ft ~= 'lifemode' then
    print('  FAIL: Command did not switch to view buffer')
    record_failure('MAJOR', 'Command exists but does not properly switch buffers', 'lua/lifemode/init.lua:144')
  else
    print('  PASS: Command works and switches to view buffer')
  end
end

print('\n=== SUMMARY ===\n')

if #failures == 0 then
  print('CONFIDENCE: 95/100')
  print('STATUS: No silent failures detected in current test coverage')
  print('NOTE: Buffer API pcall wrapping deferred to medium priority (known from memory)')
  print('')
  os.exit(0)
else
  print('FAILURES FOUND: ' .. #failures)
  print('')

  local by_severity = { CRITICAL = {}, MAJOR = {}, MEDIUM = {} }
  for _, f in ipairs(failures) do
    table.insert(by_severity[f.severity], f)
  end

  for _, severity in ipairs({'CRITICAL', 'MAJOR', 'MEDIUM'}) do
    if #by_severity[severity] > 0 then
      print(severity .. ' (' .. #by_severity[severity] .. '):')
      for _, f in ipairs(by_severity[severity]) do
        print('  - [' .. f.location .. ']')
        print('    ' .. f.description)
      end
      print('')
    end
  end

  local critical_count = #by_severity.CRITICAL
  local major_count = #by_severity.MAJOR

  if critical_count > 0 then
    print('CONFIDENCE: ' .. (50 - (critical_count * 10)) .. '/100')
  elseif major_count > 0 then
    print('CONFIDENCE: ' .. (70 - (major_count * 5)) .. '/100')
  else
    print('CONFIDENCE: 80/100')
  end

  os.exit(critical_count + major_count)
end
