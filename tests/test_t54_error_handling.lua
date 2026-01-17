local function reset_modules()
  package.loaded['lifemode'] = nil
  package.loaded['lifemode.config'] = nil
  package.loaded['lifemode.patch'] = nil
end

reset_modules()

local function assert_equal(actual, expected, label)
  if actual ~= expected then
    print('FAIL: ' .. label)
    print('  expected: ' .. vim.inspect(expected))
    print('  got: ' .. vim.inspect(actual))
    vim.cmd('cq 1')
  end
end

local function assert_truthy(value, label)
  if not value then
    print('FAIL: ' .. label)
    vim.cmd('cq 1')
  end
end

print('TEST: setup without vault_root throws error')
local lifemode = require('lifemode')
local ok, err = pcall(function()
  lifemode.setup({})
end)
assert_equal(ok, false, 'setup without vault_root fails')
assert_truthy(err:match('vault_root'), 'error mentions vault_root')
lifemode._reset_state()
print('PASS')

print('TEST: duplicate setup throws error')
reset_modules()
lifemode = require('lifemode')
local test_dir = vim.fn.tempname()
vim.fn.mkdir(test_dir, 'p')

lifemode.setup({ vault_root = test_dir })
ok, err = pcall(function()
  lifemode.setup({ vault_root = test_dir })
end)
assert_equal(ok, false, 'duplicate setup fails')
assert_truthy(err:match('already called'), 'error mentions already called')
lifemode._reset_state()
print('PASS')

print('TEST: patch returns nil for missing file')
local patch = require('lifemode.patch')
local result = patch.ensure_id('/nonexistent/file.md', 0)
assert_equal(result, nil, 'returns nil for missing file')
print('PASS')

print('TEST: patch returns nil for invalid line')
local test_file = test_dir .. '/test.md'
vim.fn.writefile({'line 1'}, test_file)
result = patch.ensure_id(test_file, 999)
assert_equal(result, nil, 'returns nil for invalid line')
print('PASS')

print('TEST: parser handles missing file path')
local parser = require('lifemode.parser')
ok, err = pcall(function()
  parser.parse_file('')
end)
assert_equal(ok, false, 'empty path throws')
print('PASS')

vim.fn.delete(test_dir, 'rf')

print('\nAll tests passed')
vim.cmd('quit')
