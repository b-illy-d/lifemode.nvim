local util = require("lifemode.util")

local M = {}

function M.parse(content)
	if type(content) ~= "string" or content == "" then
		return {}
	end

	local tokens = {}
	local pattern = "{{([a-zA-Z0-9%-]+):?(%d*)}}"

	local search_start = 1
	while true do
		local match_start, match_end, uuid, depth_str = content:find(pattern, search_start)

		if not match_start then
			break
		end

		if uuid and uuid ~= "" then
			local depth = nil
			if depth_str and depth_str ~= "" then
				depth = tonumber(depth_str)
			end

			table.insert(tokens, {
				uuid = uuid,
				depth = depth,
				start_pos = match_start,
				end_pos = match_end,
			})
		end

		search_start = match_end + 1
	end

	return tokens
end

local function copy_visited(visited)
	local copy = {}
	for k, v in pairs(visited) do
		copy[k] = v
	end
	return copy
end

local function replace_token(content, token, replacement)
	local before = content:sub(1, token.start_pos - 1)
	local after = content:sub(token.end_pos + 1)
	return before .. replacement .. after
end

local function expand_token(token, visited, depth, max_depth, fetch_fn)
	if visited[token.uuid] then
		return "⚠️ Cycle detected: {{" .. token.uuid .. "}}"
	end

	if depth >= max_depth then
		return "⚠️ Max depth reached"
	end

	local visited_copy = copy_visited(visited)
	visited_copy[token.uuid] = true

	local node_result = fetch_fn(token.uuid)
	if not node_result.ok or node_result.value == nil then
		return "⚠️ Node not found: {{" .. token.uuid .. "}}"
	end

	local node = node_result.value
	local node_content = node.content or ""

	local expanded_result = M.expand(node_content, visited_copy, depth + 1, max_depth, fetch_fn)
	if not expanded_result.ok then
		return "⚠️ Error expanding: " .. expanded_result.error
	end

	return expanded_result.value
end

function M.expand(content, visited, depth, max_depth, fetch_fn)
	if type(content) ~= "string" then
		return util.Err("expand: content must be string")
	end

	if type(visited) ~= "table" then
		return util.Err("expand: visited must be table")
	end

	if type(depth) ~= "number" or depth < 0 then
		return util.Err("expand: depth must be non-negative number")
	end

	if type(max_depth) ~= "number" or max_depth < 1 then
		return util.Err("expand: max_depth must be positive number")
	end

	if type(fetch_fn) ~= "function" then
		return util.Err("expand: fetch_fn must be function")
	end

	local current_content = content
	local tokens = M.parse(current_content)

	for i = #tokens, 1, -1 do
		local token = tokens[i]
		local replacement = expand_token(token, visited, depth, max_depth, fetch_fn)
		current_content = replace_token(current_content, token, replacement)
	end

	return util.Ok(current_content)
end

return M
