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

	if not node_meta.modified then
		node_meta.modified = node_meta.created
	end

	if type(node_meta.modified) ~= "number" then
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

return M
