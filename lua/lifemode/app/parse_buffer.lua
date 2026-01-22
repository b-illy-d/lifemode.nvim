local util = require("lifemode.util")
local node = require("lifemode.domain.node")
local buf = require("lifemode.infra.nvim.buf")
local extmark = require("lifemode.infra.nvim.extmark")

local M = {}

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

function M.parse_and_mark_buffer(bufnr)
	if type(bufnr) ~= "number" then
		return util.Err("parse_and_mark_buffer: bufnr must be a number")
	end

	if not vim.api.nvim_buf_is_valid(bufnr) then
		return util.Err("parse_and_mark_buffer: buffer is not valid")
	end

	local lines = buf.get_lines(bufnr, 0, -1)

	if #lines == 0 then
		return util.Ok({})
	end

	local boundaries = find_node_boundaries(lines)

	if #boundaries == 0 then
		return util.Ok({})
	end

	local nodes = {}

	for _, boundary in ipairs(boundaries) do
		local node_lines = {}
		for i = boundary.start_line + 1, boundary.end_line + 1 do
			table.insert(node_lines, lines[i])
		end

		local node_text = table.concat(node_lines, "\n")

		local parse_result = node.parse(node_text)

		if parse_result.ok then
			local parsed_node = parse_result.value

			local extmark_result = extmark.set(bufnr, boundary.start_line, {
				node_id = parsed_node.id,
				node_start = boundary.start_line,
				node_end = boundary.end_line,
			})

			if extmark_result.ok then
				table.insert(nodes, parsed_node)
			else
				vim.notify(
					"[LifeMode] WARN: Failed to create extmark for node " .. parsed_node.id .. ": " .. extmark_result.error,
					vim.log.levels.WARN
				)
			end
		else
			vim.notify(
				"[LifeMode] WARN: Failed to parse node at line "
					.. (boundary.start_line + 1)
					.. ": "
					.. parse_result.error,
				vim.log.levels.WARN
			)
		end
	end

	return util.Ok(nodes)
end

function M.setup_autocommand()
	local group = vim.api.nvim_create_augroup("LifeModeParsing", { clear = true })

	vim.api.nvim_create_autocmd("BufReadPost", {
		group = group,
		pattern = "*.md",
		callback = function(args)
			vim.schedule(function()
				local result = M.parse_and_mark_buffer(args.buf)
				if not result.ok then
					vim.notify("[LifeMode] ERROR: Failed to parse buffer: " .. result.error, vim.log.levels.ERROR)
				end
			end)
		end,
	})

	return util.Ok(nil)
end

return M
