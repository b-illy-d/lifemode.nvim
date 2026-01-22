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

return M
