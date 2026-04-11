# Uranus.nvim

## Requirements

- **Neovim ≥ 0.11.4** (checked in `plugin/uranus.lua:10`)
- **Rust toolchain** for the backend
- **Jupyter** is automatically installed on first plugin load if not present

## Architecture (Rust + Lua)

This is a Neovim plugin with a Rust backend, similar to [molten-nvim](https://github.com/benlubas/molten-nvim) but implemented in Rust:

- **Lua frontend** (`plugin/*.lua`): UI, lazy loading, user commands, auto Jupyter installation
- **Rust backend**: Actual Jupyter kernel communication via ZeroMQ using runtimelib + jupyter-protocol
- **Communication**: nvim-oxi FFI (no msgpack-RPC overhead)

## Foundation Libraries

| Crate | Docs | Purpose |
|-------|------|---------|
| [runtimelib](https://docs.rs/runtimelib/1.5.0) | [API](https://docs.rs/runtimelib/1.5.0/runtimelib/) | Kernel discovery, start, management over ZeroMQ |
| [jupyter-protocol](https://docs.rs/jupyter-protocol/1.4.0) | [API](https://docs.rs/jupyter-protocol/1.4.0/jupyter_protocol/) | Complete Jupyter messaging protocol |
| [nbformat](https://docs.rs/nbformat/1.2.2) | [API](https://docs.rs/nbformat/1.2.2/nbformat/) | Notebook parsing and serialization |
| [nvim-oxi](https://docs.rs/nvim-oxi/0.6.0) | [API](https://docs.rs/nvim-oxi/0.6.0/nvim_oxi/) | Neovim Rust plugin API |
| [jupyter-websocket-client](https://crates.io/crates/jupyter-websocket-client) | [API](https://docs.rs/jupyter-websocket-client/1.1.0) | Remote kernel WebSocket connection |
| [reqwest](https://docs.rs/reqwest/0.12) | [API](https://docs.rs/reqwest/0.12.0) | HTTP client for Jupyter Server API |

## Project Structure

```
plugin/uranus.lua       -- Main entry, lazy loading, user commands, auto Jupyter install
lua/uranus.so          -- Compiled Rust backend (cdylib)
lua/uranus/output.lua  -- Output rendering (virtual text, snacks.nvim)
lua/uranus/repl.lua    -- REPL mode with cell execution
lua/uranus/repl_buffer.lua -- Embedded REPL buffer window
lua/uranus/cell_mode.lua -- Modal cell editing
lua/uranus/ui.lua      -- UI components (snacks.nvim integration)
lua/uranus/notebook.lua -- Notebook module (.ipynb files)
lua/uranus/notebook_ui.lua -- Notebook UI (ipynb-style TUI)
lua/uranus/inspector.lua -- Variable inspector
lua/uranus/lsp.lua     -- LSP integration (connects to existing LSP)
src/                   -- Rust source
  lib.rs               -- Main library with nvim-oxi plugin entry
  kernel.rs            -- Kernel management using runtimelib
  remote.rs            -- Remote kernel via WebSocket (jupyter-websocket-client)
  protocol.rs          -- Jupyter protocol types
  execute.rs           -- Code execution via ZeroMQ
Cargo.toml             -- Rust dependencies
tests/                 -- Test suite
```

## Building

```bash
# Build Rust backend
cargo build --release

# Copy to lua directory (macOS: .dylib -> .so, Linux: .so -> .so)
cp target/release/liburanus.dylib lua/uranus.so
```

## Loading the Plugin

Add the project directory to Neovim's runtimepath:
```vim
set runtimepath+=~/path/to/uranus-core.nvim
```

Then in Lua:
```lua
local uranus = require("uranus")
uranus.start_backend()
uranus.list_kernels()  -- Returns kernels found via runtimelib
```

## Jupyter Auto-Installation

The plugin automatically checks for Jupyter on first load:
- `_check_jupyter()` - Checks if `jupyter_client` is available
- `_install_jupyter()` - Runs `pip3 install jupyter notebook ipykernel`
- `_ensure_jupyter()` - Prompts user if not found

Set `URANUS_AUTO_INSTALL_JUPYTER=0` to disable auto-install.

## Implementation Status

### Working Features (Phase 1 Complete)

- ✅ Kernel discovery via runtimelib
- ✅ Kernel connection and management
- ✅ Code execution with execution_count
- ✅ **stdout/stderr capture** via Stream messages
- ✅ Rich output (ExecuteResult with text/html/png/jpeg/svg)
- ✅ Error handling (ErrorOutput messages)
- ✅ Jupyter auto-installation
- ✅ **Rich output display** (virtual text, snacks.nvim)
- ✅ Output rendering (images, HTML, SVG in floating windows)

### Working Features (Phase 2 Complete)

- ✅ REPL module (`lua/uranus/repl.lua`)
- ✅ Cell marker parsing (`#%%`)
- ✅ Cell execution (`run_cell`, `run_all`, `run_selection`)
- ✅ Cell navigation (`next_cell`, `prev_cell`)
- ✅ Visual cell markers (extmarks)
- ✅ Keymaps for REPL mode (LeaderUr*)
- ✅ Plugin commands (UranusRunCell, UranusRunAll, etc.)

### Working Features (Phase 3 Complete)

- ✅ UI module (`lua/uranus/ui.lua`) with snacks.nvim integration
- ✅ Kernel picker (`pick_kernel`)
- ✅ Notifications (`notify`)
- ✅ Dashboard (`dashboard`)
- ✅ Status bar (`show_status`, `update_status`)
- ✅ Floating windows (`floating_window`)
- ✅ Image display (`show_image`)
- ✅ Debug view (`debug_view`)
- ✅ Commands: UranusPickKernel, UranusDebug, UranusUIStatus
- ✅ Keymaps: `<leader>urk` (pick kernel), `<leader>urd` (debug)

### Working Features (Notebook - COMPLETE)

- ✅ Notebook module (`lua/uranus/notebook.lua`)
- ✅ Native .ipynb parsing with nbformat
- ✅ Cell editing (#%% markers)
- ✅ Create/open/save .ipynb files
- ✅ Cell operations (insert, delete, toggle type)
- ✅ Execution with output capture
- ✅ Auto-detect .ipynb on open
- ✅ Table of Contents (markdown headings extraction)
- ✅ Cell navigation (j/k keys)

### Working Features (Inspector - COMPLETE)

- ✅ Variable inspector module (`lua/uranus/inspector.lua`)
- ✅ Kernel introspection via execute (type, value, docstring)
- ✅ Hover inspection at cursor
- ✅ Variable window (open/toggle)
- ✅ Commands: UranusInspectorOpen, UranusInspectorToggle, UranusInspectHover
- ✅ Keymap: `<leader>uji` toggle inspector

### Working Features (Additional)

- ✅ Cell folding (via vim foldmethod)
- ✅ Run indicators (execution state)
- ✅ Markdown rendering (headings, code blocks)

### Working Features (REPL Buffer - NEW)

- ✅ Embedded REPL buffer module (`lua/uranus/repl_buffer.lua`)
- ✅ Dedicated output window with streaming
- ✅ Execution history display
- ✅ Auto-scroll on output
- ✅ Commands: UranusREPLOpen, UranusREPLToggle, UranusREPLClear
- ✅ Keymap: `<leader>ure` toggle REPL

### Working Features (Modal Cell Mode - NEW)

- ✅ Modal cell editing module (`lua/uranus/cell_mode.lua`)
- ✅ Focus one cell at a time in isolated buffer
- ✅ Cell navigation (j/k, gg/G)
- ✅ Save cell changes back to notebook
- ✅ Commands: UranusCellMode, UranusCellEnter, UranusCellExit, UranusCellRun
- ✅ Keymap: `<leader>ucm` cell mode, `<leader>ucr` run

### Working Features (Auto Virtualenv - NEW)

- ✅ Virtualenv detection from file path (.venv, pyvenv.toml, poetry.lock)
- ✅ Auto kernel selection from detected environment
- ✅ Notebook.save_outputs() / load_outputs() for output persistence

### Working Features (Remote Kernel - NEW)

- ✅ Remote kernel support via Jupyter Server WebSocket
- ✅ `jupyter-websocket-client` crate for connecting to Jupyter servers
- ✅ `list_remote_kernels(server_url)` - discover remote kernels
- ✅ `connect_remote_kernel(server_url, kernel_id)` - connect to remote kernel
- ✅ Both local and remote kernels via unified KernelTrait interface

### Working Features (LSP Integration - NEW)

- ✅ LSP module (`lua/uranus/lsp.lua`) connects to **existing** LSP (no start/stop)
- ✅ Auto-detects any Python LSP (pyright, ty, ruff, etc.)
- ✅ Merges static type info (LSP) with runtime values (kernel)
- ✅ Commands: UranusLSPStatus, UranusLSPHover, UranusLSPDefinition, UranusLSPReferences, UranusLSPDiagnostics
- ✅ Keymaps: `<leader>uls` (status), `<leader>ulu` (hover), `<leader>ulg` (definition), `<leader>ulr` (references), `<leader>uld` (diagnostics)
- ✅ Inspector uses merged LSP + kernel info
- ✅ Extended LSP: workspace symbols, document symbols, rename, code actions
- ✅ Inlay hints support
- ✅ Folding ranges
- ✅ Call hierarchy (incoming/outgoing)
- ✅ Semantic tokens
- ✅ Caching for performance

### Working Features (Extended LSP - NEW)

- ✅ `workspace_symbols(query)` - Search workspace symbols
- ✅ `get_code_actions()` - Get available code actions
- ✅ `execute_code_action(action)` - Execute code action
- ✅ `toggle_inlay_hints()` - Toggle inlay hints
- ✅ `get_folding_ranges()` - Get folding ranges
- ✅ `incoming_calls()` / `outgoing_calls()` - Call hierarchy
- ✅ `get_document_symbols()` - Document symbols
- ✅ `get_semantic_tokens()` - Semantic tokens
- ✅ Commands: `:UranusLSPWorkspaceSymbols`, `:UranusLSPRename`, `:UranusLSPCodeAction`, `:UranusLSPFormat`, `:UranusLSPInlayHints`, `:UranusLSPDocSymbols`
- ✅ Keymaps: `<leader>ulw` (workspace), `<leader>uln` (rename), `<leader>ula` (action), `<leader>ulf` (format), `<leader>ulh` (inlay), `<leader>uld` (docs), `<leader>uli` (incoming), `<leader>ulo` (outgoing)

### Working Features (Completion - NEW)

- ✅ Completion module (`lua/uranus/completion.lua`)
- ✅ Kernel-aware completions (merge LSP + runtime variables)
- ✅ blink.cmp integration
- ✅ Commands: `:UranusKernelComplete`

### Working Features (Cache - NEW)

- ✅ Cache module (`lua/uranus/cache.lua`)
- ✅ TTL-based caching with memoization
- ✅ Max size limits and eviction

### Working Features (Remote Kernel UI - NEW)

- ✅ Remote module (`lua/uranus/remote.lua`)
- ✅ Start/stop remote kernels from Neovim
- ✅ List remote kernels
- ✅ Connect to Jupyter Server
- ✅ Commands: `:UranusRemoteConnect`, `:UranusRemoteList`, `:UranusRemoteStart`, `:UranusRemoteStop`, `:UranusRemoteManager`
- ✅ Keymaps: `<leader>urr` (connect), `<leader>url` (list), `<leader>urm` (manager)

### Working Features (Async Cell Execution - NEW)

- ✅ `run_all_async()` - Run cells sequentially with callbacks
- ✅ `run_all_parallel()` - Run cells in parallel (up to 4 concurrent)
- ✅ `run_cell_and_next()` - Run cell and auto-advance
- ✅ `run_cell_interruptible()` - Run with 10s timeout interrupt
- ✅ Config options: `async_execution`, `parallel_cells`, `max_parallel`

### Working Features (Notebook UI - LIKE ipynb.nvim) - NEW

- ✅ Notebook UI module (`lua/uranus.notebook_ui.lua`) - Jupyter-like modal interface
- ✅ **Modal Design** - Notebook mode ↔ Cell mode (like ipynb.nvim)
- ✅ **Cell Borders** with `[In/N]:` execution count display
- ✅ **Cell Navigation** via `]]` / `[[` motions
- ✅ **Cell Mode** - Isolated floating window for editing
- ✅ **Execution** - Execute cell, execute+next with auto-advance
- ✅ **Cell Operations** - Add, delete, move, toggle type
- ✅ **Cell Folding** - Fold/unfold cells
- ✅ **Shadow Buffer** - For LSP proxying
- ✅ **Auto-save** - Tracks dirty state
- ✅ **Action Hints** on cell borders
- ✅ **Commands**: UranusNotebookUIOpen, UranusNotebookUICellMode, UranusNotebookUIExecute, etc.
- ✅ **Keymaps**: `<Leader>kn` (execute), `<Leader>kN` (execute+next), `<Leader>k]` (next), etc.

### Working Features (Notebook UI Enhanced - ipynb.nvim FEATURES) - NEW

- ✅ **Auto-Hover Variable Inspector** - `K` key shows variable info at cursor (Jupyter inspect protocol)
- ✅ **LSP Integration** - Diagnostics per cell, formatting via LSP
- ✅ **Code Lens** - Shows `[In N]` execution count
- ✅ **Health Check** - `:UranusCheckHealth` built-in diagnostics
- ✅ **Inline Images** - PNG, SVG rendering in cells
- ✅ **Async Execution** - Sequential (`run_all_async`) or parallel (`run_all_parallel`, max 4 concurrent)
- ✅ **Execution Control** - `stop_execution()` to interrupt, `toggle_async_mode()` to switch mode
- ✅ **Treesitter Support** - Syntax highlighting via nvim-treesitter
- ✅ **New Commands**: UranusNotebookUIHover, UranusNotebookUIFormatCell, UranusNotebookUIRunAll, UranusNotebookUIRunParallel, UranusCheckHealth
- ✅ **New Keymaps**: `<Leader>ka` (run all async), `<Leader>kA` (run parallel), `<Leader>ku` (stop), `<Leader>ke` (format cell), `<Leader>ks` (health check), `K` (hover)

### Technical Details

The key to fixing stdout/stderr capture was creating **all four ZeroMQ sockets**:
- `shell` - for execute requests
- `iopub` - for streaming output (stdout/stderr)
- `control` - for kernel management
- `stdin` - for input requests

Without all four sockets, the kernel doesn't properly initialize IOPub broadcasting.

### stdin Support

The backend implements stdin handling through the ZeroMQ stdin socket:
- **stdin socket** - For InputRequest messages from the kernel
- **allow_stdin=true** - ExecuteRequest includes allow_stdin flag

Note: IPython has its own frontend detection. For input() in headless mode:

```lua
-- Override IPython's input handler for custom input
local result = u.execute([=[
def _fake_input(prompt, ident, parent, password=False):
    return "my_answer"

get_ipython().kernel._input_request = _fake_input
x = input('prompt: ')
]=])
```

## Testing

```bash
# Run all test suites
nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/test_runner.lua')" -c "lua dofile('tests/test_performance.lua')" -c "lua dofile('tests/test_integration.lua')" -c "qa!"

# Run individual test suites
nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/test_runner.lua')" -c "qa!"  # Basic: 20 tests
nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/test_performance.lua')" -c "qa!"  # Performance: 28 tests
nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/test_integration.lua')" -c "qa!"  # Integration: 18 tests
```

### Test Suites

| File | Tests | Description |
|------|-------|-------------|
| `test_runner.lua` | 20 | Basic module loading, function existence, backend operations |
| `test_performance.lua` | 28 | Cache TTL, O(1) LRU, batch processing, memoization, timing |
| `test_integration.lua` | 18 | Cross-module data flow, concurrent operations, configuration |

### Note on Backend Returns

The Rust backend (`uranus.so`) returns JSON strings. Tests handle both string and table formats.

## Test Files

```
tests/
  minimal_init.lua     -- Minimal Neovim init for testing
  uranus_spec.lua      -- Full test suite with busted
  test_runner.lua      -- Quick test runner script
  test_lsp.lua        -- LSP-specific tests
  run_tests.lua       -- Alternative test runner
```

## Performance Optimization

### Lua Module Optimizations

All Lua modules implement performance best practices:

- **vim.loader.enable()** - Enable bytecode caching for faster require()
- **Module-level caching** - Cache frequently accessed data at module scope
- **TTL-based cache invalidation** - Avoid stale data while reducing redundant lookups
- **Batch operations** - Group similar operations to reduce API calls
- **Debounced/throttled functions** - Prevent excessive LSP requests

### Module-Specific Optimizations

| Module | Optimizations |
|--------|---------------|
| `lsp.lua` | Client caching (2s TTL), reduced timeouts, single-client-first pattern |
| `cache.lua` | O(1) LRU eviction with order array, per-item TTL |
| `repl.lua` | Cell parsing cache (2s TTL), removed unused functions |
| `output.lua` | Batch virtual text updates (10ms delay), cached snacks check |
| `inspector.lua` | Variables cache (5s TTL), debounced hover |
| `notebook.lua` | Cache invalidation API |

### Recommended Neovim Settings

Add to your init.lua for optimal performance:

```lua
-- Enable bytecode caching (60-80% faster require)
vim.loader.enable(true)

-- Reduce garbage collection pause
vim.opt.gctime = 100
```