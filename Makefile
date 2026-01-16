.PHONY: test test-manual test-acceptance test-view test-t02 test-t03 clean

test: test-manual test-view test-acceptance test-t02 test-t03

test-manual:
	@echo "Running manual tests..."
	@nvim --headless --noplugin -u NONE -c "luafile test_manual.lua" -c "qa!"
	@echo ""
	@echo "Running command tests..."
	@nvim --headless --noplugin -u NONE -c "luafile test_commands.lua" -c "qa!"

test-view:
	@echo ""
	@echo "Running view creation tests..."
	@nvim --headless --noplugin -u NONE -c "luafile test_view_creation.lua" -c "qa!"

test-acceptance:
	@echo ""
	@echo "Running acceptance tests..."
	@nvim --headless --noplugin -u NONE -c "luafile test_acceptance.lua" -c "qa!"

test-t02:
	@echo ""
	@echo "Running T02 acceptance tests..."
	@nvim --headless --noplugin -u NONE -c "luafile test_t02_acceptance.lua" -c "qa!"

test-t03:
	@echo ""
	@echo "Running T03 acceptance tests..."
	@nvim --headless --noplugin -u NONE -c "luafile test_t03_acceptance.lua" -c "qa!"
	@echo ""
	@echo "Running T03 edge case tests..."
	@nvim --headless --noplugin -u NONE -c "luafile test_t03_edge_cases.lua" -c "qa!"

clean:
	@rm -f test_manual.lua test_commands.lua test_acceptance.lua test_view_creation.lua test_t02_acceptance.lua test_t03_acceptance.lua test_t03_edge_cases.lua
