local util = require("lifemode.util")
local M = {}

local function deep_copy(obj)
	if type(obj) ~= "table" then
		return obj
	end

	local copy = {}
	for k, v in pairs(obj) do
		copy[k] = deep_copy(v)
	end

	return copy
end

M.deep_copy = deep_copy

local function is_valid_uuid(str)
	if type(str) ~= "string" then
		return false
	end
	return str:match("^[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-4[0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$") ~= nil
end

function M.Node_new(content, meta, bounds)
	if type(content) ~= "string" then
		return util.Err("Node content must be a string")
	end

	if type(meta) ~= "table" then
		return util.Err("Node meta must be a table")
	end

	if not meta.id then
		return util.Err("Node meta.id is required")
	end

	if not is_valid_uuid(meta.id) then
		return util.Err("Node meta.id must be a valid UUID v4")
	end

	if not meta.created then
		return util.Err("Node meta.created is required")
	end

	if type(meta.created) ~= "number" then
		return util.Err("Node meta.created must be a timestamp (number)")
	end

	local node_meta = deep_copy(meta)

	if node_meta.modified and type(node_meta.modified) ~= "number" then
		return util.Err("Node meta.modified must be a timestamp (number)")
	end

	local node = {
		id = node_meta.id,
		content = content,
		meta = node_meta,
		bounds = bounds and deep_copy(bounds) or nil,
	}

	return util.Ok(node)
end

local VALID_EDGE_KINDS = {
	wikilink = true,
	transclusion = true,
	citation = true,
}

function M.Edge_new(from, to, kind, context)
	if type(from) ~= "string" then
		return util.Err("Edge from must be a string")
	end

	if not is_valid_uuid(from) then
		return util.Err("Edge from must be a valid UUID v4")
	end

	if type(to) ~= "string" then
		return util.Err("Edge to must be a string")
	end

	if not is_valid_uuid(to) then
		return util.Err("Edge to must be a valid UUID v4")
	end

	if type(kind) ~= "string" then
		return util.Err("Edge kind must be a string")
	end

	if not VALID_EDGE_KINDS[kind] then
		return util.Err("Edge kind must be wikilink, transclusion, or citation")
	end

	if context ~= nil and type(context) ~= "string" then
		return util.Err("Edge context must be a string or nil")
	end

	local edge = {
		from = from,
		to = to,
		kind = kind,
		context = context,
	}

	return util.Ok(edge)
end

function M.Citation_new(scheme, key, raw, location)
	if type(scheme) ~= "string" or scheme == "" then
		return util.Err("Citation scheme must be non-empty string")
	end

	if type(key) ~= "string" or key == "" then
		return util.Err("Citation key must be non-empty string")
	end

	if type(raw) ~= "string" or raw == "" then
		return util.Err("Citation raw must be non-empty string")
	end

	if location ~= nil then
		if type(location) ~= "table" then
			return util.Err("Citation location must be table or nil")
		end

		if type(location.node_id) ~= "string" or not is_valid_uuid(location.node_id) then
			return util.Err("Citation location.node_id must be valid UUID")
		end

		if type(location.line) ~= "number" then
			return util.Err("Citation location.line must be number")
		end

		if type(location.col) ~= "number" then
			return util.Err("Citation location.col must be number")
		end
	end

	local citation = {
		scheme = scheme,
		key = key,
		raw = raw,
		location = location and deep_copy(location) or nil,
	}

	return util.Ok(citation)
end

return M
