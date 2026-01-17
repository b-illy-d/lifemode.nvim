local parser = require('lifemode.parser')

local tests_passed = 0
local tests_failed = 0

local function test(description, line, checks)
  local success, err = pcall(function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {line})

    local blocks = parser.parse_buffer(bufnr)
    vim.api.nvim_buf_delete(bufnr, {force = true})

    if #blocks ~= 1 then
      error('Expected 1 block, got ' .. #blocks)
    end

    local task = blocks[1]
    if task.type ~= 'task' then
      error('Expected task type, got ' .. task.type)
    end

    checks(task)
  end)

  if success then
    tests_passed = tests_passed + 1
    print('PASS: ' .. description)
  else
    tests_failed = tests_failed + 1
    print('FAIL: ' .. description)
    print('  ' .. tostring(err))
  end
end

test('Invalid priority !0 ignored', '- [ ] Task !0', function(task)
  assert(task.priority == nil, 'Expected no priority')
end)

test('Invalid priority !6 ignored', '- [ ] Task !6', function(task)
  assert(task.priority == nil, 'Expected no priority')
end)

test('Priority without space', '- [ ] Task!3', function(task)
  assert(task.priority == 3, 'Expected priority 3')
end)

test('Invalid due format ignored', '- [ ] Task @due(2026-1-1)', function(task)
  assert(task.due == nil, 'Expected no due date')
end)

test('Invalid due format (wrong separator)', '- [ ] Task @due(2026/01/16)', function(task)
  assert(task.due == nil, 'Expected no due date')
end)

test('Tag with hyphen', '- [ ] Task #my-tag', function(task)
  assert(task.tags and #task.tags == 1, 'Expected 1 tag')
  assert(task.tags[1] == 'my-tag', 'Expected tag my-tag')
end)

test('Tag with underscore', '- [ ] Task #my_tag', function(task)
  assert(task.tags and #task.tags == 1, 'Expected 1 tag')
  assert(task.tags[1] == 'my_tag', 'Expected tag my_tag')
end)

test('Tag at start of text', '- [ ] #urgent Fix bug', function(task)
  assert(task.tags and #task.tags == 1, 'Expected 1 tag')
  assert(task.tags[1] == 'urgent', 'Expected tag urgent')
  assert(task.text == 'Fix bug', 'Expected text without tag')
end)

test('Multiple spaces between metadata', '- [ ] Task  !2  @due(2026-01-16)  #work', function(task)
  assert(task.priority == 2, 'Expected priority 2')
  assert(task.due == '2026-01-16', 'Expected due date')
  assert(task.tags and #task.tags == 1, 'Expected 1 tag')
end)

test('Metadata stripped from text', '- [ ] Important task !1 @due(2026-01-16) #work', function(task)
  assert(task.text == 'Important task', 'Text should not contain metadata')
  assert(not task.text:match('!'), 'Text should not contain !')
  assert(not task.text:match('@'), 'Text should not contain @')
  assert(not task.text:match('#'), 'Text should not contain #')
end)

test('Hash in URL not treated as tag', '- [ ] Check https://example.com#section', function(task)
  assert(task.tags == nil or #task.tags == 0, 'Expected no tags')
end)

test('Priority in middle of word ignored', '- [ ] Task abc!3def', function(task)
  assert(task.priority == nil, 'Expected no priority')
end)

test('Exclamation without digit ignored', '- [ ] Task !urgent', function(task)
  assert(task.priority == nil, 'Expected no priority')
end)

test('Multiple priorities, last one wins', '- [ ] Task !1 !3', function(task)
  assert(task.priority == 3, 'Expected priority 3 (last one)')
end)

test('Text with tags stripped correctly', '- [ ] Task #work #personal note', function(task)
  assert(task.tags and #task.tags == 2, 'Expected 2 tags')
  assert(task.text == 'Task note', 'Expected text without tags')
end)

if tests_failed > 0 then
  print(string.format('\nTotal: %d passed, %d failed', tests_passed, tests_failed))
  vim.cmd('cq 1')
else
  print(string.format('\nAll %d tests passed', tests_passed))
  vim.cmd('quit')
end
