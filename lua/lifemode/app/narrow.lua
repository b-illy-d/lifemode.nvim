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

function M.widen()
	local narrow_bufnr = vim.api.nvim_get_current_buf()

	if not vim.api.nvim_buf_is_valid(narrow_bufnr) then
		return util.Err("widen: current buffer is not valid")
	end

	local narrow_context = vim.b[narrow_bufnr].lifemode_narrow

	if not narrow_context then
		return util.Err("widen: not in narrow view")
	end

	local source_file = narrow_context.source_file
	local source_bufnr = narrow_context.source_bufnr
	local node_uuid = narrow_context.source_uuid
	local original_start = narrow_context.source_range.start
	local original_end = narrow_context.source_range["end"]

	local narrow_lines = buf.get_lines(narrow_bufnr, 0, -1)

	if not vim.api.nvim_buf_is_valid(source_bufnr) then
		local open_result = buf.open(source_file)
		if not open_result.ok then
			return util.Err("widen: failed to open source file: " .. open_result.error)
		end
		source_bufnr = open_result.value
	end

	vim.bo[source_bufnr].buftype = ""

	local set_result = buf.set_lines(source_bufnr, original_start, original_end + 1, narrow_lines)
	if not set_result.ok then
		return util.Err("widen: failed to update source buffer: " .. set_result.error)
	end

	local new_node_end = original_start + #narrow_lines - 1

	local query_result = extmark.query(source_bufnr, original_start)

	if query_result.ok then
		local extmark_id = query_result.value.extmark_id

		local delete_result = extmark.delete(source_bufnr, extmark_id)
		if not delete_result.ok then
			vim.notify(
				"[LifeMode] WARN: Failed to delete old extmark: " .. delete_result.error,
				vim.log.levels.WARN
			)
		end
	end

	local set_extmark_result = extmark.set(source_bufnr, original_start, {
		node_id = node_uuid,
		node_start = original_start,
		node_end = new_node_end,
	})

	if not set_extmark_result.ok then
		vim.notify(
			"[LifeMode] WARN: Failed to create updated extmark: " .. set_extmark_result.error,
			vim.log.levels.WARN
		)
	end

	local write_success, write_err = pcall(function()
		vim.api.nvim_buf_call(source_bufnr, function()
			vim.cmd.write()
		end)
	end)

	if not write_success then
		return util.Err("widen: failed to write source file: " .. tostring(write_err))
	end

	vim.api.nvim_set_current_buf(source_bufnr)

	vim.api.nvim_buf_delete(narrow_bufnr, { force = true })

	vim.api.nvim_win_set_cursor(0, { original_start + 1, 0 })

	vim.notify("[LifeMode] Saved", vim.log.levels.INFO)

	return util.Ok(nil)
end

function M.jump_context()
	local current_bufnr = vim.api.nvim_get_current_buf()

	if not vim.api.nvim_buf_is_valid(current_bufnr) then
		return util.Err("jump_context: current buffer is not valid")
	end

	local narrow_context = vim.b[current_bufnr].lifemode_narrow

	if narrow_context then
		local source_bufnr = narrow_context.source_bufnr
		local node_start = narrow_context.source_range.start
		local node_end = narrow_context.source_range["end"]

		if not vim.api.nvim_buf_is_valid(source_bufnr) then
			return util.Err("jump_context: source buffer no longer valid")
		end

		vim.api.nvim_set_current_buf(source_bufnr)

		vim.api.nvim_win_set_cursor(0, { node_start + 1, 0 })

		local ns = vim.api.nvim_create_namespace("lifemode_jump_highlight")

		vim.api.nvim_buf_set_extmark(source_bufnr, ns, node_start, 0, {
			end_row = node_end + 1,
			hl_group = "LifeModeNarrowContext",
			hl_eol = true,
		})

		vim.defer_fn(function()
			if vim.api.nvim_buf_is_valid(source_bufnr) then
				vim.api.nvim_buf_clear_namespace(source_bufnr, ns, 0, -1)
			end
		end, 2000)

		vim.b[source_bufnr].lifemode_jump_from = current_bufnr

		return util.Ok(nil)
	end

	local jump_from = vim.b[current_bufnr].lifemode_jump_from

	if jump_from then
		if not vim.api.nvim_buf_is_valid(jump_from) then
			return util.Err("jump_context: narrow buffer no longer valid")
		end

		vim.api.nvim_set_current_buf(jump_from)

		vim.b[current_bufnr].lifemode_jump_from = nil

		vim.api.nvim_win_set_cursor(0, { 1, 0 })

		return util.Ok(nil)
	end

	return util.Err("jump_context: not in narrow view or source with narrow history")
end

return M
