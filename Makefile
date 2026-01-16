.PHONY: test test-manual test-acceptance test-view clean

test: test-manual test-view test-acceptance

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

clean:
	@rm -f test_manual.lua test_commands.lua test_acceptance.lua test_view_creation.lua
