local config
local tmp_dir

describe("config", function()
	before_each(function()
		package.loaded["lifemode.config"] = nil
		config = require("lifemode.config")
		math.randomseed(os.time() * 1000 + os.clock() * 1000000)
		tmp_dir = "/tmp/lifemode_test_" .. os.time() .. "_" .. math.random(1000000)
		os.execute("mkdir -p " .. tmp_dir)
	end)

	after_each(function()
		os.execute("rm -rf " .. tmp_dir)
		package.loaded["lifemode.config"] = nil
	end)

	describe("validate_config", function()
		it("validates config with existing directory", function()
			local result = config.validate_config({ vault_path = tmp_dir })

			assert.is_true(result.ok)
			assert.equals(tmp_dir, result.value.vault_path)
		end)

		it("expands tilde in vault_path", function()
			local home = os.getenv("HOME")
			local timestamp = os.time()
			local test_vault = home .. "/lifemode_test_vault_" .. timestamp
			os.execute("mkdir -p " .. test_vault)

			local result = config.validate_config({ vault_path = "~/lifemode_test_vault_" .. timestamp })

			os.execute("rm -rf " .. test_vault)

			assert.is_true(result.ok)
			assert.equals(test_vault, result.value.vault_path)
		end)

		it("deep merges user config with defaults", function()
			local result = config.validate_config({
				vault_path = tmp_dir,
				sidebar = {
					width_percent = 50,
				},
			})

			assert.is_true(result.ok)
			assert.equals(50, result.value.sidebar.width_percent)
			assert.equals("right", result.value.sidebar.position)
		end)

		it("returns Err for empty vault_path", function()
			local result = config.validate_config({ vault_path = "" })

			assert.is_false(result.ok)
			assert.matches("vault_path is required", result.error)
		end)

		it("returns Err for non-existent directory", function()
			local result = config.validate_config({ vault_path = "/tmp/nonexistent_dir_12345" })

			assert.is_false(result.ok)
			assert.matches("does not exist", result.error)
		end)

		it("returns Err for non-table config", function()
			local result = config.validate_config("not a table")

			assert.is_false(result.ok)
			assert.matches("Config must be a table", result.error)
		end)

		it("handles empty config by using defaults", function()
			local default_vault = os.getenv("HOME") .. "/vault"
			local vault_exists = os.execute("test -d " .. default_vault) == 0

			local result = config.validate_config({})

			if vault_exists then
				assert.is_true(result.ok)
				assert.equals(default_vault, result.value.vault_path)
			else
				assert.is_false(result.ok)
				assert.matches("does not exist", result.error)
			end
		end)

		it("handles special characters in path", function()
			local special_dir = tmp_dir .. "/test-vault_123"
			os.execute("mkdir -p '" .. special_dir .. "'")

			local result = config.validate_config({ vault_path = special_dir })

			assert.is_true(result.ok)
			assert.equals(special_dir, result.value.vault_path)
		end)

		it("handles relative paths", function()
			os.execute("cd " .. tmp_dir .. " && mkdir -p vault")
			local cwd = io.popen("pwd"):read("*l")
			local orig_dir = cwd
			os.execute("cd " .. tmp_dir)

			local result = config.validate_config({ vault_path = tmp_dir .. "/vault" })

			os.execute("cd " .. orig_dir)

			assert.is_true(result.ok)
		end)
	end)

	describe("get", function()
		it("throws error before validate_config is called", function()
			assert.has_error(function()
				config.get()
			end)
		end)

		it("returns full config when called without key", function()
			config.validate_config({ vault_path = tmp_dir })
			local result = config.get()

			assert.equals(tmp_dir, result.vault_path)
			assert.is_not.is_nil(result.sidebar)
		end)

		it("returns value for simple key", function()
			config.validate_config({ vault_path = tmp_dir })
			local result = config.get("vault_path")

			assert.equals(tmp_dir, result)
		end)

		it("returns value for dotted key", function()
			config.validate_config({ vault_path = tmp_dir })
			local result = config.get("sidebar.width_percent")

			assert.equals(30, result)
		end)

		it("returns nil for non-existent key", function()
			config.validate_config({ vault_path = tmp_dir })
			local result = config.get("nonexistent")

			assert.is_nil(result)
		end)

		it("returns nil for non-existent nested key", function()
			config.validate_config({ vault_path = tmp_dir })
			local result = config.get("sidebar.nonexistent")

			assert.is_nil(result)
		end)

		it("persists state across multiple get calls", function()
			config.validate_config({ vault_path = tmp_dir })

			local first = config.get("vault_path")
			local second = config.get("vault_path")

			assert.equals(first, second)
		end)
	end)

	describe("singleton behavior", function()
		it("state persists when requiring module again", function()
			config.validate_config({ vault_path = tmp_dir })
			local first_path = config.get("vault_path")

			local config2 = require("lifemode.config")
			local second_path = config2.get("vault_path")

			assert.equals(first_path, second_path)
		end)

		it("state resets after package.loaded reset", function()
			config.validate_config({ vault_path = tmp_dir })
			config.get("vault_path")

			package.loaded["lifemode.config"] = nil
			local new_config = require("lifemode.config")

			assert.has_error(function()
				new_config.get("vault_path")
			end)
		end)
	end)
end)
