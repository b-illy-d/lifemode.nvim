.PHONY: test test-all clean

NVIM := nvim --headless --noplugin -u tests/minimal_init.lua

test: test-all

test-all:
	@echo "Running all tests..."
	@for f in tests/test_*.lua; do \
		echo "  $$f"; \
		$(NVIM) -c "luafile $$f" -c "qa!" 2>&1 || exit 1; \
	done
	@echo ""
	@echo "All tests passed!"

test-phase1:
	@echo "Running Phase 1 tests..."
	@$(NVIM) -c "luafile tests/test_t01_acceptance.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t01_edge_cases.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t02_vault.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t02_vault_edge_cases.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t03_acceptance.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t03_edge_cases.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t05_metadata.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t05_metadata_edge_cases.lua" -c "qa!"
	@echo "Phase 1 tests passed!"

test-phase2:
	@echo "Running Phase 2 tests..."
	@$(NVIM) -c "luafile tests/test_t06_index_structure.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t07_index_build.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t08_lazy_index.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t09_incremental_update.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t09_autocommands.lua" -c "qa!"
	@echo "Phase 2 tests passed!"

test-phase3:
	@echo "Running Phase 3 tests..."
	@$(NVIM) -c "luafile tests/test_t02_acceptance.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t02_edge_cases.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t12_lens_basic.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t12_lens_edge_cases.lua" -c "qa!"
	@echo "Phase 3 tests passed!"

test-phase4:
	@echo "Running Phase 4 tests..."
	@$(NVIM) -c "luafile tests/test_t13_daily_tree.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t14_daily_render.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t15_daily_command.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t16_expand_collapse.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t17_date_navigation.lua" -c "qa!"
	@echo "Phase 4 tests passed!"

test-phase5:
	@echo "Running Phase 5 tests..."
	@$(NVIM) -c "luafile tests/test_t18_jump_to_source.lua" -c "qa!"
	@$(NVIM) -c "luafile tests/test_t19_return_to_view.lua" -c "qa!"
	@echo "Phase 5 tests passed!"

clean:
	@rm -rf /tmp/lifemode_test_*
