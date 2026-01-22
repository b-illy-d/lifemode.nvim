local util = require("lifemode.util")
local index = require("lifemode.infra.index")
local node = require("lifemode.domain.node")
local buf = require("lifemode.infra.nvim.buf")

local M = {}

local _last_update = {}

local function get_buffer_file_path(bufnr)
	local file_path = vim.api.nvim_buf_get_name(bufnr)

	if not file_path or file_path == "" then
		return util.Err("get_buffer_file_path: buffer has no file path")
	end

	return util.Ok(file_path)
end

local function debounce_update(bufnr)
	local now = vim.loop.now()
	local last = _last_update[bufnr] or 0

	if now - last < 500 then
		return true
	end

	_last_update[bufnr] = now
	return false
end

local function find_node_boundaries(lines)
	local boundaries = {}
	local i = 1

	while i <= #lines do
		local line = lines[i]

		if line:match("^%-%-%-%s*$") then
			local frontmatter_start = i

			local frontmatter_end = nil
			for j = i + 1, #lines do
				if lines[j]:match("^%-%-%-%s*$") then
					frontmatter_end = j
					break
				end
			end

			if frontmatter_end then
				local next_node_start = nil
				for j = frontmatter_end + 1, #lines do
					if lines[j]:match("^%-%-%-%s*$") then
						next_node_start = j
						break
					end
				end

				local node_end
				if next_node_start then
					node_end = next_node_start - 1
				else
					node_end = #lines
				end

				table.insert(boundaries, {
					start_line = frontmatter_start - 1,
					end_line = node_end - 1,
				})

				i = frontmatter_end + 1
			else
				i = i + 1
			end
		else
			i = i + 1
		end
	end

	return boundaries
end

function M.update_index_for_buffer(bufnr)
	if type(bufnr) ~= "number" then
		return util.Err("update_index_for_buffer: bufnr must be a number")
	end

	if not vim.api.nvim_buf_is_valid(bufnr) then
		return util.Err("update_index_for_buffer: buffer is not valid")
	end

	local file_path_result = get_buffer_file_path(bufnr)
	if not file_path_result.ok then
		return util.Err("update_index_for_buffer: " .. file_path_result.error)
	end

	local file_path = file_path_result.value

	local lines = buf.get_lines(bufnr, 0, -1)

	if #lines == 0 then
		return util.Ok({ inserted = 0, updated = 0, errors = {} })
	end

	local boundaries = find_node_boundaries(lines)

	if #boundaries == 0 then
		return util.Ok({ inserted = 0, updated = 0, errors = {} })
	end

	local stats = {
		inserted = 0,
		updated = 0,
		errors = {},
	}

	for _, boundary in ipairs(boundaries) do
		local node_lines = {}
		for i = boundary.start_line + 1, boundary.end_line + 1 do
			table.insert(node_lines, lines[i])
		end

		local node_text = table.concat(node_lines, "\n")

		local parse_result = node.parse(node_text)

		if not parse_result.ok then
			table.insert(stats.errors, "Line " .. (boundary.start_line + 1) .. ": " .. parse_result.error)
			goto continue
		end

		local parsed_node = parse_result.value

		local insert_result = index.insert_node(parsed_node, file_path)

		if insert_result.ok then
			stats.inserted = stats.inserted + 1
		else
			if insert_result.error:match("already exists") then
				local update_result = index.update_node(parsed_node, file_path)

				if update_result.ok then
					stats.updated = stats.updated + 1
				else
					table.insert(stats.errors, "Node " .. parsed_node.id .. ": " .. update_result.error)
				end
			else
				table.insert(stats.errors, "Node " .. parsed_node.id .. ": " .. insert_result.error)
			end
		end

		::continue::
	end

	return util.Ok(stats)
end

function M.update_index_for_buffer_async(bufnr)
	vim.schedule(function()
		local result = M.update_index_for_buffer(bufnr)

		if not result.ok then
			vim.notify("[LifeMode] ERROR: Failed to update index: " .. result.error, vim.log.levels.ERROR)
			return
		end

		local stats = result.value

		if #stats.errors > 0 then
			local error_summary = string.format(
				"[LifeMode] Index update completed with %d errors:",
				#stats.errors
			)

			local errors_to_show = math.min(3, #stats.errors)
			for i = 1, errors_to_show do
				error_summary = error_summary .. "\n  - " .. stats.errors[i]
			end

			if #stats.errors > 3 then
				error_summary = error_summary .. string.format("\n  ... and %d more errors", #stats.errors - 3)
			end

			vim.notify(error_summary, vim.log.levels.WARN)
		end
	end)
end

function M.setup_autocommand()
	local group = vim.api.nvim_create_augroup("LifeModeIndexing", { clear = true })

	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		pattern = "*.md",
		callback = function(args)
			if debounce_update(args.buf) then
				return
			end

			M.update_index_for_buffer_async(args.buf)
		end,
	})

	return util.Ok(nil)
end

return M
