local util = require("lifemode.util")
local extmark = require("lifemode.infra.nvim.extmark")
local buf = require("lifemode.infra.nvim.buf")

local M = {}

local function extract_title(lines)
	local in_frontmatter = false
	local frontmatter_closed = false

	for _, line in ipairs(lines) do
		if line:match("^%-%-%-%s*$") then
			if not in_frontmatter then
				in_frontmatter = true
			elseif in_frontmatter and not frontmatter_closed then
				frontmatter_closed = true
			end
		elseif frontmatter_closed and line ~= "" then
			local heading = line:match("^#+%s+(.+)$")
			if heading then
				return heading
			elseif #line > 50 then
				return line:sub(1, 47) .. "..."
			else
				return line
			end
		end
	end

	return "Untitled"
end

function M.narrow_to_current()
	local source_bufnr = vim.api.nvim_get_current_buf()

	if not vim.api.nvim_buf_is_valid(source_bufnr) then
		return util.Err("narrow_to_current: current buffer is not valid")
	end

	local node_result = extmark.get_node_at_cursor()

	if not node_result.ok then
		return util.Err("narrow_to_current: " .. node_result.error)
	end

	local node_data = node_result.value
	local node_uuid = node_data.uuid
	local node_start = node_data.start
	local node_end = node_data["end"]

	local cursor = vim.api.nvim_win_get_cursor(0)

	local node_lines = buf.get_lines(source_bufnr, node_start, node_end + 1)

	local title = extract_title(node_lines)

	local scratch_bufnr = vim.api.nvim_create_buf(false, true)

	if not vim.api.nvim_buf_is_valid(scratch_bufnr) then
		return util.Err("narrow_to_current: failed to create scratch buffer")
	end

	vim.api.nvim_buf_set_name(scratch_bufnr, "*Narrow: " .. title .. "*")

	local set_result = buf.set_lines(scratch_bufnr, 0, -1, node_lines)
	if not set_result.ok then
		return util.Err("narrow_to_current: " .. set_result.error)
	end

	vim.b[scratch_bufnr].lifemode_narrow = {
		source_file = vim.api.nvim_buf_get_name(source_bufnr),
		source_bufnr = source_bufnr,
		source_uuid = node_uuid,
		source_range = { start = node_start, ["end"] = node_end },
		original_cursor = { line = cursor[1], col = cursor[2] },
	}

	vim.bo[scratch_bufnr].buftype = "nofile"
	vim.bo[scratch_bufnr].bufhidden = "hide"
	vim.bo[scratch_bufnr].swapfile = false
	vim.bo[scratch_bufnr].buflisted = false

	vim.api.nvim_set_current_buf(scratch_bufnr)

	vim.wo.statusline = "[NARROW: " .. title .. "]"

	local ns = vim.api.nvim_create_namespace("lifemode_narrow_hint")
	vim.api.nvim_buf_set_extmark(scratch_bufnr, ns, 0, 0, {
		virt_text = { { "↑ Context hidden. <leader>nw to widen", "Comment" } },
		virt_text_pos = "overlay",
	})

	vim.api.nvim_win_set_cursor(0, { 1, 0 })

	return util.Ok(nil)
end

return M
