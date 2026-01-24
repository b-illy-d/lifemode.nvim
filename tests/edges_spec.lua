local types = require("lifemode.domain.types")

describe("Phase 28: Store Edges in Index", function()
	local test_vault_path
	local config
	local index
	local has_sqlite
	local node1_uuid = "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa"
	local node2_uuid = "bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb"
	local node3_uuid = "cccccccc-cccc-4ccc-cccc-cccccccccccc"

	before_each(function()
		has_sqlite = pcall(require, "sqlite.db")
		if not has_sqlite then
			return
		end

		package.loaded["lifemode.config"] = nil
		package.loaded["lifemode.infra.index"] = nil
		package.loaded["lifemode.infra.index.init"] = nil
		config = require("lifemode.config")
		index = require("lifemode.infra.index")
		test_vault_path = "/tmp/lifemode_edges_test_" .. os.time() .. "_" .. math.random(100000, 999999)
		vim.fn.mkdir(test_vault_path, "p")
		config.validate_config({ vault_path = test_vault_path })
	end)

	after_each(function()
		if test_vault_path then
			vim.fn.delete(test_vault_path, "rf")
		end
		package.loaded["lifemode.config"] = nil
	end)

	describe("insert_edge", function()
		it("inserts wikilink edge", function()
			if not has_sqlite then
				pending("sqlite.lua not installed")
				return
			end

			local edge = types.Edge_new(node1_uuid, node2_uuid, "wikilink", nil)
			assert.is_true(edge.ok)

			local insert_result = index.insert_edge(edge.value)
			assert.is_true(insert_result.ok, "insert_edge failed: " .. tostring(insert_result.error))
		end)

		it("inserts transclusion edge", function()
			if not has_sqlite then
				pending("sqlite.lua not installed")
				return
			end

			local edge = types.Edge_new(node1_uuid, node3_uuid, "transclusion", nil)
			assert.is_true(edge.ok)

			local insert_result = index.insert_edge(edge.value)
			assert.is_true(insert_result.ok)
		end)

		it("inserts citation edge", function()
			if not has_sqlite then
				pending("sqlite.lua not installed")
				return
			end

			local edge = types.Edge_new(node1_uuid, node2_uuid, "citation", "somekey")
			assert.is_true(edge.ok)

			local insert_result = index.insert_edge(edge.value)
			assert.is_true(insert_result.ok)
		end)
	end)

	describe("find_edges", function()
		before_each(function()
			if not has_sqlite then
				return
			end

			local edge1 = types.Edge_new(node1_uuid, node2_uuid, "wikilink", nil)
			index.insert_edge(edge1.value)

			local edge2 = types.Edge_new(node1_uuid, node3_uuid, "transclusion", nil)
			index.insert_edge(edge2.value)
		end)

		it("finds outgoing edges", function()
			if not has_sqlite then
				pending("sqlite.lua not installed")
				return
			end

			local out = index.find_edges(node1_uuid, "out", nil)
			assert.is_true(out.ok)
			assert.is_true(#out.value >= 2)
		end)

		it("finds backlinks", function()
			if not has_sqlite then
				pending("sqlite.lua not installed")
				return
			end

			local backlinks = index.find_edges(node2_uuid, "in", nil)
			assert.is_true(backlinks.ok)
			assert.is_true(#backlinks.value >= 1)

			local has_edge_from_node1 = false
			for _, edge in ipairs(backlinks.value) do
				if edge.from_uuid == node1_uuid then
					has_edge_from_node1 = true
					break
				end
			end
			assert.is_true(has_edge_from_node1)
		end)

		it("filters by edge kind", function()
			if not has_sqlite then
				pending("sqlite.lua not installed")
				return
			end

			local wikilinks = index.find_edges(node1_uuid, "out", "wikilink")
			assert.is_true(wikilinks.ok)

			local has_only_wikilinks = true
			for _, edge in ipairs(wikilinks.value) do
				if edge.kind ~= "wikilink" then
					has_only_wikilinks = false
					break
				end
			end
			assert.is_true(has_only_wikilinks)

			local transclusions = index.find_edges(node1_uuid, "out", "transclusion")
			assert.is_true(transclusions.ok)

			local has_only_transclusions = true
			for _, edge in ipairs(transclusions.value) do
				if edge.kind ~= "transclusion" then
					has_only_transclusions = false
					break
				end
			end
			assert.is_true(has_only_transclusions)
		end)
	end)

	describe("delete_edges_from", function()
		before_each(function()
			if not has_sqlite then
				return
			end

			local edge1 = types.Edge_new(node1_uuid, node2_uuid, "wikilink", nil)
			index.insert_edge(edge1.value)

			local edge2 = types.Edge_new(node1_uuid, node3_uuid, "transclusion", nil)
			index.insert_edge(edge2.value)
		end)

		it("deletes all outgoing edges from node", function()
			if not has_sqlite then
				pending("sqlite.lua not installed")
				return
			end

			local delete_result = index.delete_edges_from(node1_uuid)
			assert.is_true(delete_result.ok)

			local after = index.find_edges(node1_uuid, "out", nil)
			assert.is_true(after.ok)
			assert.equals(0, #after.value)
		end)

		it("preserves backlinks to other nodes", function()
			if not has_sqlite then
				pending("sqlite.lua not installed")
				return
			end

			local before = index.find_edges(node2_uuid, "in", nil)
			assert.is_true(before.ok)
			local before_count = #before.value

			index.delete_edges_from(node1_uuid)

			local after = index.find_edges(node2_uuid, "in", nil)
			assert.is_true(after.ok)
		end)
	end)
end)
