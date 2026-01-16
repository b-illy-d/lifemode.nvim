vim.opt.runtimepath:prepend('/Users/billy/lifemode.nvim')

package.loaded['lifemode.parser'] = nil

local parser = require('lifemode.parser')

local test_text = "Task text ^t:indexer"

local text, id = parser._extract_id(test_text)

print(string.format("Input: '%s'", test_text))
print(string.format("Result: text='%s', id='%s'", text or "nil", id or "nil"))

if id == "t:indexer" then
  print("SUCCESS")
  os.exit(0)
else
  print("FAIL")
  os.exit(1)
end
