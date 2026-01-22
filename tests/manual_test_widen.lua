-- Manual integration test for widen functionality
-- Run with: nvim -u NONE -c "source tests/manual_test_widen.lua"

vim.opt.runtimepath:append(".")

local narrow = require("lifemode.app.narrow")
local parse_buffer = require("lifemode.app.parse_buffer")
local util = require("lifemode.util")
local buf = require("lifemode.infra.nvim.buf")
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

print("\n=== Running Widen Module Tests ===\n")

test("widen: sync content changes back to source", function()
	local uuid = "a1b2c3d4-e5f6-4789-a012-bcdef1234567"

	local temp_file = "/tmp/test_widen_source.md"
	local f = io.open(temp_file, "w")
	f:write(string.format([[---
id: %s
created: 1234567890
---
Original content.
More original.
]], uuid))
	f:close()

	local open_result = buf.open(temp_file)
	assert(open_result.ok, "should open temp file")
	local source_bufnr = open_result.value

	parse_buffer.parse_and_mark_buffer(source_bufnr)
	vim.api.nvim_set_current_buf(source_bufnr)
	vim.api.nvim_win_set_cursor(0, { 5, 0 })

	local narrow_result = narrow.narrow_to_current()
	assert(narrow_result.ok, "narrow should succeed: " .. tostring(narrow_result.error))

	local narrow_bufnr = vim.api.nvim_get_current_buf()

	vim.api.nvim_buf_set_lines(narrow_bufnr, 4, 5, false, { "Modified content." })

	local widen_result = narrow.widen()
	assert(widen_result.ok, "widen should succeed: " .. tostring(widen_result.error))

	local current_bufnr = vim.api.nvim_get_current_buf()
	assert(current_bufnr == source_bufnr, "should be back in source buffer")

	local source_lines = vim.api.nvim_buf_get_lines(source_bufnr, 0, -1, false)
	assert(source_lines[5] == "Modified content.", "source content should be updated")

	assert(not vim.api.nvim_buf_is_valid(narrow_bufnr), "narrow buffer should be deleted")

	vim.api.nvim_buf_delete(source_bufnr, { force = true })
end)

test("widen: update extmark when node size increases", function()
	local uuid = "11111111-2222-4333-a444-555555555555"
	local source_bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(source_bufnr, 0, -1, false, {
		"---",
		"id: " .. uuid,
		"created: 1234567890",
		"---",
		"Original.",
	})

	vim.api.nvim_buf_set_name(source_bufnr, "/tmp/test_widen_grow.md")

	parse_buffer.parse_and_mark_buffer(source_bufnr)
	vim.api.nvim_set_current_buf(source_bufnr)
	vim.api.nvim_win_set_cursor(0, { 4, 0 })

	narrow.narrow_to_current()

	local narrow_bufnr = vim.api.nvim_get_current_buf()

	vim.api.nvim_buf_set_lines(narrow_bufnr, -1, -1, false, {
		"New line 1.",
		"New line 2.",
	})

	narrow.widen()

	local query_result = extmark.query(source_bufnr, 0)
	assert(query_result.ok, "extmark should exist after widen")
	assert(query_result.value.node_end == 6, "node_end should be 6 (was 4, added 2 lines)")

	vim.api.nvim_buf_delete(source_bufnr, { force = true })
end)

test("widen: update extmark when node size decreases", function()
	local uuid = "66666666-7777-4888-a999-aaaaaaaaaaaa"
	local source_bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(source_bufnr, 0, -1, false, {
		"---",
		"id: " .. uuid,
		"created: 1234567890",
		"---",
		"Line 1.",
		"Line 2.",
		"Line 3.",
	})

	vim.api.nvim_buf_set_name(source_bufnr, "/tmp/test_widen_shrink.md")

	parse_buffer.parse_and_mark_buffer(source_bufnr)
	vim.api.nvim_set_current_buf(source_bufnr)
	vim.api.nvim_win_set_cursor(0, { 5, 0 })

	narrow.narrow_to_current()

	local narrow_bufnr = vim.api.nvim_get_current_buf()

	vim.api.nvim_buf_set_lines(narrow_bufnr, 5, 6, false, {})

	narrow.widen()

	local query_result = extmark.query(source_bufnr, 0)
	assert(query_result.ok, "extmark should exist after widen")
	assert(query_result.value.node_end == 5, "node_end should be 5 (was 6, removed 1 line)")

	vim.api.nvim_buf_delete(source_bufnr, { force = true })
end)

test("widen: error when not in narrow view", function()
	local normal_bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(normal_bufnr)

	local result = narrow.widen()
	assert(not result.ok, "should fail when not in narrow view")
	assert(result.error:match("not in narrow"), "error should mention narrow")

	vim.api.nvim_buf_delete(normal_bufnr, { force = true })
end)

test("widen: content modified but size unchanged", function()
	local uuid = "aaaaaaaa-bbbb-4ccc-addd-eeeeeeeeeeee"

	local temp_file = "/tmp/test_widen_same.md"
	local f = io.open(temp_file, "w")
	f:write(string.format([[---
id: %s
created: 1234567890
---
Content line.
]], uuid))
	f:close()

	local open_result = buf.open(temp_file)
	assert(open_result.ok)
	local source_bufnr = open_result.value

	parse_buffer.parse_and_mark_buffer(source_bufnr)

	vim.api.nvim_set_current_buf(source_bufnr)
	vim.api.nvim_win_set_cursor(0, { 4, 0 })

	narrow.narrow_to_current()
	local narrow_bufnr = vim.api.nvim_get_current_buf()

	vim.api.nvim_buf_set_lines(narrow_bufnr, 4, 5, false, { "Modified but same size." })

	local widen_result = narrow.widen()
	assert(widen_result.ok, "widen should succeed")

	local source_lines = vim.api.nvim_buf_get_lines(source_bufnr, 0, -1, false)
	assert(source_lines[5] == "Modified but same size.", "content should be updated")

	local query_after = extmark.query(source_bufnr, 0)
	assert(query_after.ok, "extmark should still exist")
	assert(query_after.value.node_end == 4, "node_end should be 4")

	vim.api.nvim_buf_delete(source_bufnr, { force = true })
end)

test("widen: cursor restored to node start", function()
	local uuid = "ffffffff-0000-4111-a222-333333333333"
	local source_bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(source_bufnr, 0, -1, false, {
		"---",
		"id: " .. uuid,
		"created: 1234567890",
		"---",
		"Content.",
	})

	vim.api.nvim_buf_set_name(source_bufnr, "/tmp/test_widen_cursor.md")

	parse_buffer.parse_and_mark_buffer(source_bufnr)
	vim.api.nvim_set_current_buf(source_bufnr)
	vim.api.nvim_win_set_cursor(0, { 4, 0 })

	narrow.narrow_to_current()
	narrow.widen()

	local cursor = vim.api.nvim_win_get_cursor(0)
	assert(cursor[1] == 1, "cursor should be at line 1 (node_start + 1)")

	vim.api.nvim_buf_delete(source_bufnr, { force = true })
end)

print("\n=== All tests completed ===\n")
vim.cmd("qa!")
