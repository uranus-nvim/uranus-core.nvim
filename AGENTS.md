# Uranus.nvim

## Requirements

- **Neovim ≥ 0.11.4** (checked in `plugin/uranus.lua:10`)
- **Rust toolchain** for the backend
- **Jupyter kernel** (e.g., python3, ir, julia) installed

## Architecture (Rust + Lua)

This is a Neovim plugin with a Rust backend, similar to [molten-nvim](https://github.com/benlubas/molten-nvim) but implemented in Rust:

- **Lua frontend** (`plugin/*.lua`): UI, cell parsing with extmarks, output rendering (virtual text, floating windows)
- **Rust backend**: Jupyter kernel communication, kernel management, async execution via runtimelib
- **Communication**: msgpack-RPC between Lua and Rust

## Foundation Libraries

| Crate | Docs | Purpose |
|-------|------|---------|
| [runtimelib](https://docs.rs/runtimelib/1.5.0) | [API](https://docs.rs/runtimelib/1.5.0/runtimelib/) | Kernel discovery, start, management over ZeroMQ |
| [jupyter-protocol](https://docs.rs/jupyter-protocol/1.4.0) | [API](https://docs.rs/jupyter-protocol/1.4.0/jupyter_protocol/) | Complete Jupyter messaging protocol |
| [nbformat](https://docs.rs/nbformat/1.2.2) | [API](https://docs.rs/nbformat/1.2.2/nbformat/) | Notebook parsing and serialization |

## Project Structure

```
plugin/uranus.lua       -- Main entry, lazy loading, user commands
src/                    -- Rust source
  lib.rs                -- Main library  
  kernel.rs             -- Kernel management (runtimelib)
  protocol.rs           -- Jupyter protocol (jupyter-protocol)
  execute.rs            -- Code execution
Cargo.toml              -- Rust dependencies
tests/                  -- Test suite (plenary.nvim)
```

## Commands

| Command | Description |
|---------|-------------|
| `:UranusStart` | Start backend |
| `:UranusStop` | Stop backend |
| `:UranusStatus` | Show status |
| `:UranusConnect <kernel>` | Connect to kernel |
| `:UranusExecute <code>` | Execute code |
| `:UranusListKernels` | List available kernels |
| `:UranusStartKernel <name>` | Start a kernel |

## Building

```bash
# Build Rust backend
cargo build --release

# Output: target/release/liburanus.{so|dylib}
```

## Testing

```bash
# Run tests with plenary.nvim
nvim --headless -u tests/minimal_init.lua -c "lua require('plenary.busted').run()"

# Or test specific file
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/uranus_spec.lua"
```

Tests cover:
- Plugin loading and version check
- Command registration
- Real kernel operations via runtimelib
- Actual code execution with jupyter-protocol message handling
- Cell mode parsing with extmarks
- Output rendering (virtual text, floating windows)