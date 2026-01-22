-- Manual integration test for parse_buffer module
-- Run with: nvim -u NONE -c "source tests/manual_test_parse_buffer.lua"

vim.opt.runtimepath:append(".")

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

print("\n=== Running Parse Buffer Module Tests ===\n")

test("parse_and_mark_buffer: single node", function()
	local bufnr = vim.api.nvim_create_buf(false, true)
	local uuid1 = "a1b2c3d4-e5f6-4789-a012-bcdef1234567"
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"---",
		"id: " .. uuid1,
		"created: 1234567890",
		"---",
		"This is node content.",
		"More content here.",
	})

	local result = parse_buffer.parse_and_mark_buffer(bufnr)

	assert(result.ok, "parse should succeed")
	assert(#result.value == 1, "should find 1 node")
	assert(result.value[1].id == uuid1, "node id should match")

	local query = extmark.query(bufnr, 0)
	assert(query.ok, "extmark should exist at line 0")
	assert(query.value.node_id == uuid1, "extmark node_id should match")
	assert(query.value.node_start == 0, "node_start should be 0")
	assert(query.value.node_end == 5, "node_end should be 5")

	vim.api.nvim_buf_delete(bufnr, { force = true })
end)

test("parse_and_mark_buffer: multiple nodes", function()
	local bufnr = vim.api.nvim_create_buf(false, true)
	local uuid1 = "11111111-2222-4333-a444-555555555555"
	local uuid2 = "66666666-7777-4888-a999-aaaaaaaaaaaa"
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"---",
		"id: " .. uuid1,
		"created: 1234567890",
		"---",
		"First node content.",
		"",
		"---",
		"id: " .. uuid2,
		"created: 1234567890",
		"---",
		"Second node content.",
	})

	local result = parse_buffer.parse_and_mark_buffer(bufnr)

	assert(result.ok, "parse should succeed")
	assert(#result.value == 2, "should find 2 nodes")
	assert(result.value[1].id == uuid1, "first node id should match")
	assert(result.value[2].id == uuid2, "second node id should match")

	local query1 = extmark.query(bufnr, 0)
	assert(query1.ok, "first extmark should exist")
	assert(query1.value.node_id == uuid1, "first extmark node_id should match")

	local query2 = extmark.query(bufnr, 6)
	assert(query2.ok, "second extmark should exist")
	assert(query2.value.node_id == uuid2, "second extmark node_id should match")

	vim.api.nvim_buf_delete(bufnr, { force = true })
end)

test("parse_and_mark_buffer: empty buffer", function()
	local bufnr = vim.api.nvim_create_buf(false, true)

	local result = parse_buffer.parse_and_mark_buffer(bufnr)

	assert(result.ok, "parse should succeed on empty buffer")
	assert(#result.value == 0, "should find 0 nodes")

	vim.api.nvim_buf_delete(bufnr, { force = true })
end)

test("parse_and_mark_buffer: no frontmatter", function()
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"Just some markdown",
		"With no frontmatter",
	})

	local result = parse_buffer.parse_and_mark_buffer(bufnr)

	assert(result.ok, "parse should succeed")
	assert(#result.value == 0, "should find 0 nodes")

	vim.api.nvim_buf_delete(bufnr, { force = true })
end)

test("parse_and_mark_buffer: malformed node (continues)", function()
	local bufnr = vim.api.nvim_create_buf(false, true)
	local uuid1 = "aaaaaaaa-bbbb-4ccc-addd-eeeeeeeeeeee"
	local uuid2 = "ffffffff-0000-4111-a222-333333333333"
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"---",
		"id: " .. uuid1,
		"created: 1234567890",
		"---",
		"Good content.",
		"",
		"---",
		"missing: id",
		"created: 1234567890",
		"---",
		"Bad node (no id).",
		"",
		"---",
		"id: " .. uuid2,
		"created: 1234567890",
		"---",
		"More good content.",
	})

	vim.api.nvim_create_user_command("TestNotify", function()
	end, {})

	local warnings = {}
	local old_notify = vim.notify
	vim.notify = function(msg, level)
		table.insert(warnings, { msg = msg, level = level })
	end

	local result = parse_buffer.parse_and_mark_buffer(bufnr)

	vim.notify = old_notify

	assert(result.ok, "parse should succeed despite malformed node")
	assert(#result.value == 2, "should find 2 good nodes")
	assert(result.value[1].id == uuid1, "first node should match uuid1")
	assert(result.value[2].id == uuid2, "second node should match uuid2")

	assert(#warnings > 0, "should have warnings")
	local found_warning = false
	for _, w in ipairs(warnings) do
		if w.msg:match("Failed to parse") then
			found_warning = true
			break
		end
	end
	assert(found_warning, "should warn about failed parse")

	vim.api.nvim_buf_delete(bufnr, { force = true })
end)

test("parse_and_mark_buffer: validates input", function()
	local result1 = parse_buffer.parse_and_mark_buffer("not a number")
	assert(not result1.ok, "should fail with invalid bufnr")
	assert(result1.error:match("bufnr must be a number"), "error should mention bufnr")

	local result2 = parse_buffer.parse_and_mark_buffer(9999)
	assert(not result2.ok, "should fail with invalid buffer")
	assert(result2.error:match("buffer is not valid"), "error should mention invalid buffer")
end)

test("setup_autocommand: registers autocmd", function()
	local result = parse_buffer.setup_autocommand()

	assert(result.ok, "setup should succeed")

	local autocmds = vim.api.nvim_get_autocmds({
		group = "LifeModeParsing",
		event = "BufReadPost",
	})

	assert(#autocmds > 0, "autocommand should be registered")
	assert(autocmds[1].pattern == "*.md", "pattern should be *.md")

	vim.api.nvim_del_augroup_by_name("LifeModeParsing")
end)

print("\n=== All tests completed ===\n")
vim.cmd("qa!")
