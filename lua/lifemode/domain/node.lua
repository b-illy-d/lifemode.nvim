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

local function parse_yaml_value(value_str)
	value_str = value_str:match("^%s*(.-)%s*$")

	if value_str == "true" then
		return true
	elseif value_str == "false" then
		return false
	elseif value_str:match("^%-?%d+%.%d+$") then
		return tonumber(value_str)
	elseif value_str:match("^%-?%d+$") then
		return tonumber(value_str)
	else
		return value_str
	end
end

local function parse_yaml_lines(lines, start_idx)
	local result = {}
	local i = start_idx
	local base_indent = nil

	while i <= #lines do
		local line = lines[i]
		local indent = line:match("^(%s*)")
		local indent_level = #indent

		if base_indent == nil then
			base_indent = indent_level
		end

		if indent_level < base_indent then
			break
		end

		if indent_level == base_indent then
			local key, value = line:match("^%s*([^:]+):%s*(.*)$")
			if key then
				key = key:match("^%s*(.-)%s*$")

				if value == "" then
					i = i + 1
					if i <= #lines then
						local next_line = lines[i]
						local next_indent = #(next_line:match("^(%s*)"))

						if next_indent > indent_level then
							if next_line:match("^%s*|%s*$") or lines[i-1]:match(":%s*|%s*$") then
								local multiline_parts = {}
								while i <= #lines do
									local ml_line = lines[i]
									local ml_indent = #(ml_line:match("^(%s*)"))
									if ml_indent <= base_indent then
										break
									end
									table.insert(multiline_parts, ml_line:match("^%s*(.*)$"))
									i = i + 1
								end
								result[key] = table.concat(multiline_parts, "\n")
								i = i - 1
							else
								local nested, next_i = parse_yaml_lines(lines, i)
								result[key] = nested
								i = next_i - 1
							end
						end
					end
				else
					result[key] = parse_yaml_value(value)
				end
			end
		end

		i = i + 1
	end

	local all_numeric = true
	local max_idx = 0
	for k, _ in pairs(result) do
		local num = tonumber(k)
		if not num then
			all_numeric = false
			break
		end
		if num > max_idx then
			max_idx = num
		end
	end

	if all_numeric and max_idx > 0 then
		local arr = {}
		for j = 1, max_idx do
			arr[j] = result[tostring(j)]
		end
		return arr, i
	end

	return result, i
end

function M.parse(text)
	if type(text) ~= "string" then
		return util.Err("text must be a string")
	end

	local first_delim = text:find("^%-%-%-%s*\n")
	if not first_delim then
		return util.Err("Missing frontmatter: expected '---' at start")
	end

	local frontmatter_start = first_delim + 4
	local second_delim = text:find("\n%-%-%-%s*\n", frontmatter_start)

	if not second_delim then
		return util.Err("Missing frontmatter closing delimiter: expected '---'")
	end

	local frontmatter_text = text:sub(frontmatter_start, second_delim - 1)
	local content = text:sub(second_delim + 5)

	local lines = {}
	for line in frontmatter_text:gmatch("([^\n]*)\n?") do
		if line ~= "" or frontmatter_text:sub(#frontmatter_text, #frontmatter_text) == "\n" then
			table.insert(lines, line)
		end
	end

	local meta, _ = parse_yaml_lines(lines, 1)

	if not meta.id then
		return util.Err("Missing required field: id")
	end

	if not meta.created then
		return util.Err("Missing required field: created")
	end

	return types.Node_new(content, meta)
end

return M
