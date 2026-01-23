# Phase 34: Transclusion Cache

## Overview
Add performance caching to transclusion rendering. Cache expanded content per buffer to avoid redundant expansion work.

## Function Signatures

### `get_cache(bufnr) → table`
Get or create cache for a buffer.

**Parameters:**
- `bufnr: number` - buffer number

**Returns:**
- `table` - cache table with structure `{[key] = expanded_content}`

**Logic:**
```lua
if not vim.b[bufnr].lifemode_transclusion_cache then
  vim.b[bufnr].lifemode_transclusion_cache = {}
end
return vim.b[bufnr].lifemode_transclusion_cache
```

### `clear_cache(bufnr)`
Clear transclusion cache for a buffer.

**Parameters:**
- `bufnr: number` - buffer number

**Logic:**
```lua
vim.b[bufnr].lifemode_transclusion_cache = {}
```

### `get_cache_key(uuid, depth?) → string`
Generate cache key from UUID and optional depth.

**Parameters:**
- `uuid: string`
- `depth: number?` - optional depth (currently unused, but future-proof)

**Returns:**
- `string` - cache key like "uuid" or "uuid:5"

**Logic:**
```lua
if depth then
  return uuid .. ":" .. tostring(depth)
else
  return uuid
end
```

### Modified: `render_transclusions(bufnr)`
Update to use cache.

**Changes:**
1. Get cache at start: `local cache = get_cache(bufnr)`
2. For each token:
   - Generate cache key from `token.uuid` and `token.depth`
   - Check if `cache[key]` exists
   - If exists: use cached value
   - If not: expand via `domain_transclude.expand()`, store in `cache[key]`
3. Rest of rendering unchanged

### Modified: `M.refresh_transclusions()` command handler
Clear cache before rendering.

**Logic:**
```lua
function M.refresh_transclusions_cmd()
  local bufnr = vim.api.nvim_get_current_buf()
  clear_cache(bufnr)
  local result = M.render_transclusions(bufnr)
  -- ... handle result
end
```

## Data Flow

```
render_transclusions(bufnr)
  ↓
cache = get_cache(bufnr)  [buffer-local variable]
  ↓
for each token:
  ↓
  cache_key = get_cache_key(token.uuid, token.depth)
  ↓
  if cache[cache_key] exists:
    expanded_content = cache[cache_key]  [CACHE HIT]
  else:
    expand_result = domain_transclude.expand(...)
    expanded_content = expand_result.value
    cache[cache_key] = expanded_content  [CACHE MISS, store]
  ↓
  create_transclusion_extmark(...)
```

## Cache Strategy

**Cache location:**
- Buffer-local variable: `vim.b[bufnr].lifemode_transclusion_cache`
- Automatically cleared when buffer is deleted
- No manual cleanup needed

**Cache key:**
- Format: `"uuid"` or `"uuid:depth"`
- Simple string concatenation
- Collision-free (UUIDs are unique)

**Cache invalidation:**
- Explicit: `:LifeModeRefreshTransclusions` clears cache then re-renders
- Implicit: Buffer deletion clears (Neovim handles this)
- No time-based expiry (content changes are rare in typical workflow)

**Not implementing (future optimizations):**
- mtime checking (ROADMAP mentions this but adds complexity)
- Automatic invalidation on file save (would need file watchers)
- Cross-buffer cache sharing (each buffer independent)

## Performance Impact

**Without cache:**
- Every BufEnter: parse all tokens, expand all tokens, render
- For 10 transclusions: 10 expand() calls + 10 index lookups
- Expansion is recursive, could be expensive

**With cache:**
- First BufEnter: full expansion (cold cache)
- Subsequent BufEnter: cached values, skip expansion
- For 10 transclusions: 0 expand() calls, 0 index lookups (after first)
- BufEnter fires often (buffer switching, window splits), so this helps

## Integration Tests

### Test 1: Cache hit on second render
```lua
-- Given buffer with {{uuid-a}}
-- And node A exists in index
-- When render_transclusions(bufnr) called twice
-- Then second call uses cache (verify no index query)
```

### Test 2: Refresh clears cache
```lua
-- Given buffer with cached transclusions
-- When clear_cache(bufnr) called
-- Then cache is empty
-- And next render_transclusions() re-expands
```

### Test 3: Cache key generation
```lua
-- When get_cache_key("abc", nil)
-- Then returns "abc"
-- When get_cache_key("abc", 5)
-- Then returns "abc:5"
```

### Test 4: Buffer-local isolation
```lua
-- Given two buffers with same UUID transclusions
-- When render_transclusions(buf1)
-- Then buf2 cache is independent (not populated)
```

## Dependencies

**Existing:**
- `render_transclusions()` from Phase 33
- `domain_transclude.expand()` from Phase 32
- Buffer-local variables (Neovim API)

**No new external dependencies.**

## Notes

- This is pure performance optimization - no functional changes
- Cache is simple dict, no LRU or size limits (buffers typically small)
- ROADMAP mentions mtime checking but that's premature optimization
- Depth field in cache key is future-proofing (Phase 32 doesn't use it yet)
- Cache persists for buffer lifetime - cleared on buffer delete (automatic)
