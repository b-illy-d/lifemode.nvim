local function setup()
  vim.cmd('set runtimepath+=.')
  require('lifemode')._reset_state()
  require('lifemode').setup({ vault_root = '/tmp/vault' })
end

local function test_parse_empty_buffer()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  local blocks = parser.parse_buffer(bufnr)

  assert(type(blocks) == 'table', 'Should return table')
  assert(#blocks == 0, 'Empty buffer should have 0 blocks')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Parse empty buffer')
end

local function test_parse_single_heading()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# Heading 1',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 1, 'Should have 1 block')
  assert(blocks[1].type == 'heading', 'Type should be heading')
  assert(blocks[1].level == 1, 'Level should be 1')
  assert(blocks[1].text == 'Heading 1', 'Text should match')
  assert(blocks[1].line == 0, 'Line should be 0 (0-indexed)')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Parse single heading')
end

local function test_parse_heading_with_id()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# Heading ^550e8400-e29b-41d4-a716-446655440000',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 1, 'Should have 1 block')
  assert(blocks[1].type == 'heading', 'Type should be heading')
  assert(blocks[1].text == 'Heading', 'Text should exclude ^id suffix')
  assert(blocks[1].id == '550e8400-e29b-41d4-a716-446655440000', 'ID should be extracted')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Parse heading with ID')
end

local function test_parse_task_todo()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '- [ ] Task item',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 1, 'Should have 1 block')
  assert(blocks[1].type == 'task', 'Type should be task')
  assert(blocks[1].state == 'todo', 'State should be todo')
  assert(blocks[1].text == 'Task item', 'Text should match')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Parse task todo')
end

local function test_parse_task_done()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '- [x] Completed task',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 1, 'Should have 1 block')
  assert(blocks[1].type == 'task', 'Type should be task')
  assert(blocks[1].state == 'done', 'State should be done')
  assert(blocks[1].text == 'Completed task', 'Text should match')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Parse task done')
end

local function test_parse_task_with_id()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '- [ ] Task with ID ^abc-123',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 1, 'Should have 1 block')
  assert(blocks[1].type == 'task', 'Type should be task')
  assert(blocks[1].text == 'Task with ID', 'Text should exclude ^id')
  assert(blocks[1].id == 'abc-123', 'ID should be extracted')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Parse task with ID')
end

local function test_parse_list_item()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '- Regular list item',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 1, 'Should have 1 block')
  assert(blocks[1].type == 'list_item', 'Type should be list_item')
  assert(blocks[1].text == 'Regular list item', 'Text should match')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Parse list item')
end

local function test_parse_mixed_content()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# Heading 1',
    '- [ ] Task 1',
    '- Regular item',
    '## Heading 2 ^h2-id',
    '- [x] Done task ^task-id',
  })

  local blocks = parser.parse_buffer(bufnr)

  assert(#blocks == 5, 'Should have 5 blocks')
  assert(blocks[1].type == 'heading', 'First block should be heading')
  assert(blocks[2].type == 'task', 'Second block should be task')
  assert(blocks[3].type == 'list_item', 'Third block should be list_item')
  assert(blocks[4].type == 'heading', 'Fourth block should be heading')
  assert(blocks[4].id == 'h2-id', 'Fourth block should have ID')
  assert(blocks[5].type == 'task', 'Fifth block should be task')
  assert(blocks[5].state == 'done', 'Fifth block should be done')
  assert(blocks[5].id == 'task-id', 'Fifth block should have ID')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Parse mixed content')
end

local function test_parse_buffer_counts()
  local parser = require('lifemode.parser')

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    '# Heading',
    '- [ ] Task 1',
    '- [ ] Task 2',
    '- Regular item',
    '- [x] Task 3',
  })

  local blocks = parser.parse_buffer(bufnr)

  local task_count = 0
  for _, block in ipairs(blocks) do
    if block.type == 'task' then
      task_count = task_count + 1
    end
  end

  assert(#blocks == 5, 'Should have 5 blocks total')
  assert(task_count == 3, 'Should have 3 tasks')

  vim.api.nvim_buf_delete(bufnr, { force = true })
  print('PASS: Parse buffer counts')
end

local function run_all_tests()
  setup()

  print('Running T03 Acceptance Tests...')
  print('')

  test_parse_empty_buffer()
  test_parse_single_heading()
  test_parse_heading_with_id()
  test_parse_task_todo()
  test_parse_task_done()
  test_parse_task_with_id()
  test_parse_list_item()
  test_parse_mixed_content()
  test_parse_buffer_counts()

  print('')
  print('All T03 acceptance tests passed!')
end

run_all_tests()
