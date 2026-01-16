vim.opt.runtimepath:append('.')

print("Direct pattern test...")

local test_text = "Task text ^t:indexer"

local before_id, id = test_text:match('^(.-)%s*%^([%w%-:]+)%s*$')

print(string.format("Input: '%s'", test_text))
print(string.format("Pattern: '^(.-)%%s*%%^([%%w%%-:]+)%%s*$'"))
print(string.format("Result: before_id='%s', id='%s'", before_id or "nil", id or "nil"))

if id then
  print("SUCCESS: Pattern matched")
  os.exit(0)
else
  print("FAIL: Pattern did not match")
  os.exit(1)
end
