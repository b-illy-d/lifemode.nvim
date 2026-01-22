local config = require("lifemode.config")
local node_module = require("lifemode.domain.node")
local path = require("lifemode.infra.fs.path")
local write = require("lifemode.infra.fs.write")
local util = require("lifemode.util")

local M = {}

function M.capture_node(initial_content)
	initial_content = initial_content or ""

	if type(initial_content) ~= "string" then
		return util.Err("initial_content must be a string")
	end

	local vault_path = config.get("vault_path")
	if not vault_path then
		return util.Err("vault_path not configured")
	end

	local date_dir = path.date_path(vault_path)

	local node_result = node_module.create(initial_content)
	if not node_result.ok then
		return util.Err("Failed to create node: " .. node_result.error)
	end

	local node = node_result.value

	local markdown = node_module.to_markdown(node)

	local file_path = date_dir .. node.meta.id .. ".md"

	local write_result = write.write(file_path, markdown)
	if not write_result.ok then
		return util.Err("Failed to write file: " .. write_result.error)
	end

	return util.Ok({
		node = node,
		file_path = file_path,
	})
end

return M
