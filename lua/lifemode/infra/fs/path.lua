local M = {}

local MONTH_ABBREV = {
	"Jan",
	"Feb",
	"Mar",
	"Apr",
	"May",
	"Jun",
	"Jul",
	"Aug",
	"Sep",
	"Oct",
	"Nov",
	"Dec",
}

function M.date_path(vault_root, date)
	local timestamp
	if date == nil then
		timestamp = os.time()
	elseif type(date) == "number" then
		timestamp = date
	elseif type(date) == "table" then
		timestamp = os.time(date)
	else
		timestamp = os.time()
	end

	local date_table = os.date("*t", timestamp)
	local year = date_table.year
	local month = date_table.month
	local day = date_table.day

	local month_abbrev = MONTH_ABBREV[month]
	local month_padded = string.format("%02d", month)
	local day_padded = string.format("%02d", day)

	local expanded_root = vim.fn.expand(vault_root)
	if expanded_root:sub(-1) == "/" then
		expanded_root = expanded_root:sub(1, -2)
	end

	return expanded_root .. "/" .. year .. "/" .. month_padded .. "-" .. month_abbrev .. "/" .. day_padded .. "/"
end

function M.resolve(vault_root, relative_path)
	local expanded_root = vim.fn.expand(vault_root)

	if expanded_root:sub(-1) == "/" then
		expanded_root = expanded_root:sub(1, -2)
	end

	if relative_path:sub(1, 1) == "/" then
		relative_path = relative_path:sub(2)
	end

	return expanded_root .. "/" .. relative_path
end

return M
