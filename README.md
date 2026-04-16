# Uranus.nvim

<div align="center">

**Just use Uranus!**

The fastest Neovim plugin for Jupyter notebooks — no Python, no hassle.

[![Neovim Version](https://img.shields.io/badge/Neovim-0.11.4+-blue.svg)](https://neovim.io/)
[![Rust](https://img.shields.io/badge/Rust-1.70+-orange.svg)](https://rust-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

*Because working with Jupyter notebooks in Neovim shouldn't feel like... you know.*

</div>

---

## Why Uranus?

Most Neovim Jupyter plugins are a pain to install:
- Require a Python backend
- Need complex setup with nvim-ipython or similar
- Don't work well with remote kernels

**Uranus Just Works™:**
- 🚀 Pure Rust backend — no Python process needed
- ⚡ Blazing fast with connection pooling and async execution
- 🔌 Local and remote kernels (Jupyter Server via WebSocket)
- 📓 Full notebook UI — Jupyter-like modal interface
- 🎨 Rich output — images, HTML, SVG inline
- 🧠 LSP integration — connects to your existing Python LSP

---

## Installation

Just add the plugin — everything else is automatic:

```lua
-- lazy.nvim (just one line!)
{ "yourname/uranus-core.nvim", ft = { "python", "ipynb" } }
```

**That's it!** Uranus will:
1. Auto-download the prebuilt binary on first use
2. Auto-install Jupyter if not found
3. Auto-start when you open a `.py` or `.ipynb` file

Or build from source (optional):

```lua
-- lazy.nvim with source build
{
  "yourname/uranus-core.nvim",
  build = "cargo build --release && cp target/release/liburanus.dylib lua/uranus.so",
  ft = { "python", "ipynb" },
}
```

---

## Requirements

- **Neovim ≥ 0.11**
- (Optional) **Rust** — only if building from source

---

## Quick Config

```lua
-- lazy.nvim
{
  "yourname/uranus-core.nvim",
  ft = { "python", "ipynb" },
  keys = {
    { "<leader>urc", "<cmd>UranusRunCell<cr>", desc = "Run cell" },
    { "<leader>ura", "<cmd>UranusRunAll<cr>", desc = "Run all" },
    { "<leader>urk", "<cmd>UranusPickKernel<cr>", desc = "Pick kernel" },
    { "<leader>kn", "<cmd>UranusNotebookUIExecute<cr>", desc = "Execute" },
  },
  config = function()
    require("uranus").setup({ auto_install_jupyter = true })
  end,
}
```

**Default keymaps:**
| Keymap | Action |
|--------|--------|
| `<leader>urc` | Run cell |
| `<leader>ura` | Run all cells |
| `<leader>urk` | Pick kernel |
| `<leader>kn` | Execute cell |
| `<leader>kN` | Execute + next |

---

## Features

### Core
- ✅ Local kernel discovery (runtimelib)
- ✅ Remote kernels via Jupyter Server (WebSocket)
- ✅ Code execution with stdout/stderr capture
- ✅ Rich output (text, HTML, images, SVG)
- ✅ Auto Jupyter installation

### Notebook UI (Jupyter-like)
- ✅ Modal interface — notebook mode + cell mode
- ✅ Cell borders with `[In/N]:` execution count
- ✅ Cell navigation (`]]` / `[[` motions)
- ✅ Cell folding
- ✅ Inline images (PNG, SVG)
- ✅ Async execution (sequential or parallel)
- ✅ Auto-hover variable inspection (`K` key)

### Development
- ✅ LSP integration (connects to existing pyright/ruff/etc.)
- ✅ blink.cmp completion (kernel + LSP merge)
- ✅ Variable inspector
- ✅ Health check command

---

## Configuration

```lua
require("uranus").setup({
  -- Auto-install Jupyter if not found (default: true)
  auto_install_jupyter = true,

  -- Enable async cell execution (default: false)
  async_execution = true,

  -- Parallel cells (default: false)
  parallel_cells = true,
  max_parallel = 4,

  -- Output display
  output = {
    use_virtual_text = true,
    use_snacks = true,
  },

  -- LSP settings
  lsp = {
    enabled = true,
    merge_with_kernel = true,
  },
})
```

---

## Usage

### Commands

```vim
:UranusStart              " Start backend
:UranusStatus             " Check status
:UranusListKernels        " List available kernels
:UranusConnect python3    " Connect to kernel
:UranusRunCell            " Run current cell
:UranusRunAll             " Run all cells
:UranusNotebookOpen       " Open notebook with UI
:UranusPickKernel         " Pick kernel via UI
:UranusCheckHealth        " Run diagnostics
```

### Lua API

```lua
local uranus = require("uranus")

uranus.setup()                                    -- Initialize
uranus.connect_kernel("python3")                -- Connect to kernel
uranus.execute("print('hello world')")          -- Execute code

-- Notebook operations
local nb = require("uranus.notebook_ui")
nb.open("notebook.ipynb")
nb.execute_cell()
nb.run_all_async()
```

---

## Performance

Uranus is optimized for speed:

- **Global Tokio runtime** — no per-execution spawn overhead
- **Connection pooling** — persistent kernel connections
- **Output batching** — 60fps virtual text updates
- **LRU cache** — O(1) eviction for completions/hover
- **Zero-copy messages** — minimal JSON parsing

Enable these in your `init.lua` for extra speed:

```lua
-- Enable bytecode caching (60-80% faster require)
vim.loader.enable(true)

-- Reduce GC pause
vim.opt.gctime = 100
```

---

## Architecture

```
┌─────────────────────────────────────┐
│             Neovim (Lua)            │
└─────────────────┬───────────────────┘
                  │ nvim-oxi FFI
┌─────────────────▼───────────────────┐
│         Uranus Backend (Rust)      │
│    runtimelib + jupyter-protocol   │
└─────────────────┬───────────────────┘
    ┌─────────────┴─────────────┐
    │                           │
┌───▼─────┐              ┌─────▼─────┐
│  Local  │              │  Remote   │
│ Kernel  │              │  Kernel   │
│(ZeroMQ) │              │(WebSocket)│
└─────────┘              └───────────┘
```

Built on battle-tested Rust crates:
- [runtimelib](https://docs.rs/runtimelib/1.5.0) — Kernel management
- [jupyter-protocol](https://docs.rs/jupyter-protocol/1.4.0) — Jupyter messaging
- [nvim-oxi](https://docs.rs/nvim-oxi/0.6.0) — Neovim FFI

---

## Roadmap

- [x] Core kernel integration
- [x] Notebook UI (modal interface)
- [x] LSP integration
- [x] Remote kernel support
- [ ] Prebuilt binaries (no cargo build)
- [ ] More kernel languages

---

## Acknowledgments

Inspired by:
- **ipynb.nvim** — Modal notebook UI
- **molten-nvim** — Rust-based Jupyter integration
- **snacks.nvim** — UI components
- **markview.nvim** — Markdown preview

---

<div align="center">

**Just use Uranus!**

[⭐ Star us](https://github.com/yourname/uranus.nvim) • [📖 Docs](https://uranus-nvim.dev) • [🐛 Issues](https://github.com/yourname/uranus.nvim/issues)

</div>