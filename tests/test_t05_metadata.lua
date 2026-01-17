local parser = require('lifemode.parser')

local function test_task_metadata(line, expected_priority, expected_due, expected_tags, description)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {line})

  local blocks = parser.parse_buffer(bufnr)
  vim.api.nvim_buf_delete(bufnr, {force = true})

  if #blocks ~= 1 then
    print('FAIL: ' .. description .. ' - expected 1 block, got ' .. #blocks)
    vim.cmd('cq 1')
  end

  local task = blocks[1]
  if task.type ~= 'task' then
    print('FAIL: ' .. description .. ' - expected task type, got ' .. task.type)
    vim.cmd('cq 1')
  end

  if task.priority ~= expected_priority then
    print('FAIL: ' .. description .. ' - priority')
    print('  expected: ' .. tostring(expected_priority))
    print('  got: ' .. tostring(task.priority))
    vim.cmd('cq 1')
  end

  if task.due ~= expected_due then
    print('FAIL: ' .. description .. ' - due date')
    print('  expected: ' .. tostring(expected_due))
    print('  got: ' .. tostring(task.due))
    vim.cmd('cq 1')
  end

  if expected_tags then
    if not task.tags then
      print('FAIL: ' .. description .. ' - expected tags, got nil')
      vim.cmd('cq 1')
    end
    if #task.tags ~= #expected_tags then
      print('FAIL: ' .. description .. ' - tag count')
      print('  expected: ' .. #expected_tags)
      print('  got: ' .. #task.tags)
      vim.cmd('cq 1')
    end
    for i, tag in ipairs(expected_tags) do
      if task.tags[i] ~= tag then
        print('FAIL: ' .. description .. ' - tag[' .. i .. ']')
        print('  expected: ' .. tag)
        print('  got: ' .. tostring(task.tags[i]))
        vim.cmd('cq 1')
      end
    end
  elseif task.tags then
    print('FAIL: ' .. description .. ' - expected no tags, got: ' .. vim.inspect(task.tags))
    vim.cmd('cq 1')
  end

  print('PASS: ' .. description)
end

test_task_metadata(
  '- [ ] Simple task',
  nil, nil, nil,
  'Task without metadata'
)

test_task_metadata(
  '- [ ] Task with priority !1',
  1, nil, nil,
  'Priority !1 (highest)'
)

test_task_metadata(
  '- [ ] Task with priority !5',
  5, nil, nil,
  'Priority !5 (lowest)'
)

test_task_metadata(
  '- [ ] Task with due @due(2026-01-16)',
  nil, '2026-01-16', nil,
  'Due date extraction'
)

test_task_metadata(
  '- [ ] Task with tag #work',
  nil, nil, {'work'},
  'Single tag'
)

test_task_metadata(
  '- [ ] Task with nested tag #work/urgent',
  nil, nil, {'work/urgent'},
  'Nested tag'
)

test_task_metadata(
  '- [ ] Task #work #personal',
  nil, nil, {'work', 'personal'},
  'Multiple tags'
)

test_task_metadata(
  '- [ ] Complete task !2 @due(2026-02-01) #lifemode',
  2, '2026-02-01', {'lifemode'},
  'All metadata together'
)

test_task_metadata(
  '- [ ] Task !1 @due(2026-01-16) #work #urgent ^task-id',
  1, '2026-01-16', {'work', 'urgent'},
  'All metadata with ID'
)

test_task_metadata(
  '- [ ] Order test #tag1 !3 #tag2 @due(2026-01-20)',
  3, '2026-01-20', {'tag1', 'tag2'},
  'Metadata in mixed order'
)

print('\nAll tests passed')
vim.cmd('quit')
