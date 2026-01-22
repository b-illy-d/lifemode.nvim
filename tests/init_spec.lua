local mock = require("luassert.mock")
local lifemode
local tmp_dir

describe("init", function()
	before_each(function()
		package.loaded["lifemode.init"] = nil
		package.loaded["lifemode.config"] = nil
		lifemode = require("lifemode.init")
		math.randomseed(os.time() * 1000 + os.clock() * 1000000)
		tmp_dir = "/tmp/lifemode_test_" .. os.time() .. "_" .. math.random(1000000)
		os.execute("mkdir -p " .. tmp_dir)
	end)

	after_each(function()
		os.execute("rm -rf " .. tmp_dir)
		package.loaded["lifemode.init"] = nil
		package.loaded["lifemode.config"] = nil
	end)

	describe("setup", function()
		it("initializes successfully with valid config", function()
			local api = mock(vim.api, true)
			api.nvim_create_augroup.returns(42)

			assert.has_no.errors(function()
				lifemode.setup({ vault_path = tmp_dir })
			end)

			assert.stub(api.nvim_create_augroup).was_called_with("LifeMode", { clear = true })
			mock.revert(api)
		end)

		it("creates autocommand group", function()
			local api = mock(vim.api, true)
			api.nvim_create_augroup.returns(42)

			lifemode.setup({ vault_path = tmp_dir })

			assert.stub(api.nvim_create_augroup).was_called(1)
			assert.stub(api.nvim_create_augroup).was_called_with("LifeMode", { clear = true })
			mock.revert(api)
		end)

		it("throws error on second setup call", function()
			local api = mock(vim.api, true)
			api.nvim_create_augroup.returns(42)

			lifemode.setup({ vault_path = tmp_dir })

			assert.has_error(function()
				lifemode.setup({ vault_path = tmp_dir })
			end, "already initialized")

			mock.revert(api)
		end)

		it("propagates config validation errors with LifeMode prefix", function()
			local api = mock(vim.api, true)

			assert.has_error(function()
				lifemode.setup({ vault_path = "/tmp/nonexistent_dir_12345" })
			end, "%[LifeMode%]")

			mock.revert(api)
		end)

		it("propagates vault_path validation error", function()
			local api = mock(vim.api, true)

			assert.has_error(function()
				lifemode.setup({ vault_path = "/tmp/nonexistent_dir_12345" })
			end, "does not exist")

			mock.revert(api)
		end)

		it("uses defaults when setup called with nil", function()
			local api = mock(vim.api, true)
			api.nvim_create_augroup.returns(42)

			local home = os.getenv("HOME")
			local default_vault = home .. "/vault"
			local vault_exists = os.execute("test -d " .. default_vault) == 0

			if vault_exists then
				assert.has_no.errors(function()
					lifemode.setup(nil)
				end)
				assert.stub(api.nvim_create_augroup).was_called()
			else
				assert.has_error(function()
					lifemode.setup(nil)
				end, "does not exist")
			end

			mock.revert(api)
		end)

		it("uses defaults when setup called with empty table", function()
			local api = mock(vim.api, true)
			api.nvim_create_augroup.returns(42)

			local home = os.getenv("HOME")
			local default_vault = home .. "/vault"
			local vault_exists = os.execute("test -d " .. default_vault) == 0

			if vault_exists then
				assert.has_no.errors(function()
					lifemode.setup({})
				end)
				assert.stub(api.nvim_create_augroup).was_called()
			else
				assert.has_error(function()
					lifemode.setup({})
				end, "does not exist")
			end

			mock.revert(api)
		end)

		it("allows config override of defaults", function()
			local api = mock(vim.api, true)
			api.nvim_create_augroup.returns(42)

			lifemode.setup({
				vault_path = tmp_dir,
				sidebar = {
					width_percent = 50,
				},
			})

			local config = require("lifemode.config")
			assert.equals(50, config.get("sidebar.width_percent"))

			mock.revert(api)
		end)
	end)

	describe("module reset behavior", function()
		it("allows re-initialization after package.loaded reset", function()
			local api = mock(vim.api, true)
			api.nvim_create_augroup.returns(42)

			lifemode.setup({ vault_path = tmp_dir })

			package.loaded["lifemode.init"] = nil
			package.loaded["lifemode.config"] = nil
			local new_lifemode = require("lifemode.init")

			assert.has_no.errors(function()
				new_lifemode.setup({ vault_path = tmp_dir })
			end)

			assert.stub(api.nvim_create_augroup).was_called(2)
			mock.revert(api)
		end)
	end)
end)
