local function reset_modules()
  package.loaded['lifemode.lens'] = nil
end

reset_modules()

local function assert_truthy(value, label)
  if not value then
    print('FAIL: ' .. label)
    vim.cmd('cq 1')
  end
end

local lens = require('lifemode.lens')

print('TEST: source/biblio lens renders source')
local node = {
  type = 'source',
  text = 'type:: source',
  props = {
    title = 'The Art of Code',
    author = 'John Smith',
    year = '2020',
    kind = 'book',
  },
}

local result = lens.render(node, 'source/biblio')
assert_truthy(result.lines, 'has lines')
local text = table.concat(result.lines, '\n')
assert_truthy(text:match('Art of Code'), 'contains title')
assert_truthy(text:match('Smith'), 'contains author')
assert_truthy(text:match('2020'), 'contains year')
print('PASS')

print('TEST: source/biblio lens handles missing props')
node = {
  type = 'source',
  text = 'type:: source',
  props = {
    title = 'Untitled Work',
  },
}

result = lens.render(node, 'source/biblio')
assert_truthy(result.lines, 'has lines')
local text = table.concat(result.lines, '\n')
assert_truthy(text:match('Untitled Work'), 'contains title')
print('PASS')

print('TEST: citation/brief lens renders citation')
node = {
  type = 'citation',
  text = 'type:: citation',
  props = {
    source = '^source-1',
    pages = '42-45',
  },
}

result = lens.render(node, 'citation/brief')
assert_truthy(result.lines, 'has lines')
local text = table.concat(result.lines, '\n')
assert_truthy(text:match('source%-1') or text:match('42'), 'contains citation info')
print('PASS')

print('TEST: source/biblio is in available lenses for source')
local available = lens.get_available_lenses('source')
assert_truthy(vim.tbl_contains(available, 'source/biblio'), 'source/biblio available')
print('PASS')

print('TEST: citation/brief is in available lenses for citation')
available = lens.get_available_lenses('citation')
assert_truthy(vim.tbl_contains(available, 'citation/brief'), 'citation/brief available')
print('PASS')

print('\nAll tests passed')
vim.cmd('quit')
