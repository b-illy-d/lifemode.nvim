-- UUID generation module for LifeMode
-- Generates UUID v4 using system uuidgen command

local M = {}

--- Generate a UUID v4
--- @return string UUID in lowercase format (e.g., "550e8400-e29b-41d4-a716-446655440000")
function M.generate()
  -- Use system uuidgen command (available on macOS and most Linux systems)
  local uuid = vim.fn.system('uuidgen'):gsub('%s+', ''):lower()
  return uuid
end

return M
