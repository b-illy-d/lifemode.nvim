local parser = require('lifemode.parser')

print('Testing nvim_buf_get_lines failure modes...')
print('')

local function test_deleted_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '# Test' })
  vim.api.nvim_buf_delete(bufnr, { force = true })

  local success, err = pcall(function()
    parser.parse_buffer(bufnr)
  end)

  if success then
    print('[FAIL] Deleted buffer: Should have raised error')
    return false
  else
    print('[PASS] Deleted buffer: Error raised - ' .. tostring(err))
    return true
  end
end

local function test_nvim_buf_get_lines_directly()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_delete(bufnr, { force = true })

  local success, result = pcall(function()
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end)

  if success then
    print('[FAIL] nvim_buf_get_lines with deleted buffer: No error raised')
    print('       Result: ' .. vim.inspect(result))
    return false
  else
    print('[PASS] nvim_buf_get_lines with deleted buffer: Error raised')
    print('       Error: ' .. tostring(result))
    return true
  end
end

local function test_invalid_bufnr_999999()
  local success, result = pcall(function()
    return vim.api.nvim_buf_get_lines(999999, 0, -1, false)
  end)

  if success then
    print('[FAIL] nvim_buf_get_lines with invalid bufnr 999999: No error raised')
    print('       Result: ' .. vim.inspect(result))
    return false
  else
    print('[PASS] nvim_buf_get_lines with invalid bufnr 999999: Error raised')
    print('       Error: ' .. tostring(result))
    return true
  end
end

print('=== Direct API Tests ===')
local t1 = test_nvim_buf_get_lines_directly()
local t2 = test_invalid_bufnr_999999()

print('')
print('=== Parser Wrapper Tests ===')
local t3 = test_deleted_buffer()

print('')
if t1 and t2 and t3 then
  print('All buffer API failure handling tests PASS')
else
  print('FAIL: Some buffer API failure tests failed')
  os.exit(1)
end
