local util = require("lifemode.util")
local config = require("lifemode.config")
local index = require("lifemode.infra.index")
local sqlite_adapter = require("lifemode.infra.index.sqlite")
local schema = require("lifemode.infra.index.schema")
local fs_read = require("lifemode.infra.fs.read")
local domain_node = require("lifemode.domain.node")
local types = require("lifemode.domain.types")

local M = {}

local function parse_frontmatter(lines)
	local meta = {}

	for _, line in ipairs(lines) do
		local key, value = line:match("^([%w_]+):%s*(.+)$")
		if key and value then
			value = value:gsub("^%s+", ""):gsub("%s+$", "")

			if key == "created" or key == "modified" then
				meta[key] = tonumber(value)
			else
				meta[key] = value
			end
		end
	end

	return meta
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
					start_line = frontmatter_start,
					end_line = node_end,
					frontmatter_start = frontmatter_start,
					frontmatter_end = frontmatter_end,
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

function M.parse_file_for_nodes(file_path)
	if not file_path or file_path == "" then
		return util.Err("parse_file_for_nodes: file_path is required")
	end

	local read_result = fs_read.read(file_path)
	if not read_result.ok then
		return util.Err("parse_file_for_nodes: " .. read_result.error)
	end

	local content = read_result.value
	local lines = {}
	for line in content:gmatch("([^\n]*)\n?") do
		table.insert(lines, line)
	end

	local boundaries = find_node_boundaries(lines)
	local nodes = {}

	for _, boundary in ipairs(boundaries) do
		local frontmatter_lines = {}
		for i = boundary.frontmatter_start + 1, boundary.frontmatter_end - 1 do
			table.insert(frontmatter_lines, lines[i])
		end

		local meta = parse_frontmatter(frontmatter_lines)

		if not meta.id or not meta.created then
			goto continue
		end

		local content_lines = {}
		for i = boundary.frontmatter_end + 1, boundary.end_line do
			table.insert(content_lines, lines[i])
		end
		local node_content = table.concat(content_lines, "\n")

		local node_result = types.Node_new(node_content, meta)

		if node_result.ok then
			table.insert(nodes, { node = node_result.value, file_path = file_path })
		end

		::continue::
	end

	return util.Ok(nodes)
end

function M.find_markdown_files(vault_path)
	if not vault_path or vault_path == "" then
		return util.Err("find_markdown_files: vault_path is required")
	end

	if vim.fn.isdirectory(vault_path) == 0 then
		return util.Err("find_markdown_files: directory not found: " .. vault_path)
	end

	local pattern = vault_path .. "/**/*.md"
	local files = vim.fn.glob(pattern, false, true)

	local filtered = {}
	for _, file in ipairs(files) do
		local is_hidden = file:match("/%.[^/]+/")
		local is_lifemode_dir = file:match("/.lifemode/")

		if not is_hidden or is_lifemode_dir then
			table.insert(filtered, file)
		end
	end

	return util.Ok(filtered)
end

function M.clear_index(vault_path)
	vault_path = vault_path or config.get("vault_path")
	local db_dir = vault_path .. "/.lifemode"
	local db_path = db_dir .. "/index.sqlite"

	if vim.fn.isdirectory(db_dir) == 0 then
		local mkdir_ok, mkdir_err = pcall(function()
			vim.fn.mkdir(db_dir, "p")
		end)
		if not mkdir_ok then
			return util.Err("clear_index: failed to create directory: " .. tostring(mkdir_err))
		end
	end

	local init_result = schema.init_db(db_path)
	if not init_result.ok then
		return util.Err("clear_index: " .. init_result.error)
	end

	local db = init_result.value

	local delete_edges_result = sqlite_adapter.exec(db, "DELETE FROM edges")
	if not delete_edges_result.ok then
		sqlite_adapter.close(db)
		return util.Err("clear_index: failed to clear edges: " .. delete_edges_result.error)
	end

	local delete_nodes_result = sqlite_adapter.exec(db, "DELETE FROM nodes")
	sqlite_adapter.close(db)

	if not delete_nodes_result.ok then
		return util.Err("clear_index: failed to clear nodes: " .. delete_nodes_result.error)
	end

	return util.Ok(nil)
end

function M.rebuild_index(vault_path)
	vault_path = vault_path or config.get("vault_path")

	if not vault_path or vault_path == "" then
		return util.Err("rebuild_index: vault_path is required")
	end

	local stats = {
		scanned = 0,
		indexed = 0,
		errors = {},
	}

	local clear_result = M.clear_index(vault_path)
	if not clear_result.ok then
		return util.Err("rebuild_index: " .. clear_result.error)
	end

	local files_result = M.find_markdown_files(vault_path)
	if not files_result.ok then
		return util.Err("rebuild_index: " .. files_result.error)
	end

	local files = files_result.value
	local total_files = #files

	for i, file_path in ipairs(files) do
		stats.scanned = stats.scanned + 1

		local parse_result = M.parse_file_for_nodes(file_path)

		if not parse_result.ok then
			table.insert(stats.errors, file_path .. ": " .. parse_result.error)
			goto next_file
		end

		local parsed_nodes = parse_result.value

		for _, node_data in ipairs(parsed_nodes) do
			local insert_result = index.insert_node(node_data.node, node_data.file_path)

			if insert_result.ok then
				stats.indexed = stats.indexed + 1
			else
				table.insert(
					stats.errors,
					file_path .. " (node " .. node_data.node.id .. "): " .. insert_result.error
				)
			end
		end

		if i % 10 == 0 then
			vim.schedule(function()
				vim.notify(
					string.format(
						"[LifeMode] Rebuilding index: %d/%d files, %d nodes",
						i,
						total_files,
						stats.indexed
					),
					vim.log.levels.INFO
				)
			end)
		end

		::next_file::
	end

	return util.Ok(stats)
end

return M
