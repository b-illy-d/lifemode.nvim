local transclude = require("lifemode.app.transclude")

describe("transclude cache", function()
	it("uses cache on second render", function()
		local content = { "Hello {{test-uuid}}" }
		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
		vim.api.nvim_win_set_buf(0, bufnr)

		local result1 = transclude.render_transclusions(bufnr)
		assert.is_true(result1.ok)

		local cache = vim.b[bufnr].lifemode_transclusion_cache
		assert.is_not_nil(cache)

		local cache_size_before = 0
		for _ in pairs(cache) do
			cache_size_before = cache_size_before + 1
		end

		local result2 = transclude.render_transclusions(bufnr)
		assert.is_true(result2.ok)

		local cache_after = vim.b[bufnr].lifemode_transclusion_cache
		local cache_size_after = 0
		for _ in pairs(cache_after) do
			cache_size_after = cache_size_after + 1
		end

		assert.equals(cache_size_before, cache_size_after)
	end)

	it("clear_cache empties the cache", function()
		local content = { "Hello {{test-uuid}}" }
		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
		vim.api.nvim_win_set_buf(0, bufnr)

		local result = transclude.render_transclusions(bufnr)
		assert.is_true(result.ok)

		local cache = vim.b[bufnr].lifemode_transclusion_cache
		assert.is_not_nil(cache)

		local had_entries = false
		for _ in pairs(cache) do
			had_entries = true
			break
		end
		assert.is_true(had_entries)

		transclude.clear_cache(bufnr)

		local cache_after = vim.b[bufnr].lifemode_transclusion_cache
		assert.is_not_nil(cache_after)

		local count = 0
		for _ in pairs(cache_after) do
			count = count + 1
		end
		assert.equals(0, count)
	end)

	it("buffer-local cache isolation", function()
		local content = { "Hello {{test-uuid}}" }
		local bufnr1 = vim.api.nvim_create_buf(false, true)
		local bufnr2 = vim.api.nvim_create_buf(false, true)

		vim.api.nvim_buf_set_lines(bufnr1, 0, -1, false, content)
		vim.api.nvim_buf_set_lines(bufnr2, 0, -1, false, content)

		vim.api.nvim_win_set_buf(0, bufnr1)
		local result1 = transclude.render_transclusions(bufnr1)
		assert.is_true(result1.ok)

		local cache1 = vim.b[bufnr1].lifemode_transclusion_cache
		local cache2 = vim.b[bufnr2].lifemode_transclusion_cache

		assert.is_not_nil(cache1)

		local count1 = 0
		for _ in pairs(cache1) do
			count1 = count1 + 1
		end
		assert.is_true(count1 > 0)

		local count2 = 0
		if cache2 then
			for _ in pairs(cache2) do
				count2 = count2 + 1
			end
		end
		assert.equals(0, count2)
	end)
end)
