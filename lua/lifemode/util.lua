local M = {}

local Result = {}
Result.__index = Result

function M.Ok(value)
	local result = { ok = true, value = value }
	return setmetatable(result, Result)
end

function M.Err(error)
	local result = { ok = false, error = error }
	return setmetatable(result, Result)
end

function Result:unwrap()
	if self.ok then
		return self.value
	else
		error(self.error)
	end
end

function Result:unwrap_or(default)
	if self.ok then
		return self.value
	else
		return default
	end
end

local bit_lib = bit or bit32
local band, bor

if bit_lib then
	band = bit_lib.band
	bor = bit_lib.bor
else
	band = function(a, b)
		local result = 0
		local bit = 1
		while a > 0 or b > 0 do
			if a % 2 == 1 and b % 2 == 1 then
				result = result + bit
			end
			a = math.floor(a / 2)
			b = math.floor(b / 2)
			bit = bit * 2
		end
		return result
	end

	bor = function(a, b)
		local result = 0
		local bit = 1
		while a > 0 or b > 0 do
			if a % 2 == 1 or b % 2 == 1 then
				result = result + bit
			end
			a = math.floor(a / 2)
			b = math.floor(b / 2)
			bit = bit * 2
		end
		return result
	end
end

function M.uuid()
	local f = io.open("/dev/urandom", "rb")
	if not f then
		error("Failed to open /dev/urandom")
	end

	local bytes = {}
	for i = 1, 16 do
		bytes[i] = string.byte(f:read(1))
	end
	f:close()

	bytes[7] = bor(band(bytes[7], 0x0F), 0x40)
	bytes[9] = bor(band(bytes[9], 0x3F), 0x80)

	return string.format(
		"%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
		bytes[1],
		bytes[2],
		bytes[3],
		bytes[4],
		bytes[5],
		bytes[6],
		bytes[7],
		bytes[8],
		bytes[9],
		bytes[10],
		bytes[11],
		bytes[12],
		bytes[13],
		bytes[14],
		bytes[15],
		bytes[16]
	)
end

function M.parse_date(str)
	if not str or type(str) ~= "string" then
		return M.Err("Invalid date: expected string")
	end

	local year, month, day = str:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")

	if not year then
		return M.Err("Invalid date format: expected YYYY-MM-DD")
	end

	year = tonumber(year)
	month = tonumber(month)
	day = tonumber(day)

	if month < 1 or month > 12 then
		return M.Err("Invalid month: must be between 01 and 12")
	end

	if day < 1 or day > 31 then
		return M.Err("Invalid day: must be between 01 and 31")
	end

	local timestamp = os.time({ year = year, month = month, day = day, hour = 0, min = 0, sec = 0 })

	if not timestamp then
		return M.Err("Invalid date: os.time() failed")
	end

	return M.Ok(timestamp)
end

return M
