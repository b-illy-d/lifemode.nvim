local function setup()
  vim.cmd('set runtimepath+=.')
  require('lifemode')._reset_state()
  require('lifemode').setup({ vault_root = '/tmp/vault' })
end

local function test_invalid_buffer()
  local parser = require('lifemode.parser')

  local success, err = pcall(function()
    parser.parse_buffer(0)
  end)

  assert(not success, 'Should fail with invalid buffer')
  assert(err:match('Invalid buffer number'), 'Error message should mention invalid buffer')

  print('PASS: Invalid buffer')
end

local function test_headings_multiple_levels()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# Level 1',
    '## Level 2',
    '### Level 3',
    '#### Level 4',
    '##### Level 5',
    '###### Level 6',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 6, 'Should have 6 blocks')
  for i = 1, 6 do
    assert(blocks[i].type == 'heading', 'Should be heading')
    assert(blocks[i].level == i, 'Level should be ' .. i)
  end

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Headings multiple levels')
end

local function test_task_with_uppercase_x()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '- [X] Task with uppercase X',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 1, 'Should have 1 block')
  assert(blocks[1].state == 'done', 'Uppercase X should be done state')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Task with uppercase X')
end

local function test_indented_list_items()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '- Level 0',
    '  - Level 1',
    '    - Level 2',
    '      - [ ] Indented task',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 4, 'Should parse all indented items')
  assert(blocks[1].type == 'list_item', 'First should be list_item')
  assert(blocks[2].type == 'list_item', 'Second should be list_item')
  assert(blocks[3].type == 'list_item', 'Third should be list_item')
  assert(blocks[4].type == 'task', 'Fourth should be task')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Indented list items')
end

local function test_id_with_hyphens()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# Heading ^550e8400-e29b-41d4-a716-446655440000',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 1, 'Should have 1 block')
  assert(blocks[1].id == '550e8400-e29b-41d4-a716-446655440000', 'Should extract UUID with hyphens')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: ID with hyphens')
end

local function test_id_without_hyphens()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '- [ ] Task ^abc123xyz',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 1, 'Should have 1 block')
  assert(blocks[1].id == 'abc123xyz', 'Should extract alphanumeric ID')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: ID without hyphens')
end

local function test_text_with_caret_not_id()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '- Use ^C to cancel',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 1, 'Should have 1 block')
  assert(blocks[1].text == 'Use ^C to cancel', 'Text with ^ not at end should not be treated as ID')
  assert(blocks[1].id == nil, 'Should not extract ID')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Text with caret not ID')
end

local function test_whitespace_around_id()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# Heading   ^id-123   ',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 1, 'Should have 1 block')
  assert(blocks[1].text == 'Heading', 'Text should be trimmed')
  assert(blocks[1].id == 'id-123', 'ID should be extracted despite whitespace')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Whitespace around ID')
end

local function test_ignore_non_markdown_lines()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# Heading',
    'Regular paragraph text',
    'Another line of text',
    '- [ ] Task',
    '',
    'More text',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 2, 'Should only parse headings and list items')
  assert(blocks[1].type == 'heading', 'First should be heading')
  assert(blocks[2].type == 'task', 'Second should be task')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Ignore non-markdown lines')
end

local function run_all_tests()
  setup()

  print('Running T03 Edge Case Tests...')
  print('')

  test_invalid_buffer()
  test_headings_multiple_levels()
  test_task_with_uppercase_x()
  test_indented_list_items()
  test_id_with_hyphens()
  test_id_without_hyphens()
  test_text_with_caret_not_id()
  test_whitespace_around_id()
  test_ignore_non_markdown_lines()

  print('')
  print('All T03 edge case tests passed!')
end

run_all_tests()
