vim.opt.runtimepath:prepend('.')

for k in pairs(package.loaded) do
  if k:match('^lifemode') then
    package.loaded[k] = nil
  end
end

local parser = require('lifemode.parser')

print("Testing ID pattern bug via parse_buffer...")
print(string.format("Loaded from: %s", package.searchpath('lifemode.parser', package.path)))

local test_cases = {
  {line = "- [ ] Task text ^t:indexer", expected_id = "t:indexer", desc = "Colon ID (SPEC example)"},
  {line = "- [ ] Task text ^s:smith2019", expected_id = "s:smith2019", desc = "Colon ID (SPEC example)"},
  {line = "- [ ] Task text ^c:001", expected_id = "c:001", desc = "Colon ID (SPEC example)"},
  {line = "- [ ] Task text ^my_id", expected_id = "my_id", desc = "Underscore ID"},
  {line = "- [ ] Task text ^abc-123", expected_id = "abc-123", desc = "Hyphen ID (current pattern)"},
  {line = "- [ ] Task text ^abc123", expected_id = "abc123", desc = "Alphanumeric ID (current pattern)"},
  {line = "- [ ] Task text ^uuid-1234-5678", expected_id = "uuid-1234-5678", desc = "UUID-like (current pattern)"},
  {line = "- [ ] Task text ^a:b_c-d", expected_id = "a:b_c-d", desc = "Mixed special chars"},
}

local pass_count = 0
local fail_count = 0

for i, test in ipairs(test_cases) do
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {test.line})

  local blocks = parser.parse_buffer(bufnr)
  local id = blocks[1] and blocks[1].id or nil

  vim.api.nvim_buf_delete(bufnr, {force = true})

  if id == test.expected_id then
    print(string.format("✓ TEST %d PASS: %s", i, test.desc))
    pass_count = pass_count + 1
  else
    print(string.format("✗ TEST %d FAIL: %s", i, test.desc))
    print(string.format("  Expected: '%s', Got: '%s'", test.expected_id, id or "nil"))
    fail_count = fail_count + 1
  end
end

print(string.format("\nResults: %d/%d PASS, %d FAIL", pass_count, #test_cases, fail_count))

if fail_count > 0 then
  print("\nCRITICAL: ID pattern is incomplete - SPEC examples fail")
  os.exit(1)
else
  print("\nAll ID patterns work correctly")
  os.exit(0)
end
