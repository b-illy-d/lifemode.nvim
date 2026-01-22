local util = require("lifemode.util")
local types = require("lifemode.domain.types")
local M = {}

local function to_yaml_value(value, indent)
	indent = indent or ""
	local t = type(value)

	if t == "string" then
		if value:match("\n") or value:match("[:#@%[%]{}|>]") then
			return "|\n" .. indent .. "  " .. value:gsub("\n", "\n" .. indent .. "  ")
		else
			return value
		end
	elseif t == "number" then
		return tostring(value)
	elseif t == "boolean" then
		return value and "true" or "false"
	elseif t == "table" then
		local lines = {}
		for k, v in pairs(value) do
			local key = tostring(k)
			local val = to_yaml_value(v, indent .. "  ")
			if type(v) == "table" then
				table.insert(lines, indent .. key .. ":")
				table.insert(lines, val)
			else
				table.insert(lines, indent .. key .. ": " .. val)
			end
		end
		return table.concat(lines, "\n")
	else
		return tostring(value)
	end
end

function M.create(content, meta)
	if type(content) ~= "string" then
		return util.Err("content must be a string")
	end

	meta = meta or {}

	if type(meta) ~= "table" then
		return util.Err("meta must be a table")
	end

	local node_meta = types.deep_copy(meta)

	if not node_meta.id then
		node_meta.id = util.uuid()
	end

	if not node_meta.created then
		node_meta.created = os.time()
	end

	if not node_meta.modified then
		node_meta.modified = node_meta.created
	end

	return types.Node_new(content, node_meta)
end

function M.validate(node)
	if type(node) ~= "table" then
		return util.Err("node must be a table")
	end

	if not node.id then
		return util.Err("node.id is required")
	end

	if type(node.id) ~= "string" then
		return util.Err("node.id must be a string")
	end

	if not node.id:match("^[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-4[0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$") then
		return util.Err("node.id must be a valid UUID v4")
	end

	if not node.content then
		return util.Err("node.content is required")
	end

	if type(node.content) ~= "string" then
		return util.Err("node.content must be a string")
	end

	if not node.meta then
		return util.Err("node.meta is required")
	end

	if type(node.meta) ~= "table" then
		return util.Err("node.meta must be a table")
	end

	if not node.meta.id then
		return util.Err("node.meta.id is required")
	end

	if not node.meta.created then
		return util.Err("node.meta.created is required")
	end

	if type(node.meta.created) ~= "number" then
		return util.Err("node.meta.created must be a timestamp (number)")
	end

	if node.meta.modified and type(node.meta.modified) ~= "number" then
		return util.Err("node.meta.modified must be a timestamp (number)")
	end

	return util.Ok(node)
end

function M.to_markdown(node)
	local yaml_lines = {}

	for k, v in pairs(node.meta) do
		local val = to_yaml_value(v, "")
		if type(v) == "table" then
			table.insert(yaml_lines, k .. ":")
			table.insert(yaml_lines, val)
		else
			table.insert(yaml_lines, k .. ": " .. val)
		end
	end

	local frontmatter = "---\n" .. table.concat(yaml_lines, "\n") .. "\n---"
	return frontmatter .. "\n" .. node.content
end

return M
