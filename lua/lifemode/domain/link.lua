local M = {}

local function trim(s)
	return s:match("^%s*(.-)%s*$")
end

local function is_valid_uuid(str)
	if type(str) ~= "string" then
		return false
	end
	return str:match("^[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-4[0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$") ~= nil
end

function M.parse_wikilinks(content)
	if type(content) ~= "string" then
		return {}
	end

	local links = {}
	local pattern = "%[%[([^%]]+)%]%]"

	local search_start = 1
	while true do
		local match_start, match_end, inner_text = content:find(pattern, search_start)

		if not match_start then
			break
		end

		if inner_text and inner_text ~= "" then
			local target, display = inner_text:match("^(.-)%|(.+)$")

			if not target then
				target = inner_text
				display = nil
			end

			target = trim(target)
			if display then
				display = trim(display)
			end

			if target ~= "" then
				table.insert(links, {
					type = "wikilink",
					target = target,
					display = display,
					position = {
						start = match_start,
						end_pos = match_end,
					},
				})
			end
		end

		search_start = match_end + 1
	end

	return links
end

function M.parse_transclusions(content)
	if type(content) ~= "string" then
		return {}
	end

	local links = {}
	local pattern = "!%[%[([^%]]+)%]%]"

	local search_start = 1
	while true do
		local match_start, match_end, inner_text = content:find(pattern, search_start)

		if not match_start then
			break
		end

		if inner_text and inner_text ~= "" then
			local target, display = inner_text:match("^(.-)%|(.+)$")

			if not target then
				target = inner_text
				display = nil
			end

			target = trim(target)
			if display then
				display = trim(display)
			end

			if target ~= "" then
				table.insert(links, {
					type = "transclusion",
					target = target,
					display = display,
					position = {
						start = match_start,
						end_pos = match_end,
					},
				})
			end
		end

		search_start = match_end + 1
	end

	return links
end

return M
