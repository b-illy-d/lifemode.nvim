-- Manual integration test for extmark module
-- Run with: nvim -u NONE -c "source tests/manual_test_extmark.lua"

vim.opt.runtimepath:append(".")

local extmark = require("lifemode.infra.nvim.extmark")

local function test(name, fn)
	local status, err = pcall(fn)
	if status then
		print("✓ " .. name)
	else
		print("✗ " .. name)
		print("  Error: " .. tostring(err))
	end
end

print("\n=== Running Extmark Module Tests ===\n")

test("set: creates extmark with metadata", function()
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line 0", "line 1", "line 2" })

	local result = extmark.set(bufnr, 1, {
		node_id = "test-uuid-123",
		node_start = 1,
		node_end = 3,
	})

	assert(result.ok, "Result should be ok")
	assert(type(result.value) == "number", "Should return extmark ID as number")

	vim.api.nvim_buf_delete(bufnr, { force = true })
end)

test("query: retrieves metadata from extmark", function()
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line 0", "line 1", "line 2" })

	local set_result = extmark.set(bufnr, 1, {
		node_id = "query-test-uuid",
		node_start = 1,
		node_end = 3,
	})

	assert(set_result.ok)

	local query_result = extmark.query(bufnr, 1)

	assert(query_result.ok, "Query should succeed")
	assert(query_result.value.node_id == "query-test-uuid", "node_id should match")
	assert(query_result.value.node_start == 1, "node_start should match")
	assert(query_result.value.node_end == 3, "node_end should match")
	assert(type(query_result.value.extmark_id) == "number", "extmark_id should be number")

	vim.api.nvim_buf_delete(bufnr, { force = true })
end)

test("query: fails when no extmark at line", function()
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line 0", "line 1", "line 2" })

	local query_result = extmark.query(bufnr, 1)

	assert(not query_result.ok, "Query should fail when no extmark exists")
	assert(query_result.error:match("no extmark found"), "Error message should mention no extmark found")

	vim.api.nvim_buf_delete(bufnr, { force = true })
end)

test("delete: removes extmark by ID", function()
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line 0", "line 1", "line 2" })

	local set_result = extmark.set(bufnr, 1, {
		node_id = "delete-test-uuid",
		node_start = 1,
		node_end = 3,
	})

	assert(set_result.ok)
	local extmark_id = set_result.value

	local delete_result = extmark.delete(bufnr, extmark_id)

	assert(delete_result.ok, "Delete should succeed")

	local query_result = extmark.query(bufnr, 1)
	assert(not query_result.ok, "Query should fail after delete")

	vim.api.nvim_buf_delete(bufnr, { force = true })
end)

test("get_node_at_cursor: finds node at cursor position", function()
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line 0", "line 1", "line 2", "line 3", "line 4" })

	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_win_set_cursor(0, { 3, 0 })

	local set_result = extmark.set(bufnr, 2, {
		node_id = "cursor-test-uuid",
		node_start = 2,
		node_end = 4,
	})

	assert(set_result.ok)

	local cursor_result = extmark.get_node_at_cursor()

	assert(cursor_result.ok, "get_node_at_cursor should succeed")
	assert(cursor_result.value.uuid == "cursor-test-uuid", "uuid should match")
	assert(cursor_result.value.start == 2, "start should match")
	assert(cursor_result.value["end"] == 4, "end should match")

	vim.api.nvim_buf_delete(bufnr, { force = true })
end)

test("get_node_at_cursor: fails when cursor not on extmark", function()
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line 0", "line 1", "line 2" })

	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })

	local result = extmark.get_node_at_cursor()

	assert(not result.ok, "Should fail when no extmark at cursor")
	assert(result.error:match("no extmark found"), "Error should mention no extmark found")

	vim.api.nvim_buf_delete(bufnr, { force = true })
end)

test("set: validates input types", function()
	local bufnr = vim.api.nvim_create_buf(false, true)

	local result1 = extmark.set("not a number", 1, {
		node_id = "test",
		node_start = 1,
		node_end = 3,
	})
	assert(not result1.ok, "Should fail with invalid bufnr")
	assert(result1.error:match("bufnr must be a number"), "Error should mention bufnr")

	local result2 = extmark.set(bufnr, "not a number", {
		node_id = "test",
		node_start = 1,
		node_end = 3,
	})
	assert(not result2.ok, "Should fail with invalid line")
	assert(result2.error:match("line must be a number"), "Error should mention line")

	local result3 = extmark.set(bufnr, 1, {
		node_start = 1,
		node_end = 3,
	})
	assert(not result3.ok, "Should fail with missing node_id")
	assert(result3.error:match("node_id"), "Error should mention node_id")

	vim.api.nvim_buf_delete(bufnr, { force = true })
end)

print("\n=== All tests completed ===\n")
vim.cmd("qa!")
