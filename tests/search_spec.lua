describe("Phase 24: Full-Text Search (FTS5)", function()
	local test_vault_path
	local config
	local builder
	local search

	before_each(function()
		package.loaded["lifemode.config"] = nil
		package.loaded["lifemode.infra.index.builder"] = nil
		package.loaded["lifemode.infra.index.search"] = nil
		package.loaded["lifemode.infra.index"] = nil
		package.loaded["lifemode.infra.index.init"] = nil
		config = require("lifemode.config")
		builder = require("lifemode.infra.index.builder")
		search = require("lifemode.infra.index.search")
		test_vault_path = "/tmp/lifemode_fts_test_" .. os.time() .. "_" .. math.random(100000, 999999)
		vim.fn.mkdir(test_vault_path, "p")
		config.validate_config({ vault_path = test_vault_path })
	end)

	after_each(function()
		if test_vault_path then
			vim.fn.delete(test_vault_path, "rf")
		end
		package.loaded["lifemode.config"] = nil
	end)

	describe("search.search", function()
		it("requires sqlite.lua to be installed", function()
			local has_sqlite = pcall(require, "sqlite.db")

			if has_sqlite then
				pending("sqlite.lua is installed, skipping negative test")
				return
			end

			local result = search.search("test")
			assert.is_false(result.ok)
			assert.is_truthy(result.error:match("sqlite%.lua not installed"))
		end)
	end)

	describe("basic keyword search", function()
		before_each(function()
			local has_sqlite = pcall(require, "sqlite.db")
			if not has_sqlite then
				pending("sqlite.lua not installed")
				return
			end

			local test1 = test_vault_path .. "/test1.md"
			local test2 = test_vault_path .. "/test2.md"

			vim.fn.writefile({
				"---",
				"id: aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa",
				"created: 1234567890",
				"---",
				"The quick brown fox jumps over the lazy dog",
			}, test1)

			vim.fn.writefile({
				"---",
				"id: bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb",
				"created: 1234567891",
				"---",
				"Quick thinking leads to quick solutions",
			}, test2)

			local rebuild_result = builder.rebuild_index()
			assert.is_true(rebuild_result.ok, "Rebuild failed: " .. tostring(rebuild_result.error))
		end)

		it("finds nodes matching keyword", function()
			local has_sqlite = pcall(require, "sqlite.db")
			if not has_sqlite then
				pending("sqlite.lua not installed")
				return
			end

			local results = search.search("quick")
			assert.is_true(results.ok)
			assert.equals(2, #results.value)
		end)

		it("ranks by relevance", function()
			local has_sqlite = pcall(require, "sqlite.db")
			if not has_sqlite then
				pending("sqlite.lua not installed")
				return
			end

			local results = search.search("quick")
			assert.is_true(results.ok)
			assert.equals(2, #results.value)

			assert.equals("bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb", results.value[1].uuid)
		end)
	end)

	describe("phrase search", function()
		before_each(function()
			local has_sqlite = pcall(require, "sqlite.db")
			if not has_sqlite then
				pending("sqlite.lua not installed")
				return
			end

			local test1 = test_vault_path .. "/test1.md"
			local test2 = test_vault_path .. "/test2.md"

			vim.fn.writefile({
				"---",
				"id: aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa",
				"created: 1234567890",
				"---",
				"The quick brown fox jumps over the lazy dog",
			}, test1)

			vim.fn.writefile({
				"---",
				"id: bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb",
				"created: 1234567891",
				"---",
				"Quick thinking leads to quick solutions",
			}, test2)

			builder.rebuild_index()
		end)

		it("matches exact phrases", function()
			local has_sqlite = pcall(require, "sqlite.db")
			if not has_sqlite then
				pending("sqlite.lua not installed")
				return
			end

			local results = search.search('"lazy dog"')
			assert.is_true(results.ok)
			assert.equals(1, #results.value)
			assert.equals("aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa", results.value[1].uuid)
		end)
	end)

	describe("prefix search", function()
		before_each(function()
			local has_sqlite = pcall(require, "sqlite.db")
			if not has_sqlite then
				pending("sqlite.lua not installed")
				return
			end

			local test1 = test_vault_path .. "/test1.md"
			local test2 = test_vault_path .. "/test2.md"

			vim.fn.writefile({
				"---",
				"id: aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa",
				"created: 1234567890",
				"---",
				"The quick brown fox jumps over the lazy dog",
			}, test1)

			vim.fn.writefile({
				"---",
				"id: bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb",
				"created: 1234567891",
				"---",
				"Quick thinking leads to quick solutions",
			}, test2)

			builder.rebuild_index()
		end)

		it("expands wildcards", function()
			local has_sqlite = pcall(require, "sqlite.db")
			if not has_sqlite then
				pending("sqlite.lua not installed")
				return
			end

			local results = search.search("qui*")
			assert.is_true(results.ok)
			assert.equals(2, #results.value)
		end)
	end)
end)
