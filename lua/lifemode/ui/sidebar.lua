local util = require("lifemode.util")
local index = require("lifemode.infra.index")
local extmark = require("lifemode.infra.nvim.extmark")
local config = require("lifemode.config")
local adapter = require("lifemode.infra.index.sqlite")
local schema = require("lifemode.infra.index.schema")

local M = {}

local sidebar_state = {
	winnr = nil,
	bufnr = nil,
	current_uuid = nil,
}

local function is_sidebar_open()
	if sidebar_state.winnr and vim.api.nvim_win_is_valid(sidebar_state.winnr) then
		return true
	end
	sidebar_state.winnr = nil
	sidebar_state.bufnr = nil
	sidebar_state.current_uuid = nil
	return false
end

local function get_db()
	local vault_path = config.get("vault_path")
	local db_path = vault_path .. "/.lifemode/index.sqlite"
	return schema.init_db(db_path)
end

local function query_file_paths(uuids)
	if #uuids == 0 then
		return util.Ok({})
	end

	local db_result = get_db()
	if not db_result.ok then
		return util.Err("query_file_paths: " .. db_result.error)
	end

	local db = db_result.value
	local placeholders = {}
	for _ = 1, #uuids do
		table.insert(placeholders, "?")
	end

	local query_sql = string.format(
		"SELECT uuid, file_path FROM nodes WHERE uuid IN (%s)",
		table.concat(placeholders, ", ")
	)

	local query_result = adapter.query(db, query_sql, uuids)
	adapter.close(db)

	if not query_result.ok then
		return util.Err("query_file_paths: " .. query_result.error)
	end

	local uuid_to_path = {}
	for _, row in ipairs(query_result.value) do
		uuid_to_path[row.uuid] = row.file_path
	end

	return util.Ok(uuid_to_path)
end

function M.create_sidebar_window()
	local width = math.floor(vim.o.columns * 0.3)
	local height = vim.o.lines - 2
	local col = math.floor(vim.o.columns * 0.7)
	local row = 0

	local bufnr = vim.api.nvim_create_buf(false, true)

	if bufnr == 0 then
		return util.Err("create_sidebar_window: failed to create buffer")
	end

	vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
	vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
	vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(bufnr, "filetype", "markdown")

	local win_config = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
		title = " LifeMode ",
		title_pos = "center",
	}

	local success, winnr = pcall(vim.api.nvim_open_win, bufnr, false, win_config)

	if not success then
		return util.Err("create_sidebar_window: failed to open window: " .. tostring(winnr))
	end

	vim.api.nvim_win_set_option(winnr, "wrap", false)
	vim.api.nvim_win_set_option(winnr, "cursorline", true)
	vim.api.nvim_win_set_option(winnr, "number", false)
	vim.api.nvim_win_set_option(winnr, "relativenumber", false)

	vim.api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "", {
		noremap = true,
		silent = true,
		callback = function()
			M.jump_to_node()
		end,
	})

	vim.api.nvim_buf_set_keymap(bufnr, "n", "q", "", {
		noremap = true,
		silent = true,
		callback = function()
			M.toggle_sidebar()
		end,
	})

	return util.Ok({
		bufnr = bufnr,
		winnr = winnr,
	})
end

function M.render_sidebar(uuid)
	if not uuid or type(uuid) ~= "string" then
		return util.Err("render_sidebar: uuid is required and must be a string")
	end

	if not is_sidebar_open() then
		local create_result = M.create_sidebar_window()
		if not create_result.ok then
			return util.Err("render_sidebar: " .. create_result.error)
		end
		sidebar_state.bufnr = create_result.value.bufnr
		sidebar_state.winnr = create_result.value.winnr
	end

	local node_result = index.find_by_id(uuid)
	if not node_result.ok then
		return util.Err("render_sidebar: " .. node_result.error)
	end

	if not node_result.value then
		return util.Err("render_sidebar: node not found: " .. uuid)
	end

	local backlinks_result = index.find_edges(uuid, "in", nil)
	if not backlinks_result.ok then
		return util.Err("render_sidebar: failed to query backlinks: " .. backlinks_result.error)
	end

	local outgoing_result = index.find_edges(uuid, "out", nil)
	if not outgoing_result.ok then
		return util.Err("render_sidebar: failed to query outgoing: " .. outgoing_result.error)
	end

	local backlinks = backlinks_result.value
	local outgoing = outgoing_result.value

	local all_uuids = {}
	for _, edge in ipairs(backlinks) do
		table.insert(all_uuids, edge.from)
	end
	for _, edge in ipairs(outgoing) do
		table.insert(all_uuids, edge.to)
	end

	local paths_result = query_file_paths(all_uuids)
	if not paths_result.ok then
		return util.Err("render_sidebar: " .. paths_result.error)
	end

	local uuid_to_path = paths_result.value

	local lines = {}
	local line_to_uuid = {}

	table.insert(lines, "# Relations")
	table.insert(lines, "")
	table.insert(lines, "## Backlinks (" .. #backlinks .. ")")

	if #backlinks == 0 then
		table.insert(lines, "")
		table.insert(lines, "(none)")
	else
		for _, edge in ipairs(backlinks) do
			local file_path = uuid_to_path[edge.from]
			if file_path then
				local relative_path = vim.fn.fnamemodify(file_path, ":~:.")
				table.insert(lines, "")
				table.insert(lines, "- " .. relative_path)
				line_to_uuid[#lines] = edge.from
			end
		end
	end

	table.insert(lines, "")
	table.insert(lines, "## Outgoing (" .. #outgoing .. ")")

	if #outgoing == 0 then
		table.insert(lines, "")
		table.insert(lines, "(none)")
	else
		for _, edge in ipairs(outgoing) do
			local file_path = uuid_to_path[edge.to]
			if file_path then
				local relative_path = vim.fn.fnamemodify(file_path, ":~:.")
				table.insert(lines, "")
				table.insert(lines, "- " .. relative_path)
				line_to_uuid[#lines] = edge.to
			end
		end
	end

	vim.api.nvim_buf_set_option(sidebar_state.bufnr, "modifiable", true)
	vim.api.nvim_buf_set_lines(sidebar_state.bufnr, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(sidebar_state.bufnr, "modifiable", false)

	vim.b[sidebar_state.bufnr].lifemode_sidebar_links = line_to_uuid
	vim.b[sidebar_state.bufnr].lifemode_sidebar_uuid_to_path = uuid_to_path
	sidebar_state.current_uuid = uuid

	return util.Ok(nil)
end

function M.jump_to_node()
	if not is_sidebar_open() then
		return util.Err("jump_to_node: sidebar is not open")
	end

	local cursor = vim.api.nvim_win_get_cursor(sidebar_state.winnr)
	local line_num = cursor[1]

	local uuid_to_path = vim.b[sidebar_state.bufnr].lifemode_sidebar_uuid_to_path
	local line_to_uuid = vim.b[sidebar_state.bufnr].lifemode_sidebar_links

	if not line_to_uuid or not uuid_to_path then
		return util.Err("jump_to_node: no links data found")
	end

	local target_uuid = line_to_uuid[line_num]

	if not target_uuid then
		return util.Err("jump_to_node: no link on current line")
	end

	local file_path = uuid_to_path[target_uuid]

	if not file_path or file_path == "" then
		return util.Err("jump_to_node: node has no file_path")
	end

	local windows = vim.api.nvim_list_wins()
	local main_winnr = nil

	for _, winnr in ipairs(windows) do
		if winnr ~= sidebar_state.winnr then
			local bufnr = vim.api.nvim_win_get_buf(winnr)
			local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
			if buftype == "" then
				main_winnr = winnr
				break
			end
		end
	end

	if not main_winnr then
		return util.Err("jump_to_node: no main window found")
	end

	vim.api.nvim_set_current_win(main_winnr)

	local success, err = pcall(vim.cmd.edit, file_path)
	if not success then
		return util.Err("jump_to_node: failed to open file: " .. tostring(err))
	end

	return util.Ok(nil)
end

function M.toggle_sidebar()
	if is_sidebar_open() then
		vim.api.nvim_win_close(sidebar_state.winnr, true)
		sidebar_state.winnr = nil
		sidebar_state.bufnr = nil
		sidebar_state.current_uuid = nil
		return util.Ok(nil)
	end

	local node_result = extmark.get_node_at_cursor()

	if not node_result.ok then
		return util.Err("toggle_sidebar: " .. node_result.error)
	end

	local uuid = node_result.value.uuid

	local create_result = M.create_sidebar_window()
	if not create_result.ok then
		return util.Err("toggle_sidebar: " .. create_result.error)
	end

	sidebar_state.bufnr = create_result.value.bufnr
	sidebar_state.winnr = create_result.value.winnr

	local render_result = M.render_sidebar(uuid)
	if not render_result.ok then
		vim.api.nvim_win_close(sidebar_state.winnr, true)
		sidebar_state.winnr = nil
		sidebar_state.bufnr = nil
		return util.Err("toggle_sidebar: " .. render_result.error)
	end

	return util.Ok(nil)
end

function M.is_open()
	return is_sidebar_open()
end

function M.get_current_uuid()
	return sidebar_state.current_uuid
end

return M
