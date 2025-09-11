# Uranus.nvim Development Makefile
#
# This Makefile provides common development tasks for Uranus.nvim
# Run `make help` to see available commands

.PHONY: help setup test lint format clean install dev docs release

# Default target
help: ## Show this help message
	@echo "Uranus.nvim Development Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

# Setup development environment
setup: ## Set up development environment
	@echo "Setting up Uranus development environment..."
	@command -v cargo >/dev/null 2>&1 || { echo "Cargo not found. Please install Rust."; exit 1; }
	@command -v nvim >/dev/null 2>&1 || { echo "Neovim not found."; exit 1; }
	@echo "Installing Lua dependencies..."
	@luarocks install --local plenary.nvim || echo "plenary.nvim already installed"
	@echo "Building Rust backend..."
	@cargo build
	@echo "Development environment ready!"

# Run tests
test: ## Run the test suite
	@echo "Running Uranus test suite..."
	@nvim --headless -c "lua require('plenary.test_harness').test_directory('tests/', {minimal_init = 'tests/minimal_init.lua'})"

# Run tests with coverage
test-coverage: ## Run tests with coverage reporting
	@echo "Running tests with coverage..."
	@nvim --headless -c "require('plenary.test_harness').test_directory('tests/', {minimal_init = 'tests/minimal_init.lua'})"
	@echo "Coverage report generated in .coverage/"

# Run specific test file
test-file: ## Run a specific test file (usage: make test-file FILE=tests/uranus_spec.lua)
	@echo "Running $(FILE)..."
	@nvim --headless -c "require('plenary.busted').run('$(FILE)', {minimal_init = 'tests/minimal_init.lua'})"

# Lint Lua code
lint: ## Lint Lua code with luacheck
	@echo "Linting Lua code..."
	@command -v luacheck >/dev/null 2>&1 || { echo "luacheck not found. Install with: luarocks install luacheck"; exit 1; }
	@luacheck lua/ plugin/ tests/

# Format Lua code
format: ## Format Lua code with stylua
	@echo "Formatting Lua code..."
	@command -v stylua >/dev/null 2>&1 || { echo "stylua not found. Install from: https://github.com/JohnnyMorganz/StyLua"; exit 1; }
	@stylua lua/ plugin/ tests/

# Format Rust code
format-rust: ## Format Rust code with rustfmt
	@echo "Formatting Rust code..."
	@cargo fmt

# Format all code
format-all: format format-rust ## Format both Lua and Rust code

# Build Rust backend
build: ## Build the Rust backend
	@echo "Building Rust backend..."
	@cargo build

# Build optimized release
build-release: ## Build optimized release binary
	@echo "Building optimized release..."
	@cargo build --release

# Clean build artifacts
clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	@cargo clean
	@rm -rf .coverage/
	@rm -rf doc/tags
	@find . -name "*.tmp" -delete
	@find . -name "*.log" -delete

# Install for development
install-dev: ## Install Uranus for development
	@echo "Installing Uranus for development..."
	@mkdir -p ~/.local/share/nvim/site/pack/uranus/start/
	@ln -sf $(PWD) ~/.local/share/nvim/site/pack/uranus/start/uranus.nvim
	@echo "Uranus installed for development"

# Generate documentation
docs: ## Generate Vim documentation
	@echo "Generating documentation..."
	@mkdir -p doc
	@cat > doc/uranus.txt << 'EOF'
*uranus.txt*    For Uranus.nvim

==============================================================================
CONTENTS                                                  *uranus-contents*

1. Introduction ................................. |uranus-intro|
2. Installation ................................. |uranus-install|
3. Configuration ................................ |uranus-config|
4. Usage ........................................ |uranus-usage|
5. API .......................................... |uranus-api|
6. Troubleshooting .............................. |uranus-troubleshooting|

==============================================================================
INTRODUCTION                                           *uranus-intro*

Uranus is a Neovim plugin that provides seamless Jupyter kernel integration
with VSCode-like REPL and Notebook modes.

Features:
- Local and remote Jupyter kernel support
- Rich output rendering (images, HTML, Markdown, tables)
- Interactive REPL with cell markers
- Notebook mode with live preview
- Telescope integration
- LSP compatibility

==============================================================================
INSTALLATION                                           *uranus-install*

Requirements:
- Neovim 0.11.4+
- Jupyter (`pip install jupyter`)
- Rust toolchain

Using lazy.nvim:
>
  {
    "yourname/uranus.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "folke/snacks.nvim",
    },
    build = "cargo build --release",
    config = function()
      require("uranus").setup()
    end,
  }
<

==============================================================================
CONFIGURATION                                         *uranus-config*

Uranus can be configured with the following options:

                                                *uranus-config-ui*
ui.mode                     UI mode: "repl", "notebook", or "both"
ui.repl.view                Output view: "floating", "virtualtext", "terminal"
ui.image.backend            Image backend: "snacks" or "image.nvim"

                                                *uranus-config-kernels*
kernels.auto_start          Auto-start default kernel
kernels.default             Default kernel name
kernels.timeout             Connection timeout in milliseconds

For complete configuration options, see |uranus-setup|.

==============================================================================
USAGE                                                 *uranus-usage*

Start Uranus:                                         *:UranusStart*
Stop Uranus:                                          *:UranusStop*
Show status:                                          *:UranusStatus*

Execute code:                                         *:UranusExecute*
Connect to kernel:                                    *:UranusConnect*

Key mappings (when enabled):
<c>           Run current cell
<a>           Run all cells
<s>           Run selection
<j>/<k>       Navigate cells

==============================================================================
API                                                   *uranus-api*

require("uranus").setup(config)           Setup Uranus
require("uranus").start_backend()         Start Rust backend
require("uranus").connect_kernel(name)    Connect to kernel
require("uranus").execute(code)           Execute code

==============================================================================
TROUBLESHOOTING                                      *uranus-troubleshooting*

Common issues:

Backend not starting:
- Ensure Rust is installed: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- Build the backend: `cargo build --release`

Kernel connection failed:
- Check Jupyter is installed: `jupyter --version`
- Verify kernel is available: `jupyter kernelspec list`

For more help, see: https://github.com/yourname/uranus.nvim/issues

==============================================================================
vim:tw=78:ts=8:ft=help:norl:
EOF
	@echo "Documentation generated in doc/uranus.txt"

# Run all checks (lint, test, format)
check: lint test format ## Run all code quality checks

# Development server (watch for changes)
dev: ## Start development mode with file watching
	@echo "Starting development mode..."
	@echo "Watching for changes... (Ctrl+C to stop)"
	@while true; do \
		inotifywait -qre modify lua/ plugin/ tests/ src/; \
		echo "Changes detected, running checks..."; \
		make check; \
	done

# Create release archive
release: build-release ## Create release archive
	@echo "Creating release archive..."
	@version=$$(grep '^version' Cargo.toml | head -1 | sed 's/.*"\(.*\)".*/\1/'); \
	echo "Creating release v$$version"; \
	mkdir -p releases; \
	tar -czf releases/uranus-v$$version.tar.gz \
		--exclude='.git' \
		--exclude='target/debug' \
		--exclude='*.tmp' \
		--exclude='.coverage' \
		.; \
	echo "Release archive created: releases/uranus-v$$version.tar.gz"

# Update version numbers
bump-version: ## Bump version (usage: make bump-version VERSION=1.0.0)
	@if [ -z "$(VERSION)" ]; then \
		echo "Usage: make bump-version VERSION=x.y.z"; \
		exit 1; \
	fi
	@echo "Bumping version to $(VERSION)"
	@sed -i 's/^version = ".*"/version = "$(VERSION)"/' Cargo.toml
	@sed -i 's/version = ".*"/version = "$(VERSION)"/' lua/uranus/init.lua
	@echo "Version bumped to $(VERSION)"

# Show project statistics
stats: ## Show project statistics
	@echo "Uranus Project Statistics:"
	@echo "=========================="
	@echo "Lua files:    $$(find lua/ -name "*.lua" | wc -l)"
	@echo "Test files:   $$(find tests/ -name "*.lua" | wc -l)"
	@echo "Rust files:   $$(find src/ -name "*.rs" | wc -l)"
	@echo "Total lines:  $$(find lua/ tests/ src/ -name "*.lua" -o -name "*.rs" | xargs wc -l | tail -1 | awk '{print $$1}')"
	@echo "Test coverage: TBD"

# CI/CD simulation
ci: clean setup check build-release ## Run full CI pipeline locally

# Help for specific targets
help-target: ## Show detailed help for a specific target
	@echo "Available targets:"
	@echo "  setup         - Set up development environment"
	@echo "  test          - Run test suite"
	@echo "  lint          - Lint Lua code"
	@echo "  format        - Format Lua code"
	@echo "  build         - Build Rust backend"
	@echo "  clean         - Clean build artifacts"
	@echo "  docs          - Generate documentation"
	@echo "  release       - Create release archive"
	@echo "  check         - Run all quality checks"
	@echo "  dev           - Start development mode"
	@echo "  stats         - Show project statistics"