local index_app = require("lifemode.app.index")
local index = require("lifemode.infra.index")
local config = require("lifemode.config")

local M = {}

local function has_sqlite()
	local ok = pcall(require, "sqlite.db")
	return ok
end

local function init_config_for_tests()
	local temp_vault = "/tmp/test_vault_index_updates_" .. os.time()
	if vim.fn.isdirectory(temp_vault) == 0 then
		vim.fn.mkdir(temp_vault, "p")
	end
	local result = config.validate_config({ vault_path = temp_vault })
	if not result.ok then
		error("Failed to init config: " .. result.error)
	end
	return temp_vault
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

function M.test_update_index_new_node()
	print("\n=== Test: update_index_for_buffer with new node ===")

	if not has_sqlite() then
		print("⊘ Skipped (requires sqlite.lua)")
		return
	end

	local vault_path = config.get("vault_path")
	local test_file = vault_path .. "/test_new_node.md"

	local content = [[---
id: aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa
created: 1111111111
---
New test node content
]]

	write_file(test_file, content)

	local bufnr = vim.fn.bufadd(test_file)
	vim.fn.bufload(bufnr)

	local result = index_app.update_index_for_buffer(bufnr)
	assert(result.ok, "update_index_for_buffer should succeed: " .. (result.error or ""))
	assert(result.value.inserted == 1, "Should insert 1 node, got: " .. result.value.inserted)
	assert(result.value.updated == 0, "Should update 0 nodes, got: " .. result.value.updated)
	assert(#result.value.errors == 0, "Should have 0 errors, got: " .. #result.value.errors)

	local find_result = index.find_by_id("aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa")
	assert(find_result.ok, "Should find node")
	assert(find_result.value ~= nil, "Node should exist in index")
	assert(find_result.value.content:match("New test node content"), "Content should match")

	vim.fn.delete(test_file)
	vim.api.nvim_buf_delete(bufnr, { force = true })

	print("✓ New node test passed")
end

function M.test_update_index_existing_node()
	print("\n=== Test: update_index_for_buffer with existing node ===")

	if not has_sqlite() then
		print("⊘ Skipped (requires sqlite.lua)")
		return
	end

	local vault_path = config.get("vault_path")
	local test_file = vault_path .. "/test_existing_node.md"

	local initial_content = [[---
id: bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb
created: 2222222222
---
Initial content
]]

	write_file(test_file, initial_content)

	local bufnr = vim.fn.bufadd(test_file)
	vim.fn.bufload(bufnr)

	local result1 = index_app.update_index_for_buffer(bufnr)
	assert(result1.ok, "First update should succeed")
	assert(result1.value.inserted == 1, "Should insert on first save")

	local updated_content = [[---
id: bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb
created: 2222222222
modified: 3333333333
---
Updated content here
]]

	write_file(test_file, updated_content)
	vim.cmd("edit! " .. test_file)

	local result2 = index_app.update_index_for_buffer(bufnr)
	assert(result2.ok, "Second update should succeed")
	assert(result2.value.inserted == 0, "Should not insert on second save, got: " .. result2.value.inserted)
	assert(result2.value.updated == 1, "Should update on second save, got: " .. result2.value.updated)

	local find_result = index.find_by_id("bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb")
	assert(find_result.ok, "Should find node")
	assert(find_result.value.content:match("Updated content here"), "Content should be updated")
	assert(find_result.value.meta.modified == 3333333333, "Modified timestamp should be updated")

	vim.fn.delete(test_file)
	vim.api.nvim_buf_delete(bufnr, { force = true })

	print("✓ Existing node test passed")
end

function M.test_update_index_multiple_nodes()
	print("\n=== Test: update_index_for_buffer with multiple nodes ===")

	if not has_sqlite() then
		print("⊘ Skipped (requires sqlite.lua)")
		return
	end

	local vault_path = config.get("vault_path")
	local test_file = vault_path .. "/test_multiple.md"

	local content = [[---
id: cccccccc-cccc-4ccc-cccc-cccccccccccc
created: 3333333333
---
First node

---
id: dddddddd-dddd-4ddd-dddd-dddddddddddd
created: 4444444444
---
Second node
]]

	write_file(test_file, content)

	local bufnr = vim.fn.bufadd(test_file)
	vim.fn.bufload(bufnr)

	local result = index_app.update_index_for_buffer(bufnr)
	assert(result.ok, "update should succeed")
	assert(result.value.inserted == 2, "Should insert 2 nodes, got: " .. result.value.inserted)

	local find1 = index.find_by_id("cccccccc-cccc-4ccc-cccc-cccccccccccc")
	assert(find1.ok and find1.value ~= nil, "Should find first node")

	local find2 = index.find_by_id("dddddddd-dddd-4ddd-dddd-dddddddddddd")
	assert(find2.ok and find2.value ~= nil, "Should find second node")

	vim.fn.delete(test_file)
	vim.api.nvim_buf_delete(bufnr, { force = true })

	print("✓ Multiple nodes test passed")
end

function M.test_update_index_invalid_node()
	print("\n=== Test: update_index_for_buffer with invalid node ===")

	if not has_sqlite() then
		print("⊘ Skipped (requires sqlite.lua)")
		return
	end

	local vault_path = config.get("vault_path")
	local test_file = vault_path .. "/test_invalid.md"

	local content = [[---
id: not-a-uuid
created: 5555555555
---
Invalid node

---
id: eeeeeeee-eeee-4eee-eeee-eeeeeeeeeeee
created: 6666666666
---
Valid node
]]

	write_file(test_file, content)

	local bufnr = vim.fn.bufadd(test_file)
	vim.fn.bufload(bufnr)

	local result = index_app.update_index_for_buffer(bufnr)
	assert(result.ok, "Should succeed overall")
	assert(result.value.inserted == 1, "Should insert 1 valid node, got: " .. result.value.inserted)
	assert(#result.value.errors == 1, "Should have 1 error, got: " .. #result.value.errors)

	local find_result = index.find_by_id("eeeeeeee-eeee-4eee-eeee-eeeeeeeeeeee")
	assert(find_result.ok and find_result.value ~= nil, "Valid node should be indexed")

	vim.fn.delete(test_file)
	vim.api.nvim_buf_delete(bufnr, { force = true })

	print("✓ Invalid node test passed")
end

function M.test_update_index_no_file_path()
	print("\n=== Test: update_index_for_buffer with no file path ===")

	if not has_sqlite() then
		print("⊘ Skipped (requires sqlite.lua)")
		return
	end

	local bufnr = vim.api.nvim_create_buf(false, true)

	local result = index_app.update_index_for_buffer(bufnr)
	assert(not result.ok, "Should fail for buffer with no file path")
	assert(result.error:match("no file path"), "Error should mention no file path")

	vim.api.nvim_buf_delete(bufnr, { force = true })

	print("✓ No file path test passed")
end

function M.test_autocommand_setup()
	print("\n=== Test: setup_autocommand ===")

	local result = index_app.setup_autocommand()
	assert(result.ok, "setup_autocommand should succeed: " .. (result.error or ""))

	local autocmds = vim.api.nvim_get_autocmds({
		group = "LifeModeIndexing",
		event = "BufWritePost",
	})

	assert(#autocmds > 0, "Should create autocommand")

	print("✓ Autocommand setup test passed")
end

function M.run_all_tests()
	print("\n" .. string.rep("=", 60))
	print("Running Index Updates Tests")
	print(string.rep("=", 60))

	init_config_for_tests()

	local tests = {
		M.test_update_index_new_node,
		M.test_update_index_existing_node,
		M.test_update_index_multiple_nodes,
		M.test_update_index_invalid_node,
		M.test_update_index_no_file_path,
		M.test_autocommand_setup,
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
