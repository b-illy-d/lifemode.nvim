.PHONY: test test-manual test-acceptance clean

test: test-manual test-acceptance

test-manual:
	@echo "Running manual tests..."
	@nvim --headless --noplugin -u NONE -c "luafile test_manual.lua" -c "qa!"
	@echo ""
	@echo "Running command tests..."
	@nvim --headless --noplugin -u NONE -c "luafile test_commands.lua" -c "qa!"

test-acceptance:
	@echo ""
	@echo "Running acceptance tests..."
	@nvim --headless --noplugin -u NONE -c "luafile test_acceptance.lua" -c "qa!"

clean:
	@rm -f test_manual.lua test_commands.lua test_acceptance.lua
