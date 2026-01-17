local M = {}

local MONTH_NAMES = {
  '01', 'January',
  '02', 'February',
  '03', 'March',
  '04', 'April',
  '05', 'May',
  '06', 'June',
  '07', 'July',
  '08', 'August',
  '09', 'September',
  '10', 'October',
  '11', 'November',
  '12', 'December',
}

local MONTH_LOOKUP = {}
for i = 1, #MONTH_NAMES, 2 do
  MONTH_LOOKUP[MONTH_NAMES[i]] = MONTH_NAMES[i + 1]
end

local DAY_NAMES = {'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'}

function M.today()
  return os.date('%Y-%m-%d')
end

function M.parse(date_str)
  local year, month, day = date_str:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
  if not year then return nil end

  return {
    year = year,
    month = year .. '-' .. month,
    day = date_str,
  }
end

function M.format_day(date_str)
  local year, month, day = date_str:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
  if not year then return date_str end

  local timestamp = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
  })
  local weekday = os.date('*t', timestamp).wday

  return day .. ' ' .. DAY_NAMES[weekday]
end

function M.format_month(month_str)
  local month_num = month_str:match('^%d%d%d%d%-(%d%d)$')
  return MONTH_LOOKUP[month_num] or month_str
end

function M.sort_descending(list)
  table.sort(list, function(a, b) return a > b end)
  return list
end

return M
