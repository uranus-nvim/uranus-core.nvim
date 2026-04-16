# Uranus.nvim

## Requirements
- **Neovim ≥ 0.11.4** (checked in `plugin/uranus.lua:10`)
- **Rust toolchain** for building backend
- **Jupyter** auto-installed on first load (set `URANUS_AUTO_INSTALL_JUPYTER=0` to disable)

## Build

```bash
cargo build --release
cp target/release/liburanus.dylib lua/uranus.so  # macOS
# Linux: .so -> .so
```

## Loading
```vim
set runtimepath+=~/path/to/uranus-core.nvim
```
```lua
local uranus = require("uranus")
uranus.start_backend()
```

## Architecture
- **Lua frontend** (`lua/uranus/*.lua`): UI, commands, lazy-loading
- **Rust backend** (`src/*.rs`): Jupyter kernel communication via ZeroMQ
- **FFI**: nvim-oxi (no msgpack-RPC)

## Key Technical Details

**ZeroMQ sockets required for stdout/stderr**: shell, iopub, control, stdin — without all four, IOPub broadcasting fails.

**stdin handling**: Set `allow_stdin=true` in ExecuteRequest; for IPython headless input, override:
```lua
def _fake_input(prompt, ident, parent, password=False): return "my_answer"
get_ipython().kernel._input_request = _fake_input
```

## Testing

```bash
nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/test_runner.lua')" -c "qa!"
nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/test_performance.lua')" -c "qa!"
nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/test_integration.lua')" -c "qa!"
```

## Key Modules
- `lua/uranus/config.lua` — Centralized config with observers
- `lua/uranus/factory.lua` — Lazy-loading factory
- `lua/uranus/state.lua` — Global state with watchers
- `lua/uranus/notebook_ui.lua` — Jupyter-like modal interface
- `lua/uranus/lsp.lua` — LSP integration (connects to existing pyright/ruff)

## Performance Notes
- Global Tokio runtime (no per-execution spawn)
- Connection pooling for kernel persistence
- 60fps output batching (16ms interval)
- LRU cache with O(1) eviction
- Enable `vim.loader.enable(true)` for 60-80% faster require