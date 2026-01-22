local builder = require("lifemode.infra.index.builder")
local index = require("lifemode.infra.index")
local config = require("lifemode.config")

local M = {}

local function has_sqlite()
	local ok = pcall(require, "sqlite.db")
	return ok
end

local function init_config_for_tests()
	local temp_vault = "/tmp/test_vault_config_" .. os.time()
	if vim.fn.isdirectory(temp_vault) == 0 then
		vim.fn.mkdir(temp_vault, "p")
	end
	local result = config.validate_config({ vault_path = temp_vault })
	if not result.ok then
		error("Failed to init config: " .. result.error)
	end
end

local function cleanup_test_vault(path)
	if vim.fn.isdirectory(path) == 1 then
		vim.fn.delete(path, "rf")
	end
end

local function create_test_vault(path)
	cleanup_test_vault(path)
	vim.fn.mkdir(path, "p")
end

local function write_file(path, content)
	local dir = vim.fn.fnamemodify(path, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end
	local f = io.open(path, "w")
	if not f then
		error("Failed to open file for writing: " .. path)
	end
	f:write(content)
	f:close()
end

function M.test_find_markdown_files_empty()
	print("\n=== Test: find_markdown_files with empty vault ===")
	local temp_vault = "/tmp/test_vault_empty_" .. os.time()
	create_test_vault(temp_vault)

	local result = builder.find_markdown_files(temp_vault)
	assert(result.ok, "find_markdown_files should succeed: " .. (result.error or ""))
	assert(#result.value == 0, "Should find no files in empty vault")

	cleanup_test_vault(temp_vault)
	print("✓ Empty vault test passed")
end

function M.test_find_markdown_files_with_files()
	print("\n=== Test: find_markdown_files with files ===")
	local temp_vault = "/tmp/test_vault_find_" .. os.time()
	create_test_vault(temp_vault)

	write_file(temp_vault .. "/file1.md", "# Test 1")
	write_file(temp_vault .. "/subdir/file2.md", "# Test 2")
	write_file(temp_vault .. "/subdir/deep/file3.md", "# Test 3")
	write_file(temp_vault .. "/README.txt", "Not markdown")

	local result = builder.find_markdown_files(temp_vault)
	assert(result.ok, "find_markdown_files should succeed: " .. (result.error or ""))
	assert(#result.value == 3, "Should find 3 markdown files, got: " .. #result.value)

	cleanup_test_vault(temp_vault)
	print("✓ Find files test passed")
end

function M.test_find_markdown_files_filters_hidden()
	print("\n=== Test: find_markdown_files filters hidden dirs ===")
	local temp_vault = "/tmp/test_vault_hidden_" .. os.time()
	create_test_vault(temp_vault)

	write_file(temp_vault .. "/visible.md", "# Visible")
	write_file(temp_vault .. "/.hidden/secret.md", "# Hidden")

	local result = builder.find_markdown_files(temp_vault)
	assert(result.ok, "find_markdown_files should succeed: " .. (result.error or ""))
	assert(#result.value >= 1, "Should find at least visible.md, got: " .. #result.value)

	local has_hidden = false
	for _, path in ipairs(result.value) do
		if path:match("/.hidden/") then
			has_hidden = true
			break
		end
	end
	assert(not has_hidden, "Should not include files in hidden directories")

	cleanup_test_vault(temp_vault)
	print("✓ Hidden dir filter test passed")
end

function M.test_parse_file_single_node()
	print("\n=== Test: parse_file_for_nodes with single node ===")
	local temp_vault = "/tmp/test_vault_parse_" .. os.time()
	create_test_vault(temp_vault)

	local test_file = temp_vault .. "/test.md"
	write_file(
		test_file,
		[[---
id: a1b2c3d4-e5f6-4789-a012-bcdef1234567
created: 1234567890
modified: 1234567900
---
Test content here
More lines
]]
	)

	local result = builder.parse_file_for_nodes(test_file)
	assert(result.ok, "parse_file_for_nodes should succeed: " .. (result.error or ""))
	assert(#result.value == 1, "Should find 1 node, got: " .. #result.value)

	local node_data = result.value[1]
	assert(node_data.node.id == "a1b2c3d4-e5f6-4789-a012-bcdef1234567", "Node ID should match")
	assert(node_data.node.meta.created == 1234567890, "Created timestamp should match")
	assert(node_data.node.meta.modified == 1234567900, "Modified timestamp should match")
	assert(node_data.file_path == test_file, "File path should match")

	cleanup_test_vault(temp_vault)
	print("✓ Parse single node test passed")
end

function M.test_parse_file_multiple_nodes()
	print("\n=== Test: parse_file_for_nodes with multiple nodes ===")
	local temp_vault = "/tmp/test_vault_multi_" .. os.time()
	create_test_vault(temp_vault)

	local test_file = temp_vault .. "/multi.md"
	write_file(
		test_file,
		[[---
id: 11111111-1111-4111-a111-111111111111
created: 1111111111
---
First node content

---
id: 22222222-2222-4222-a222-222222222222
created: 2222222222
---
Second node content

---
id: 33333333-3333-4333-a333-333333333333
created: 3333333333
---
Third node content
]]
	)

	local result = builder.parse_file_for_nodes(test_file)
	assert(result.ok, "parse_file_for_nodes should succeed: " .. (result.error or ""))
	assert(#result.value == 3, "Should find 3 nodes, got: " .. #result.value)

	cleanup_test_vault(temp_vault)
	print("✓ Parse multiple nodes test passed")
end

function M.test_parse_file_invalid_frontmatter()
	print("\n=== Test: parse_file_for_nodes with invalid frontmatter ===")
	local temp_vault = "/tmp/test_vault_invalid_" .. os.time()
	create_test_vault(temp_vault)

	local test_file = temp_vault .. "/invalid.md"
	write_file(
		test_file,
		[[---
id: not-a-uuid
created: 1234567890
---
Invalid node (bad UUID)

---
id: a1b2c3d4-e5f6-4789-a012-bcdef1234567
---
Missing created field

---
id: b1b2c3d4-e5f6-4789-a012-bcdef1234567
created: 9999999999
---
Valid node
]]
	)

	local result = builder.parse_file_for_nodes(test_file)
	assert(result.ok, "parse_file_for_nodes should succeed: " .. (result.error or ""))
	assert(
		#result.value == 1,
		"Should find 1 valid node (skip invalid), got: " .. #result.value
	)
	assert(result.value[1].node.id == "b1b2c3d4-e5f6-4789-a012-bcdef1234567", "Should be the valid node")

	cleanup_test_vault(temp_vault)
	print("✓ Invalid frontmatter test passed")
end

function M.test_rebuild_index_empty_vault()
	print("\n=== Test: rebuild_index with empty vault ===")

	if not has_sqlite() then
		print("⊘ Skipped (requires sqlite.lua)")
		return
	end

	local vault_path = config.get("vault_path")

	local existing_files_result = builder.find_markdown_files(vault_path)
	if not existing_files_result.ok or #existing_files_result.value > 0 then
		print("⊘ Skipped (vault not empty)")
		return
	end

	local result = builder.rebuild_index()
	assert(result.ok, "rebuild_index should succeed: " .. (result.error or ""))
	assert(result.value.scanned == 0, "Should scan 0 files, got: " .. result.value.scanned)
	assert(result.value.indexed == 0, "Should index 0 nodes, got: " .. result.value.indexed)
	assert(#result.value.errors == 0, "Should have 0 errors, got: " .. #result.value.errors)

	print("✓ Rebuild empty vault test passed")
end

function M.test_rebuild_index_with_nodes()
	print("\n=== Test: rebuild_index with nodes ===")

	if not has_sqlite() then
		print("⊘ Skipped (requires sqlite.lua)")
		return
	end

	local vault_path = config.get("vault_path")

	write_file(
		vault_path .. "/test_file1.md",
		[[---
id: aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa
created: 1111111111
---
Content 1
]]
	)

	write_file(
		vault_path .. "/test_file2.md",
		[[---
id: bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb
created: 2222222222
---
Content 2
]]
	)

	local result = builder.rebuild_index()
	assert(result.ok, "rebuild_index should succeed: " .. (result.error or ""))
	assert(result.value.scanned >= 2, "Should scan at least 2 files, got: " .. result.value.scanned)
	assert(result.value.indexed >= 2, "Should index at least 2 nodes, got: " .. result.value.indexed)

	local find_result1 = index.find_by_id("aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa")
	assert(find_result1.ok, "Should find node 1: " .. (find_result1.error or ""))
	assert(find_result1.value ~= nil, "Node 1 should exist in index")

	local find_result2 = index.find_by_id("bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb")
	assert(find_result2.ok, "Should find node 2: " .. (find_result2.error or ""))
	assert(find_result2.value ~= nil, "Node 2 should exist in index")

	vim.fn.delete(vault_path .. "/test_file1.md")
	vim.fn.delete(vault_path .. "/test_file2.md")
	print("✓ Rebuild with nodes test passed")
end

function M.test_clear_index()
	print("\n=== Test: clear_index ===")

	if not has_sqlite() then
		print("⊘ Skipped (requires sqlite.lua)")
		return
	end

	local vault_path = config.get("vault_path")

	write_file(
		vault_path .. "/test_clear.md",
		[[---
id: cccccccc-cccc-4ccc-cccc-cccccccccccc
created: 3333333333
---
Test content
]]
	)

	local rebuild_result = builder.rebuild_index()
	assert(rebuild_result.ok, "rebuild_index should succeed")
	assert(rebuild_result.value.indexed >= 1, "Should have indexed at least 1 node")

	local clear_result = builder.clear_index()
	assert(clear_result.ok, "clear_index should succeed: " .. (clear_result.error or ""))

	local find_result = index.find_by_id("cccccccc-cccc-4ccc-cccc-cccccccccccc")
	assert(find_result.ok, "find_by_id should succeed")
	assert(find_result.value == nil, "Index should be empty after clear")

	vim.fn.delete(vault_path .. "/test_clear.md")
	print("✓ Clear index test passed")
end

function M.run_all_tests()
	print("\n" .. string.rep("=", 60))
	print("Running Index Builder Tests")
	print(string.rep("=", 60))

	init_config_for_tests()

	local tests = {
		M.test_find_markdown_files_empty,
		M.test_find_markdown_files_with_files,
		M.test_find_markdown_files_filters_hidden,
		M.test_parse_file_single_node,
		M.test_parse_file_multiple_nodes,
		M.test_parse_file_invalid_frontmatter,
		M.test_rebuild_index_empty_vault,
		M.test_rebuild_index_with_nodes,
		M.test_clear_index,
	}

	local passed = 0
	local failed = 0

	for _, test_fn in ipairs(tests) do
		local ok, err = pcall(test_fn)
		if ok then
			passed = passed + 1
		else
			failed = failed + 1
			print("\n✗ TEST FAILED: " .. err)
		end
	end

	print("\n" .. string.rep("=", 60))
	print(string.format("Results: %d passed, %d failed", passed, failed))
	print(string.rep("=", 60))

	if failed > 0 then
		error("Some tests failed")
	end
end

return M
