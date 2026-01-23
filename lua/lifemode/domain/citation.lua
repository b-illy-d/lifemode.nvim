local types = require("lifemode.domain.types")

local M = {}

function M.parse_citations(content)
	if type(content) ~= "string" or content == "" then
		return {}
	end

	local citations = {}
	local pattern = "@([a-zA-Z0-9_%-]+)"

	local search_start = 1
	while true do
		local match_start, match_end, key = content:find(pattern, search_start)

		if not match_start then
			break
		end

		if key and key ~= "" then
			local raw = content:sub(match_start, match_end)

			local citation_result = types.Citation_new("bibtex", key, raw, nil)

			if citation_result.ok then
				table.insert(citations, citation_result.value)
			end
		end

		search_start = match_end + 1
	end

	return citations
end

return M
