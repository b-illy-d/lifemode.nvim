local util = require("lifemode.util")
local domain_transclude = require("lifemode.domain.transclude")
local index = require("lifemode.infra.index")

local M = {}

local ns = nil

local function get_namespace()
	if not ns then
		ns = vim.api.nvim_create_namespace("lifemode_transclusions")
	end
	return ns
end

local function define_highlight_groups()
	vim.api.nvim_set_hl(0, "LifeModeTransclusion", { bg = "#2a2a2a" })
	vim.api.nvim_set_hl(0, "LifeModeTransclusionSign", { fg = "#6c6c6c" })
	vim.api.nvim_set_hl(0, "LifeModeTransclusionError", { bg = "#3a1a1a", fg = "#ff6666" })
	vim.api.nvim_set_hl(0, "LifeModeTransclusionVirtual", { fg = "#4a4a4a" })
end

local function is_error_content(content)
	return content:match("⚠️") ~= nil
end

local function position_from_offset(lines, offset)
	local pos = 0
	for i, line in ipairs(lines) do
		if pos + #line >= offset - 1 then
			return i - 1, (offset - 1) - pos
		end
		pos = pos + #line + 1
	end
	return 0, 0
end

local function create_transclusion_extmark(bufnr, line, col, token, expanded_content)
	local ns_id = get_namespace()

	local is_error = is_error_content(expanded_content)
	local hl_group = is_error and "LifeModeTransclusionError" or "LifeModeTransclusion"
	local sign_hl = is_error and "LifeModeTransclusionError" or "LifeModeTransclusionSign"

	local virt_text_content = "▼ " .. expanded_content
	if #virt_text_content > 80 then
		virt_text_content = virt_text_content:sub(1, 77) .. "..."
	end

	local opts = {
		virt_text = { { virt_text_content, "LifeModeTransclusionVirtual" } },
		virt_text_pos = "inline",
		hl_mode = "combine",
		sign_text = "»",
		sign_hl_group = sign_hl,
	}

	if token.end_pos - token.start_pos >= 0 then
		opts.end_col = col + (token.end_pos - token.start_pos + 1)
		opts.conceal = ""
	end

	local success, result = pcall(function()
		return vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, col, opts)
	end)

	if not success then
		return util.Err("create_transclusion_extmark: " .. tostring(result))
	end

	return util.Ok(result)
end

function M.render_transclusions(bufnr)
	if type(bufnr) ~= "number" then
		return util.Err("render_transclusions: bufnr must be number")
	end

	if not vim.api.nvim_buf_is_valid(bufnr) then
		return util.Err("render_transclusions: buffer not valid")
	end

	define_highlight_groups()

	local success, lines = pcall(function()
		return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	end)

	if not success then
		return util.Err("render_transclusions: failed to get buffer lines: " .. tostring(lines))
	end

	local content = table.concat(lines, "\n")

	local tokens = domain_transclude.parse(content)

	local fetch_fn = function(uuid)
		return index.find_by_id(uuid)
	end

	for _, token in ipairs(tokens) do
		local token_text = content:sub(token.start_pos, token.end_pos)

		local expand_result = domain_transclude.expand(token_text, {}, 0, 10, fetch_fn)

		local expanded_content
		if expand_result.ok then
			expanded_content = expand_result.value
		else
			expanded_content = "⚠️ Error: " .. expand_result.error
		end

		local line_num, col_offset = position_from_offset(lines, token.start_pos)

		local mark_result = create_transclusion_extmark(bufnr, line_num, col_offset, token, expanded_content)
		if not mark_result.ok then
			vim.notify("[LifeMode] " .. mark_result.error, vim.log.levels.WARN)
		end
	end

	local windows = vim.fn.win_findbuf(bufnr)
	for _, winid in ipairs(windows) do
		local set_opt_ok, set_opt_err = pcall(function()
			vim.api.nvim_set_option_value("conceallevel", 2, { win = winid })
		end)

		if not set_opt_ok then
			return util.Err("render_transclusions: failed to set conceallevel: " .. tostring(set_opt_err))
		end
	end

	return util.Ok(nil)
end

function M.setup_autocommands()
	vim.api.nvim_create_autocmd("BufEnter", {
		pattern = "*.md",
		group = vim.api.nvim_create_augroup("lifemode_transclusions", { clear = true }),
		callback = function(args)
			vim.schedule(function()
				local result = M.render_transclusions(args.buf)
				if not result.ok then
					vim.notify("[LifeMode] Failed to render transclusions: " .. result.error, vim.log.levels.WARN)
				end
			end)
		end,
	})
end

return M
