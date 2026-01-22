-- Manual integration test for jump_context functionality
-- Run with: nvim -u NONE -c "source tests/manual_test_jump_context.lua"

vim.opt.runtimepath:append(".")

local narrow = require("lifemode.app.narrow")
local parse_buffer = require("lifemode.app.parse_buffer")
local buf = require("lifemode.infra.nvim.buf")

local function test(name, fn)
	local status, err = pcall(fn)
	if status then
		print("✓ " .. name)
	else
		print("✗ " .. name)
		print("  Error: " .. tostring(err))
	end
end

print("\n=== Running Jump Context Module Tests ===\n")

test("jump_context: jump from narrow to context", function()
	local uuid = "a1b2c3d4-e5f6-4789-a012-bcdef1234567"

	local temp_file = "/tmp/test_jump_narrow_to_context.md"
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

	local jump_result = narrow.jump_context()
	assert(jump_result.ok, "jump should succeed: " .. tostring(jump_result.error))

	assert(vim.api.nvim_get_current_buf() == source_bufnr, "should be in source buffer")

	local cursor = vim.api.nvim_win_get_cursor(0)
	assert(cursor[1] == 1, "cursor should be at node start (line 1)")

	assert(vim.b[source_bufnr].lifemode_jump_from == narrow_bufnr, "jump history should be set")

	vim.api.nvim_buf_delete(source_bufnr, { force = true })
	vim.api.nvim_buf_delete(narrow_bufnr, { force = true })
end)

test("jump_context: jump from context back to narrow", function()
	local uuid = "11111111-2222-4333-a444-555555555555"

	local temp_file = "/tmp/test_jump_context_to_narrow.md"
	local f = io.open(temp_file, "w")
	f:write(string.format([[---
id: %s
created: 1234567890
---
Content.
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

	narrow.jump_context()

	local jump_back_result = narrow.jump_context()
	assert(jump_back_result.ok, "jump back should succeed")

	local current = vim.api.nvim_get_current_buf()
	assert(current == narrow_bufnr, "should be back in narrow buffer")

	assert(vim.b[source_bufnr].lifemode_jump_from == nil, "jump history should be cleared")

	vim.api.nvim_buf_delete(source_bufnr, { force = true })
	vim.api.nvim_buf_delete(narrow_bufnr, { force = true })
end)

test("jump_context: error when not in context", function()
	local normal_bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(normal_bufnr)

	local result = narrow.jump_context()
	assert(not result.ok, "should fail when no context")
	assert(result.error:match("not in narrow"), "error should mention context")

	vim.api.nvim_buf_delete(normal_bufnr, { force = true })
end)

test("jump_context: highlighting applied", function()
	local uuid = "22222222-3333-4444-a555-666666666666"

	local temp_file = "/tmp/test_jump_highlight.md"
	local f = io.open(temp_file, "w")
	f:write(string.format([[---
id: %s
created: 1234567890
---
Content line 1.
Content line 2.
]], uuid))
	f:close()

	local open_result = buf.open(temp_file)
	assert(open_result.ok)
	local source_bufnr = open_result.value

	parse_buffer.parse_and_mark_buffer(source_bufnr)
	vim.api.nvim_set_current_buf(source_bufnr)
	vim.api.nvim_win_set_cursor(0, { 4, 0 })

	narrow.narrow_to_current()
	narrow.jump_context()

	local ns = vim.api.nvim_create_namespace("lifemode_jump_highlight")
	local extmarks = vim.api.nvim_buf_get_extmarks(source_bufnr, ns, 0, -1, {})
	assert(#extmarks > 0, "highlight extmark should exist")

	vim.wait(2100, function() return false end)

	local extmarks_after = vim.api.nvim_buf_get_extmarks(source_bufnr, ns, 0, -1, {})
	assert(#extmarks_after == 0, "highlight should be cleared after timeout")

	vim.api.nvim_buf_delete(source_bufnr, { force = true })
end)

test("jump_context: handle closed narrow buffer", function()
	local uuid = "33333333-4444-4555-a666-777777777777"

	local temp_file = "/tmp/test_jump_closed_narrow.md"
	local f = io.open(temp_file, "w")
	f:write(string.format([[---
id: %s
created: 1234567890
---
Content.
]], uuid))
	f:close()

	local open_result = buf.open(temp_file)
	assert(open_result.ok)
	local source_bufnr = open_result.value

	parse_buffer.parse_and_mark_buffer(source_bufnr)
	vim.api.nvim_set_current_buf(source_bufnr)
	vim.api.nvim_win_set_cursor(0, { 4, 0 })

	narrow.narrow_to_current()
	narrow.jump_context()

	local narrow_bufnr = vim.b[source_bufnr].lifemode_jump_from

	vim.api.nvim_buf_delete(narrow_bufnr, { force = true })

	local result = narrow.jump_context()
	assert(not result.ok, "should fail when narrow buffer closed")
	assert(result.error:match("no longer valid"), "error should mention buffer validity")

	vim.api.nvim_buf_delete(source_bufnr, { force = true })
end)

print("\n=== All tests completed ===\n")
vim.cmd("qa!")
