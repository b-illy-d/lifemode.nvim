vim.opt.runtimepath:prepend('/Users/billy/lifemode.nvim')

local parser = require('lifemode.parser')

print("Testing SPEC.md colon ID examples...")

local test_cases = {
  {line = "- [ ] Implement indexer !2 @due(2026-02-01) #lifemode ^t:indexer", expected_id = "t:indexer"},
  {line = "- [[source:Smith2019]] ^s:smith2019", expected_id = "s:smith2019"},
  {line = "- [[source:DesiringGodPost2024]] ^s:dg2024", expected_id = "s:dg2024"},
  {line = "- Smith argues X in his commentary. ^c:001", expected_id = "c:001"},
}

local pass = 0
local fail = 0

for i, test in ipairs(test_cases) do
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {test.line})

  local blocks = parser.parse_buffer(bufnr)
  local id = blocks[1] and blocks[1].id or nil

  vim.api.nvim_buf_delete(bufnr, {force = true})

  if id == test.expected_id then
    print(string.format("✓ TEST %d: '%s' → id='%s'", i, test.expected_id, id))
    pass = pass + 1
  else
    print(string.format("✗ TEST %d: Expected '%s', got '%s'", i, test.expected_id, id or "nil"))
    fail = fail + 1
  end
end

print(string.format("\nResults: %d PASS, %d FAIL", pass, fail))

if fail > 0 then
  print("CRITICAL: SPEC examples fail")
  os.exit(1)
else
  print("SUCCESS: All SPEC examples work")
  os.exit(0)
end
