#!/usr/bin/env -S nvim -l

-- Tests for multi-file vault index
-- T18: Multi-file index (vault scan MVP)

-- Add lua directory to package path
package.path = package.path .. ';lua/?.lua;lua/?/init.lua'

local index = require('lifemode.index')

local test_count = 0
local pass_count = 0
local fail_count = 0

local function assert_equals(expected, actual, msg)
  if expected ~= actual then
    error(string.format("%s: expected %s, got %s", msg or "Assertion failed", tostring(expected), tostring(actual)))
  end
end

local function assert_true(condition, msg)
  if not condition then
    error(msg or "Expected true but got false")
  end
end

local function assert_nil(value, msg)
  if value ~= nil then
    error(msg or string.format("Expected nil, got %s", tostring(value)))
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

describe("Multi-file Index", function()
  -- Test 1: scan_vault finds all .md files
  test("scan_vault finds all .md files in vault", function()
    -- Create temp vault directory with test files
    local vault_root = "/tmp/lifemode_test_vault_" .. os.time()
    os.execute("mkdir -p " .. vault_root)
    os.execute("echo '# Test Page 1' > " .. vault_root .. "/page1.md")
    os.execute("echo '# Test Page 2' > " .. vault_root .. "/page2.md")
    os.execute("mkdir -p " .. vault_root .. "/subdir")
    os.execute("echo '# Nested Page' > " .. vault_root .. "/subdir/nested.md")

    local files = index.scan_vault(vault_root)

    -- Should find 3 markdown files
    assert_equals(3, #files, "Should find 3 markdown files")

    -- Cleanup
    os.execute("rm -rf " .. vault_root)
  end)

  -- Test 2: scan_vault returns empty array for non-existent vault
  test("scan_vault returns empty array for non-existent vault", function()
    local files = index.scan_vault("/nonexistent/vault/path")
    assert_equals(0, #files, "Should return empty array for non-existent path")
  end)

  -- Test 3: build_vault_index creates node location map
  test("build_vault_index creates node location map", function()
    local vault_root = "/tmp/lifemode_test_vault_" .. os.time()
    os.execute("mkdir -p " .. vault_root)

    -- Create file with identifiable nodes
    local file1 = vault_root .. "/tasks.md"
    local content = [[# Tasks
- [ ] Task one ^task-1
- [ ] Task two ^task-2
]]
    local f = io.open(file1, "w")
    f:write(content)
    f:close()

    local idx = index.build_vault_index(vault_root)

    -- Should have node locations
    assert_true(idx.node_locations ~= nil, "Should have node_locations")
    assert_true(idx.node_locations["task-1"] ~= nil, "Should have location for task-1")
    assert_true(idx.node_locations["task-2"] ~= nil, "Should have location for task-2")

    -- Check structure
    local loc = idx.node_locations["task-1"]
    assert_true(loc.file ~= nil, "Location should have file")
    assert_true(loc.line ~= nil, "Location should have line")

    os.execute("rm -rf " .. vault_root)
  end)

  -- Test 4: build_vault_index creates backlinks map
  test("build_vault_index creates backlinks map", function()
    local vault_root = "/tmp/lifemode_test_vault_" .. os.time()
    os.execute("mkdir -p " .. vault_root)

    -- File 1: defines a node
    local file1 = vault_root .. "/target.md"
    local f1 = io.open(file1, "w")
    f1:write("# Target Page ^target-node\n")
    f1:close()

    -- File 2: references the node
    local file2 = vault_root .. "/source.md"
    local f2 = io.open(file2, "w")
    f2:write("# Source\n- Link to [[target.md]] and [[target.md^target-node]] ^source-node\n")
    f2:close()

    local idx = index.build_vault_index(vault_root)

    -- Should have backlinks
    assert_true(idx.backlinks ~= nil, "Should have backlinks")
    assert_true(idx.backlinks["target.md"] ~= nil, "Should have backlinks for target.md")

    os.execute("rm -rf " .. vault_root)
  end)

  -- Test 5: get_node_location returns file and line
  test("get_node_location returns file and line for existing node", function()
    local vault_root = "/tmp/lifemode_test_vault_" .. os.time()
    os.execute("mkdir -p " .. vault_root)

    local file1 = vault_root .. "/test.md"
    local f = io.open(file1, "w")
    f:write("# Test\n- [ ] Task ^test-task\n")
    f:close()

    local idx = index.build_vault_index(vault_root)
    local loc = index.get_node_location(idx, "test-task")

    assert_true(loc ~= nil, "Should return location")
    assert_true(loc.file:match("test.md") ~= nil, "Should have correct file")
    assert_equals(2, loc.line, "Should have correct line")

    os.execute("rm -rf " .. vault_root)
  end)

  -- Test 6: get_node_location returns nil for non-existent node
  test("get_node_location returns nil for non-existent node", function()
    local vault_root = "/tmp/lifemode_test_vault_" .. os.time()
    os.execute("mkdir -p " .. vault_root)
    os.execute("echo '# Test' > " .. vault_root .. "/test.md")

    local idx = index.build_vault_index(vault_root)
    local loc = index.get_node_location(idx, "nonexistent-node")

    assert_nil(loc, "Should return nil for non-existent node")

    os.execute("rm -rf " .. vault_root)
  end)

  -- Test 7: get_backlinks returns array of source nodes
  test("get_backlinks returns array of source nodes", function()
    local vault_root = "/tmp/lifemode_test_vault_" .. os.time()
    os.execute("mkdir -p " .. vault_root)

    -- File with references
    local file1 = vault_root .. "/source.md"
    local f1 = io.open(file1, "w")
    f1:write("# Source\n- Link to [[Target]] ^source-1\n- Another [[Target]] ^source-2\n")
    f1:close()

    local idx = index.build_vault_index(vault_root)
    local backlinks = index.get_backlinks(idx, "Target")

    assert_true(backlinks ~= nil, "Should return backlinks array")
    assert_equals(2, #backlinks, "Should have 2 backlinks")

    os.execute("rm -rf " .. vault_root)
  end)

  -- Test 8: get_backlinks returns empty array for target with no backlinks
  test("get_backlinks returns empty array for target with no backlinks", function()
    local vault_root = "/tmp/lifemode_test_vault_" .. os.time()
    os.execute("mkdir -p " .. vault_root)
    os.execute("echo '# Test' > " .. vault_root .. "/test.md")

    local idx = index.build_vault_index(vault_root)
    local backlinks = index.get_backlinks(idx, "NonExistent")

    assert_true(backlinks ~= nil, "Should return array")
    assert_equals(0, #backlinks, "Should be empty array")

    os.execute("rm -rf " .. vault_root)
  end)

  -- Test 9: Index includes Bible verse references
  test("build_vault_index includes Bible verse backlinks", function()
    local vault_root = "/tmp/lifemode_test_vault_" .. os.time()
    os.execute("mkdir -p " .. vault_root)

    local file1 = vault_root .. "/sermon.md"
    local f1 = io.open(file1, "w")
    f1:write("# Sermon Notes\n- Key verse: John 3:16 ^note-1\n")
    f1:close()

    local idx = index.build_vault_index(vault_root)

    -- Should have backlinks for Bible verse
    assert_true(idx.backlinks["bible:john:3:16"] ~= nil, "Should have backlinks for Bible verse")

    os.execute("rm -rf " .. vault_root)
  end)

  -- Test 10: scan_vault ignores non-markdown files
  test("scan_vault ignores non-markdown files", function()
    local vault_root = "/tmp/lifemode_test_vault_" .. os.time()
    os.execute("mkdir -p " .. vault_root)
    os.execute("echo 'test' > " .. vault_root .. "/file.txt")
    os.execute("echo 'test' > " .. vault_root .. "/file.pdf")
    os.execute("echo '# Test' > " .. vault_root .. "/valid.md")

    local files = index.scan_vault(vault_root)

    assert_equals(1, #files, "Should only find markdown files")

    os.execute("rm -rf " .. vault_root)
  end)

  -- Test 11: rebuild_index refreshes the index
  test("rebuild_index refreshes the vault index", function()
    local vault_root = "/tmp/lifemode_test_vault_" .. os.time()
    os.execute("mkdir -p " .. vault_root)
    os.execute("echo '# Test' > " .. vault_root .. "/test.md")

    -- Build initial index
    local idx1 = index.build_vault_index(vault_root)
    local count1 = 0
    for _ in pairs(idx1.node_locations) do count1 = count1 + 1 end

    -- Add more content
    local f = io.open(vault_root .. "/test2.md", "w")
    f:write("# Test 2\n- [ ] Task ^new-task\n")
    f:close()

    -- Rebuild index
    local idx2 = index.build_vault_index(vault_root)
    local count2 = 0
    for _ in pairs(idx2.node_locations) do count2 = count2 + 1 end

    -- New index should have more nodes
    assert_true(count2 > count1, "Rebuilt index should have more nodes")

    os.execute("rm -rf " .. vault_root)
  end)
end)

-- Print summary
print(string.format("\n%s", string.rep("=", 50)))
print(string.format("Tests: %d | Pass: %d | Fail: %d", test_count, pass_count, fail_count))
print(string.rep("=", 50))

-- Exit with appropriate code
if fail_count > 0 then
  os.exit(1)
else
  os.exit(0)
end
