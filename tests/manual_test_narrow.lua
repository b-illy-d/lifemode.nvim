-- Manual integration test for narrow module
-- Run with: nvim -u NONE -c "source tests/manual_test_narrow.lua"

vim.opt.runtimepath:append(".")

local narrow = require("lifemode.app.narrow")
local parse_buffer = require("lifemode.app.parse_buffer")
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

print("\n=== Running Narrow Module Tests ===\n")

test("narrow_to_current: single node", function()
	local uuid = "a1b2c3d4-e5f6-4789-a012-bcdef1234567"
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"---",
		"id: " .. uuid,
		"created: 1234567890",
		"---",
		"# Test Node",
		"Content here.",
	})

	local parse_result = parse_buffer.parse_and_mark_buffer(bufnr)
	assert(parse_result.ok, "parse should succeed")

	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_win_set_cursor(0, { 5, 0 })

	local result = narrow.narrow_to_current()
	assert(result.ok, "narrow should succeed")

	local narrow_bufnr = vim.api.nvim_get_current_buf()
	assert(narrow_bufnr ~= bufnr, "should be in new buffer")

	local buf_name = vim.api.nvim_buf_get_name(narrow_bufnr)
	assert(buf_name:match("*Narrow:"), "buffer name should contain *Narrow:")
	assert(buf_name:match("Test Node"), "buffer name should contain node title")

	local lines = vim.api.nvim_buf_get_lines(narrow_bufnr, 0, -1, false)
	assert(#lines == 6, "should have all node lines")

	assert(vim.bo[narrow_bufnr].buftype == "nofile", "buftype should be nofile")
	assert(vim.bo[narrow_bufnr].swapfile == false, "swapfile should be false")

	assert(vim.b[narrow_bufnr].lifemode_narrow ~= nil, "narrow context should exist")
	assert(vim.b[narrow_bufnr].lifemode_narrow.source_uuid == uuid, "uuid should match")

	vim.api.nvim_buf_delete(bufnr, { force = true })
	vim.api.nvim_buf_delete(narrow_bufnr, { force = true })
end)

test("narrow_to_current: multiple nodes, narrow to second", function()
	local uuid1 = "11111111-2222-4333-a444-555555555555"
	local uuid2 = "66666666-7777-4888-a999-aaaaaaaaaaaa"
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"---",
		"id: " .. uuid1,
		"created: 1234567890",
		"---",
		"First node.",
		"",
		"---",
		"id: " .. uuid2,
		"created: 1234567890",
		"---",
		"# Second Node",
		"Second content.",
	})

	parse_buffer.parse_and_mark_buffer(bufnr)

	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_win_set_cursor(0, { 11, 0 })

	local result = narrow.narrow_to_current()
	assert(result.ok, "narrow should succeed")

	local narrow_bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(narrow_bufnr, 0, -1, false)

	assert(#lines == 6, "should have second node lines only")

	local has_first = false
	for _, line in ipairs(lines) do
		if line:match("First node") then
			has_first = true
		end
	end
	assert(not has_first, "should not contain first node content")

	local has_second = false
	for _, line in ipairs(lines) do
		if line:match("Second") then
			has_second = true
		end
	end
	assert(has_second, "should contain second node content")

	assert(vim.b[narrow_bufnr].lifemode_narrow.source_uuid == uuid2, "uuid should be uuid2")

	vim.api.nvim_buf_delete(bufnr, { force = true })
	vim.api.nvim_buf_delete(narrow_bufnr, { force = true })
end)

test("narrow_to_current: error when not on node", function()
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"Just text",
		"No nodes here",
	})

	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })

	local result = narrow.narrow_to_current()
	assert(not result.ok, "narrow should fail when not on node")
	assert(result.error:match("not within any node") or result.error:match("no extmark"), "error should mention node")

	vim.api.nvim_buf_delete(bufnr, { force = true })
end)

test("narrow_to_current: extract title from heading", function()
	local uuid = "aaaaaaaa-bbbb-4ccc-addd-eeeeeeeeeeee"
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"---",
		"id: " .. uuid,
		"created: 1234567890",
		"---",
		"## My Awesome Heading",
		"Some content.",
	})

	parse_buffer.parse_and_mark_buffer(bufnr)
	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_win_set_cursor(0, { 5, 0 })

	narrow.narrow_to_current()

	local narrow_bufnr = vim.api.nvim_get_current_buf()
	local buf_name = vim.api.nvim_buf_get_name(narrow_bufnr)

	assert(buf_name:match("My Awesome Heading"), "should extract heading as title")

	vim.api.nvim_buf_delete(bufnr, { force = true })
	vim.api.nvim_buf_delete(narrow_bufnr, { force = true })
end)

test("narrow_to_current: fallback to Untitled when no content", function()
	local uuid = "ffffffff-0000-4111-a222-333333333333"
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"---",
		"id: " .. uuid,
		"created: 1234567890",
		"---",
		"",
	})

	local parse_result = parse_buffer.parse_and_mark_buffer(bufnr)
	assert(parse_result.ok, "parse should succeed: " .. tostring(parse_result.error or ""))

	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })

	local narrow_result = narrow.narrow_to_current()
	assert(narrow_result.ok, "narrow should succeed: " .. tostring(narrow_result.error or ""))

	local narrow_bufnr = vim.api.nvim_get_current_buf()
	local buf_name = vim.api.nvim_buf_get_name(narrow_bufnr)

	assert(buf_name:match("Untitled"), "should use Untitled as fallback")

	vim.api.nvim_buf_delete(bufnr, { force = true })
	vim.api.nvim_buf_delete(narrow_bufnr, { force = true })
end)

test("narrow_to_current: statusline set correctly", function()
	local uuid = "12345678-1234-4567-a890-123456789012"
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"---",
		"id: " .. uuid,
		"created: 1234567890",
		"---",
		"# Status Test",
		"Content.",
	})

	parse_buffer.parse_and_mark_buffer(bufnr)
	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_win_set_cursor(0, { 5, 0 })

	narrow.narrow_to_current()

	local statusline = vim.wo.statusline
	assert(statusline:match("NARROW"), "statusline should contain NARROW")
	assert(statusline:match("Status Test"), "statusline should contain node title")

	local narrow_bufnr = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_delete(bufnr, { force = true })
	vim.api.nvim_buf_delete(narrow_bufnr, { force = true })
end)

test("narrow_to_current: virtual text hint added", function()
	local uuid = "abcdef01-2345-4678-a901-234567890123"
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"---",
		"id: " .. uuid,
		"created: 1234567890",
		"---",
		"# Hint Test",
		"Content.",
	})

	parse_buffer.parse_and_mark_buffer(bufnr)
	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_win_set_cursor(0, { 5, 0 })

	narrow.narrow_to_current()

	local narrow_bufnr = vim.api.nvim_get_current_buf()

	local ns = vim.api.nvim_create_namespace("lifemode_narrow_hint")
	local extmarks = vim.api.nvim_buf_get_extmarks(narrow_bufnr, ns, 0, -1, { details = true })

	assert(#extmarks > 0, "should have extmark for hint")

	local has_hint = false
	for _, mark in ipairs(extmarks) do
		local opts = mark[4]
		if opts and opts.virt_text then
			for _, vt in ipairs(opts.virt_text) do
				if vt[1]:match("Context hidden") then
					has_hint = true
				end
			end
		end
	end

	assert(has_hint, "should have virtual text hint")

	vim.api.nvim_buf_delete(bufnr, { force = true })
	vim.api.nvim_buf_delete(narrow_bufnr, { force = true })
end)

print("\n=== All tests completed ===\n")
vim.cmd("qa!")
