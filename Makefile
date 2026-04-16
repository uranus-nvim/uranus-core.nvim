# Uranus.nvim Makefile
#
# Provides convenient targets for building, testing, and developing Uranus.nvim
#
# Usage:
#   make          - Build the plugin
#   make test     - Run all tests
#   make dev      - Run in development mode
#   make clean    - Clean build artifacts
#
# Test categories:
#   make test-rust           - Run Rust tests
#   make test-rust-coverage  - Run Rust tests with coverage
#   make test-lua            - Run all Lua tests
#   make test-lua-no-kernel  - Run Lua tests (no Jupyter required)
#   make test-lua-kernel     - Run Lua tests (Jupyter required)

.PHONY: all build test test-e2e test-parsing test-runner clean dev help install-jupyter install-parsers test-jupyter-installer
.PHONY: test-rust test-rust-coverage test-lua test-lua-no-kernel test-lua-kernel
.PHONY: test-lua-runner test-lua-performance test-lua-integration test-lua-parsing
.PHONY: test-lua-modules test-lua-parallel test-lua-e2e test-lua-stdin test-lua-lsp

# Default target
all: build

# ============================================================================
# BUILD
# ============================================================================

build:
	@echo "Building Uranus Rust backend..."
	cargo build --release
	@echo "Copying library to lua directory..."
ifneq ($(OS),Windows)
ifeq ($(shell uname), Darwin)
	cp target/release/liburanus.dylib lua/uranus.so
else
	cp target/release/liburanus.so lua/uranus.so
endif
endif
	@echo "Build complete!"

# ============================================================================
# RUST TESTS
# ============================================================================

test-rust:
	@echo "Running Rust tests..."
	cargo test

test-rust-coverage:
	@echo "Running Rust tests with coverage..."
	cargo install cargo-tarpaulin 2>/dev/null || true
	cargo tarpaulin --out Html --output-dir coverage/rust

test-rust-clippy:
	@echo "Running Rust clippy..."
	cargo clippy -- -D warnings

test-rust-fmt:
	@echo "Running Rust fmt check..."
	cargo fmt --check

# ============================================================================
# LUA TESTS - NO KERNEL REQUIRED
# ============================================================================

test-lua-runner:
	@echo "Running Lua test runner..."
	nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_runner.lua" -c "qa!"

test-lua-performance:
	@echo "Running Lua performance tests..."
	nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_performance.lua" -c "qa!"

test-lua-integration:
	@echo "Running Lua integration tests..."
	nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_integration.lua" -c "qa!"

test-lua-parsing:
	@echo "Running Lua notebook parsing tests..."
	nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_notebook_parsing.lua" -c "qa!"

test-lua-modules:
	@echo "Running Lua module integration tests..."
	nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_integration_modules.lua" -c "qa!"

test-lua-parallel:
	@echo "Running Lua parallel execution tests..."
	nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_integration_parallel.lua" -c "qa!"

test-lua-jupyter-installer:
	@echo "Running Lua jupyter installer tests..."
	nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_jupyter_installer.lua" -c "qa!"

# Run all Lua tests that don't require Jupyter kernel
test-lua-no-kernel: test-lua-runner test-lua-performance test-lua-integration test-lua-parsing test-lua-modules test-lua-parallel test-lua-jupyter-installer
	@echo "All Lua tests (no kernel) complete!"

# ============================================================================
# LUA TESTS - REQUIRES KERNEL
# ============================================================================

test-lua-e2e:
	@echo "Running Lua E2E tests (requires kernel)..."
	nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_integration_e2e.lua" -c "qa!"

test-lua-stdin:
	@echo "Running Lua stdin tests (requires kernel)..."
	nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_stdin.lua" -c "qa!"

test-lua-lsp:
	@echo "Running Lua LSP tests (optional kernel)..."
	nvim --headless -u tests/minimal_init.lua -c "luafile tests/test_lsp.lua" -c "qa!"

# Run all Lua tests that require Jupyter kernel
test-lua-kernel: test-lua-e2e test-lua-stdin
	@echo "All Lua tests (kernel) complete!"

# ============================================================================
# AGGREGATED TEST TARGETS
# ============================================================================

# Run all Lua tests (no kernel + kernel)
test-lua: test-lua-no-kernel test-lua-kernel
	@echo "All Lua tests complete!"

# Run all tests (build + rust + lua)
test-all: build test-rust test-lua
	@echo "All tests complete!"

# Legacy: Run all tests (original behavior)
test:
	@echo "Running all tests..."
	nvim --headless -c "luafile tests/run_tests_plenary.lua" -c "qa!"

# ============================================================================
# DEVELOPMENT
# ============================================================================

dev:
	@echo "Starting development mode..."
	@echo "Watching for changes and rebuilding..."
ifneq ($(OS),Windows)
	cp target/release/liburanus.dylib lua/uranus.so 2>/dev/null || cp target/release/liburanus.so lua/uranus.so
endif

clean:
	@echo "Cleaning build artifacts..."
	cargo clean
	rm -f lua/uranus.so
	rm -f target/release/liburanus.*
	@echo "Clean complete!"

# ============================================================================
# SETUP
# ============================================================================

install-jupyter:
	@echo "Installing Jupyter..."
ifneq ($(OS),Windows)
	uv venv .venv && .venv/bin/activate && uv add jupyter notebook ipykernel || \
	python3 -m venv .venv && .venv/bin/pip install jupyter notebook ipykernel || \
	python3 -m pip install --break-system-packages jupyter notebook ipykernel
else
	python -m venv .venv && .venv\Scripts\pip install jupyter notebook ipykernel
endif
	@echo "Jupyter installed!"

install-parsers:
	@echo "Installing required Treesitter parsers..."
	nvim --headless -c "TSInstallSync python json markdown" -c "qa!"
	@echo "Parsers installed!"

setup: install-jupyter install-parsers build
	@echo "Setup complete!"

# ============================================================================
# HELP
# ============================================================================

help:
	@echo "Uranus.nvim Makefile"
	@echo ""
	@echo "Build targets:"
	@echo "  all (default)      - Build the plugin"
	@echo "  build             - Build Rust backend"
	@echo ""
	@echo "Rust test targets:"
	@echo "  test-rust         - Run Rust tests"
	@echo "  test-rust-coverage - Run Rust tests with coverage"
	@echo "  test-rust-clippy  - Run clippy linter"
	@echo "  test-rust-fmt     - Check formatting"
	@echo ""
	@echo "Lua test targets (no kernel required):"
	@echo "  test-lua-runner   - Run basic test runner"
	@echo "  test-lua-performance - Run performance tests"
	@echo "  test-lua-integration - Run integration tests"
	@echo "  test-lua-parsing  - Run notebook parsing tests"
	@echo "  test-lua-modules  - Run module integration tests"
	@echo "  test-lua-parallel - Run parallel execution tests"
	@echo "  test-lua-jupyter-installer - Run jupyter installer tests"
	@echo "  test-lua-no-kernel - Run all Lua tests (no kernel)"
	@echo ""
	@echo "Lua test targets (requires kernel):"
	@echo "  test-lua-e2e      - Run end-to-end tests"
	@echo "  test-lua-stdin    - Run stdin tests"
	@echo "  test-lua-lsp      - Run LSP tests"
	@echo "  test-lua-kernel   - Run all Lua tests (requires kernel)"
	@echo ""
	@echo "Aggregated test targets:"
	@echo "  test-lua          - Run all Lua tests"
	@echo "  test-all          - Run all tests (build + rust + lua)"
	@echo "  test              - Run legacy plenary tests"
	@echo ""
	@echo "Development targets:"
	@echo "  dev               - Development mode with watch"
	@echo "  clean             - Clean build artifacts"
	@echo "  install-jupyter   - Install Jupyter dependencies"
	@echo "  install-parsers   - Install Treesitter parsers"
	@echo "  setup             - Full development setup"
	@echo ""
	@echo "  help              - Show this help"
	@echo ""
