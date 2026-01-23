local util = require("lifemode.util")
local config = require("lifemode.config")
local domain_citation = require("lifemode.domain.citation")

local M = {}

local function get_citation_under_cursor()
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2] + 1

	local citations = domain_citation.parse_citations(line)

	for _, cit in ipairs(citations) do
		local start_pos = line:find("@" .. cit.key, 1, true)
		if start_pos then
			local end_pos = start_pos + #cit.raw - 1
			if col >= start_pos and col <= end_pos then
				return util.Ok({ key = cit.key, scheme = cit.scheme })
			end
		end
	end

	return util.Err("No citation under cursor")
end

local function get_source_path(key)
	local vault_path = config.get("vault_path")
	return vault_path .. "/.lifemode/sources/" .. key .. ".yaml"
end

local function create_source_file(path, key)
	local dir = vim.fn.fnamemodify(path, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		local mkdir_ok, mkdir_err = pcall(function()
			vim.fn.mkdir(dir, "p")
		end)
		if not mkdir_ok then
			return util.Err("Failed to create directory: " .. tostring(mkdir_err))
		end
	end

	local template = string.format(
		[[---
key: %s
title: ""
author: ""
year: ""
type: article
url: ""
notes: ""
]],
		key
	)

	local file_ok, file = pcall(io.open, path, "w")
	if not file_ok or not file then
		return util.Err("Failed to create source file: " .. path)
	end

	file:write(template)
	file:close()

	return util.Ok(nil)
end

function M.jump_to_source()
	local cit_result = get_citation_under_cursor()
	if not cit_result.ok then
		return cit_result
	end

	local citation = cit_result.value
	local source_path = get_source_path(citation.key)

	if vim.fn.filereadable(source_path) == 1 then
		vim.cmd.edit(source_path)
		return util.Ok(nil)
	end

	local choice = vim.fn.confirm(
		"Source file not found: " .. citation.key .. ".yaml\nCreate it?",
		"&Yes\n&No",
		2
	)

	if choice == 1 then
		local create_result = create_source_file(source_path, citation.key)
		if not create_result.ok then
			return create_result
		end
		vim.cmd.edit(source_path)
		return util.Ok(nil)
	end

	return util.Err("Source file not found: " .. citation.key .. ".yaml")
end

return M
