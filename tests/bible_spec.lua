#!/usr/bin/env -S nvim -l

-- Tests for bible reference parsing
-- Task: T07 - Bible reference extraction and parsing

local test_count = 0
local pass_count = 0
local fail_count = 0

local function assert_equals(expected, actual)
  if expected ~= actual then
    error(string.format("Expected %s but got %s", vim.inspect(expected), vim.inspect(actual)))
  end
end

local function test(name, fn)
  test_count = test_count + 1
  io.write(string.format("  [%d] %s ... ", test_count, name))
  io.flush()

  local ok, err = pcall(fn)
  if ok then
    pass_count = pass_count + 1
    print("PASS")
  else
    fail_count = fail_count + 1
    print(string.format("FAIL\n      %s", err))
  end
end

local function describe(name, tests_fn)
  print(string.format("\n%s", name))
  tests_fn()
end

-- Add lua directory to package path
package.path = package.path .. ';lua/?.lua;lua/?/init.lua'

-- Load the module
local bible = require('lifemode.bible')

-- Test suite
describe("Bible Reference Parsing - Single Verses", function()
  test("parses single verse (full book name)", function()
    local refs = bible.parse_bible_refs("John 17:20")
    assert_equals(1, #refs)
    assert_equals("bible:john:17:20", refs[1].target)
    assert_equals("bible_verse", refs[1].type)
  end)

  test("parses single verse (abbreviated book name)", function()
    local refs = bible.parse_bible_refs("Rom 8:28")
    assert_equals(1, #refs)
    assert_equals("bible:romans:8:28", refs[1].target)
    assert_equals("bible_verse", refs[1].type)
  end)

  test("handles abbreviated Genesis", function()
    local refs = bible.parse_bible_refs("Gen 1:1")
    assert_equals(1, #refs)
    assert_equals("bible:genesis:1:1", refs[1].target)
  end)

  test("handles abbreviated Matthew", function()
    local refs = bible.parse_bible_refs("Matt 5:3")
    assert_equals(1, #refs)
    assert_equals("bible:matthew:5:3", refs[1].target)
  end)

  test("case insensitive book names", function()
    local refs = bible.parse_bible_refs("JOHN 3:16")
    assert_equals(1, #refs)
    assert_equals("bible:john:3:16", refs[1].target)
  end)
end)

describe("Bible Reference Parsing - Verse Ranges", function()
  test("parses verse range", function()
    local refs = bible.parse_bible_refs("John 17:18-23")
    assert_equals(6, #refs)  -- Verses 18, 19, 20, 21, 22, 23
    assert_equals("bible:john:17:18", refs[1].target)
    assert_equals("bible:john:17:19", refs[2].target)
    assert_equals("bible:john:17:20", refs[3].target)
    assert_equals("bible:john:17:23", refs[6].target)
  end)

  test("expands verse range across 10+ verses correctly", function()
    local refs = bible.parse_bible_refs("John 1:1-5")
    assert_equals(5, #refs)
    assert_equals("bible:john:1:1", refs[1].target)
    assert_equals("bible:john:1:5", refs[5].target)
  end)

  test("handles verse range with semicolon separator", function()
    local refs = bible.parse_bible_refs("John 1:1-3; Rom 8:28")
    assert_equals(4, #refs)  -- 3 verses from John, 1 from Romans
    assert_equals("bible:john:1:1", refs[1].target)
    assert_equals("bible:john:1:2", refs[2].target)
    assert_equals("bible:john:1:3", refs[3].target)
    assert_equals("bible:romans:8:28", refs[4].target)
  end)
end)

describe("Bible Reference Parsing - Multiple References", function()
  test("parses multiple references separated by semicolon", function()
    local refs = bible.parse_bible_refs("Gen 1:1; John 3:16; Rev 22:21")
    assert_equals(3, #refs)
    assert_equals("bible:genesis:1:1", refs[1].target)
    assert_equals("bible:john:3:16", refs[2].target)
    assert_equals("bible:revelation:22:21", refs[3].target)
  end)

  test("handles reference in middle of text", function()
    local refs = bible.parse_bible_refs("As it says in John 3:16, God so loved the world")
    assert_equals(1, #refs)
    assert_equals("bible:john:3:16", refs[1].target)
  end)

  test("handles multiple references in text", function()
    local refs = bible.parse_bible_refs("Compare Rom 8:28 with John 17:20 and Gen 1:1")
    assert_equals(3, #refs)
    assert_equals("bible:romans:8:28", refs[1].target)
    assert_equals("bible:john:17:20", refs[2].target)
    assert_equals("bible:genesis:1:1", refs[3].target)
  end)
end)

describe("Bible Reference Parsing - Numbered Books", function()
  test("handles 1/2/3 prefixes (1 Corinthians)", function()
    local refs = bible.parse_bible_refs("1 Cor 13:4")
    assert_equals(1, #refs)
    assert_equals("bible:1corinthians:13:4", refs[1].target)
  end)

  test("handles 1 John", function()
    local refs = bible.parse_bible_refs("1 John 4:8")
    assert_equals(1, #refs)
    assert_equals("bible:1john:4:8", refs[1].target)
  end)

  test("handles 2 Timothy", function()
    local refs = bible.parse_bible_refs("2 Tim 3:16")
    assert_equals(1, #refs)
    assert_equals("bible:2timothy:3:16", refs[1].target)
  end)
end)

describe("Bible Reference Parsing - Psalms Variations", function()
  test("handles Psalm (singular)", function()
    local refs = bible.parse_bible_refs("Psalm 23:1")
    assert_equals(1, #refs)
    assert_equals("bible:psalms:23:1", refs[1].target)
  end)

  test("handles Psalms (plural)", function()
    local refs = bible.parse_bible_refs("Psalms 23:1")
    assert_equals(1, #refs)
    assert_equals("bible:psalms:23:1", refs[1].target)
  end)

  test("handles abbreviated Psalms", function()
    local refs = bible.parse_bible_refs("Ps 23:1")
    assert_equals(1, #refs)
    assert_equals("bible:psalms:23:1", refs[1].target)
  end)
end)

describe("Bible Reference Parsing - Edge Cases", function()
  test("returns empty array for text with no references", function()
    local refs = bible.parse_bible_refs("This is just regular text without any Bible references")
    assert_equals(0, #refs)
  end)

  test("ignores invalid book names", function()
    local refs = bible.parse_bible_refs("Fake 1:1")
    assert_equals(0, #refs)
  end)
end)

-- Print summary
print(string.format("\n========================================"))
print(string.format("Tests: %d, Pass: %d, Fail: %d", test_count, pass_count, fail_count))
print(string.format("========================================\n"))

if fail_count > 0 then
  os.exit(1)
end
