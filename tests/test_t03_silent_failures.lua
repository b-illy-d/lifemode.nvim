local function setup()
  vim.cmd('set runtimepath+=.')
  require('lifemode')._reset_state()
  require('lifemode').setup({ vault_root = '/tmp/vault' })
end

local function test_nvim_buf_get_lines_failure()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '# Test' })
  vim.api.nvim_buf_delete(bufnr, { force = true })

  local success, err = pcall(function()
    parser.parse_buffer(bufnr)
  end)

  if success then
    print('FAIL: Should have failed with deleted buffer')
    os.exit(1)
  end

  print('PASS: nvim_buf_get_lines failure handling')
end

local function test_extremely_long_line()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  local long_text = string.rep('a', 100000)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# ' .. long_text
  })

  local success, blocks = pcall(function()
    return parser.parse_buffer(bufnr)
  end)

  if not success then
    print('FAIL: Should handle long lines: ' .. tostring(blocks))
    vim.api.nvim_buf_delete(bufnr, { force = true })
    os.exit(1)
  end

  assert(#blocks == 1, 'Should parse long line')
  assert(blocks[1].type == 'heading', 'Should identify as heading')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Extremely long line')
end

local function test_unicode_in_text()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# 日本語 Heading 中文',
    '- [ ] Task with emoji 🚀 ✅',
    '- List with unicode • § ©',
  })

  local success, blocks = pcall(function()
    return parser.parse_buffer(bufnr)
  end)

  if not success then
    print('FAIL: Should handle unicode: ' .. tostring(blocks))
    vim.api.nvim_buf_delete(bufnr, { force = true })
    os.exit(1)
  end

  assert(#blocks == 3, 'Should parse all unicode lines')
  assert(blocks[1].text:match('日本語'), 'Should preserve unicode text')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Unicode in text')
end

local function test_special_chars_in_id()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# Heading ^id_with_underscore',
    '# Heading ^id-with-hyphen',
    '# Heading ^id123numeric',
    '# Heading ^ID-UPPER',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 4, 'Should parse all lines')
  assert(blocks[1].id == 'id_with_underscore', 'Should extract underscore ID')
  assert(blocks[2].id == 'id-with-hyphen', 'Should extract hyphen ID')
  assert(blocks[3].id == 'id123numeric', 'Should extract numeric ID')
  assert(blocks[4].id == 'ID-UPPER', 'Should extract uppercase ID')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Special chars in ID')
end

local function test_malformed_heading()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '#NoSpace',
    '####### TooManyHashes',
    '# ',
    '#',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 0, 'Should not parse malformed headings (got ' .. #blocks .. ')')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Malformed heading handling')
end

local function test_malformed_task()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '-[x] NoSpace',
    '- [y] InvalidChar',
    '- []MissingContent',
    '- [ ]NoText',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(blocks[1] and blocks[1].type == 'list_item', 'Line 1 should be list_item (malformed task)')
  assert(blocks[2] and blocks[2].type == 'list_item', 'Line 2 should be list_item (invalid checkbox)')
  assert(blocks[3] and blocks[3].type == 'list_item', 'Line 3 should be list_item (malformed)')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Malformed task handling')
end

local function test_edge_whitespace()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '   # Heading with leading spaces',
    '# Heading with trailing spaces   ',
    '\t- List with tab',
    '- [ ] Task with multiple   spaces   between   words',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(blocks[1] == nil or blocks[1].type ~= 'heading', 'Leading spaces before # should not parse')
  assert(blocks[2] and blocks[2].type == 'heading', 'Trailing spaces should parse')
  assert(blocks[3] and blocks[3].type == 'list_item', 'Tab indent should parse')
  assert(blocks[4] and blocks[4].type == 'task', 'Multiple spaces should parse')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Edge whitespace handling')
end

local function test_empty_buffer()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 0, 'Empty buffer should return empty list')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Empty buffer')
end

local function test_large_file_performance()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  local lines = {}
  for i = 1, 10000 do
    lines[i] = '# Heading ' .. i .. ' ^id-' .. i
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  local start_time = vim.loop.hrtime()
  local blocks = parser.parse_buffer(bufnr)
  local end_time = vim.loop.hrtime()

  local duration_ms = (end_time - start_time) / 1000000

  assert(#blocks == 10000, 'Should parse all 10000 lines')

  if duration_ms > 1000 then
    print('WARNING: Large file parsing took ' .. duration_ms .. 'ms (>1s)')
  end

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Large file performance (' .. string.format('%.2f', duration_ms) .. 'ms)')
end

local function test_pattern_injection()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# Heading with () parentheses',
    '# Heading with [brackets]',
    '# Heading with {braces}',
    '# Heading with * asterisk',
    '# Heading with + plus',
    '# Heading with ? question',
    '- [ ] Task with %s pattern chars',
  })

  local success, blocks = pcall(function()
    return parser.parse_buffer(bufnr)
  end)

  if not success then
    print('FAIL: Pattern characters caused crash: ' .. tostring(blocks))
    vim.api.nvim_buf_delete(bufnr, { force = true })
    os.exit(1)
  end

  assert(#blocks == 7, 'Should parse lines with pattern chars')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Pattern injection handling')
end

local function test_id_with_invalid_chars()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# Heading ^id with spaces',
    '# Heading ^id@special',
    '# Heading ^id!exclaim',
    '# Heading ^',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 4, 'Should parse all lines')
  assert(blocks[1].id == nil, 'ID with spaces should not be extracted')
  assert(blocks[2].id == nil, 'ID with @ should not be extracted')
  assert(blocks[3].id == nil, 'ID with ! should not be extracted')
  assert(blocks[4].id == nil, 'Empty ID should not be extracted')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: ID with invalid chars')
end

local function test_nil_input_handling()
  local parser = require('lifemode.parser')

  local success, err = pcall(function()
    parser.parse_buffer(nil)
  end)

  assert(not success, 'Should fail with nil buffer')
  assert(err:match('Invalid buffer number'), 'Error message should mention invalid buffer')

  print('PASS: Nil input handling')
end

local function test_negative_buffer_number()
  local parser = require('lifemode.parser')

  local success, err = pcall(function()
    parser.parse_buffer(-1)
  end)

  if success then
    print('FAIL: Should have failed with negative buffer number')
    os.exit(1)
  end

  print('PASS: Negative buffer number')
end

local function test_parse_current_buffer_no_crash()
  local lifemode = require('lifemode')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '# Test' })
  vim.api.nvim_set_current_buf(bufnr)

  local success, err = pcall(function()
    lifemode.parse_current_buffer()
  end)

  if not success then
    print('FAIL: parse_current_buffer crashed: ' .. tostring(err))
    vim.api.nvim_buf_delete(bufnr, { force = true })
    os.exit(1)
  end

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: parse_current_buffer no crash')
end

local function test_state_modification()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  local original_lines = { '# Test 1', '- [ ] Task 1' }
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, original_lines)

  local blocks1 = parser.parse_buffer(bufnr)

  blocks1[1].text = 'MODIFIED'
  blocks1[1].line = 999

  local lines_after = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  assert(lines_after[1] == original_lines[1], 'Buffer should not be modified by parsing')

  local blocks2 = parser.parse_buffer(bufnr)

  assert(blocks2[1].text ~= 'MODIFIED', 'Modifying returned blocks should not affect future parses')
  assert(blocks2[1].line == 0, 'Line should be original value')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: State modification isolation')
end

local function run_all_tests()
  setup()

  print('Running T03 Silent Failure Hunt...')
  print('')

  test_nvim_buf_get_lines_failure()
  test_extremely_long_line()
  test_unicode_in_text()
  test_special_chars_in_id()
  test_malformed_heading()
  test_malformed_task()
  test_edge_whitespace()
  test_empty_buffer()
  test_large_file_performance()
  test_pattern_injection()
  test_id_with_invalid_chars()
  test_nil_input_handling()
  test_negative_buffer_number()
  test_parse_current_buffer_no_crash()
  test_state_modification()

  print('')
  print('All T03 silent failure tests passed!')
end

run_all_tests()
