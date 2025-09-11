# Uranus.nvim

<div align="center">

**Seamless Jupyter kernel integration for Neovim**

[![Neovim Version](https://img.shields.io/badge/Neovim-0.11.4+-blue.svg)](https://neovim.io/)
[![Lua](https://img.shields.io/badge/Lua-5.1+-blue.svg)](https://lua.org/)
[![Rust](https://img.shields.io/badge/Rust-1.70+-orange.svg)](https://rust-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

*Like the planet Uranus, orbit between local and remote worlds 🌍🔭 — edit locally, run remotely, visualize everything in Neovim.*

</div>

---

## ✨ Features

Uranus.nvim provides **VSCode-like Jupyter integration** with two powerful modes:

### 🔬 REPL / Cell Mode
- **Cell execution** with `#%%` markers (configurable)
- **Interactive execution** of code selections
- **Rich output display** in floating windows, virtual text, or terminal
- **Multi-language support** (Python, R, Julia, etc.)

### 📓 Notebook Mode
- **Rendered notebooks** with interleaved code + outputs
- **Live markdown preview** with images, tables, and LaTeX
- **Multiple renderers** (markview, render-markdown)
- **Export capabilities** to various formats

### 🌐 Kernel Management
- **Local kernels** via Jupyter runtime discovery
- **Remote kernels** via JupyterHub/JupyterLab
- **WebSocket streaming** for real-time output
- **Telescope integration** for kernel selection

### 🎨 Rich Output Support
- **Images** rendered with `snacks.nvim`
- **HTML/Markdown** in floating windows
- **Tables** with syntax highlighting
- **LaTeX/MathJax** rendering
- **Interactive plots** and visualizations

---

## 📦 Installation

### Requirements

- **Neovim ≥ 0.11.4**
- **Jupyter** (`pip install jupyter`)
- **Rust toolchain** (for building the backend)
- **Optional**: `cargo install uranus-rs` for prebuilt binary

### Using lazy.nvim

```lua
{
  "yourname/uranus.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "folke/snacks.nvim",
    { "OXY2DEV/markview.nvim", optional = true },
    { "MeanderingProgrammer/render-markdown.nvim", optional = true },
  },
  build = function()
    -- Build Rust backend
    vim.fn.system("cargo build --release")
  end,
  config = function()
    require("uranus").setup({
      -- LSP integration
      lsp = {
        enable = true,
        server = "pyright", -- or "pylsp", "jedi"
      },

      -- UI configuration
      ui = {
        mode = "both", -- "repl" | "notebook" | "both"
        repl = {
          view = "floating", -- "floating" | "virtualtext" | "terminal"
          max_height = 20,
          max_width = 80,
        },
        image = {
          backend = "snacks", -- "snacks" | "image.nvim"
          max_width = 800,
          max_height = 600,
        },
        markdown_renderer = "markview", -- "markview" | "render-markdown"
      },

      -- Kernel configuration
      kernels = {
        auto_start = true,
        default = "python3",
        timeout = 10000, -- ms
        discovery_paths = {
          "~/.local/share/jupyter/runtime",
          "/tmp/jupyter/runtime",
        },
      },

      -- Remote servers
      remote_servers = {
        {
          name = "work",
          url = "http://jupyter.myserver.com:8888",
          token = os.getenv("JUPYTER_TOKEN"),
          headers = {},
        },
      },

      -- Cell configuration
      cell = {
        marker = "# %%", -- cell separator
        auto_execute = false,
        highlight = true,
      },

      -- Output configuration
      output = {
        max_lines = 1000,
        image_dir = vim.fn.stdpath("cache") .. "/uranus/images",
        cleanup_temp = true,
        cleanup_interval = 300000, -- 5 minutes
      },
    })
  end,
}
```

### Manual Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourname/uranus.nvim.git
   cd uranus.nvim
   ```

2. **Build the Rust backend:**
   ```bash
   cargo build --release
   ```

3. **Copy to Neovim config:**
   ```bash
   cp -r lua/uranus ~/.local/share/nvim/site/pack/manual/start/
   ```

---

## 🚀 Quick Start

### 1. Start the Backend

```lua
:lua require("uranus").start_backend()
```

### 2. Connect to a Kernel

```lua
-- Local kernel
:lua require("uranus").connect_kernel("python3")

-- Remote kernel
:lua require("uranus").connect_remote("http://localhost:8888", "your-token")
```

### 3. Execute Code

```python
# %% Cell marker
print("Hello from Uranus!")
```

```lua
-- Execute current cell
vim.keymap.set("n", "<leader>rc", function()
  require("uranus.repl").run_cell()
end)

-- Execute selection
vim.keymap.set("v", "<leader>rs", function()
  require("uranus.repl").run_selection()
end)
```

---

## 📖 Usage Guide

### REPL / Cell Mode

#### Cell Markers
Mark cells using configurable separators:

```python
# %% Data Loading
import pandas as pd
data = pd.read_csv("data.csv")

# %% Analysis
result = data.describe()

# %% Visualization
import matplotlib.pyplot as plt
plt.plot(data.x, data.y)
plt.show()
```

#### Keymaps
```lua
-- Cell operations
vim.keymap.set("n", "<leader>rc", require("uranus.repl").run_cell)
vim.keymap.set("n", "<leader>ra", require("uranus.repl").run_all)
vim.keymap.set("n", "<leader>rs", require("uranus.repl").run_selection)
vim.keymap.set("n", "<leader>rp", require("uranus.repl").run_to_cursor)

-- Navigation
vim.keymap.set("n", "<leader>rj", require("uranus.repl").next_cell)
vim.keymap.set("n", "<leader>rk", require("uranus.repl").prev_cell)
```

#### Output Display Options

**Floating Windows** (default):
- Rich formatting with borders
- Scrollable content
- Auto-positioning

**Virtual Text**:
- Inline output under code
- Compact display
- Less intrusive

**Terminal/Tmux**:
- External terminal integration
- Persistent output
- Better for long-running tasks

### Notebook Mode

#### Creating Notebooks
```lua
-- Convert current buffer to notebook
:lua require("uranus.notebook").create()

-- Open notebook from file
:lua require("uranus.notebook").open("notebook.ipynb")
```

#### Notebook Features
- **Interleaved display**: Code blocks with rendered outputs
- **Live updates**: Automatic re-rendering on execution
- **Multiple formats**: Support for images, tables, LaTeX
- **Export options**: Convert to various formats

Example notebook display:
````markdown
```python
# Data analysis cell
import pandas as pd
data = pd.read_csv("sales.csv")
print(data.head())
```

```
   date  sales  region
0  2023-01-01   1000   North
1  2023-01-02   1200   South
2  2023-01-03    800   East
```

```python
# Visualization cell
import matplotlib.pyplot as plt
plt.bar(data.region, data.sales)
plt.title("Sales by Region")
plt.show()
```

![Sales Chart](temp_chart.png)
````

### Remote Kernel Management

#### Connecting to Remote Servers
```lua
-- Add remote server
require("uranus.remote").add_server({
  name = "work-cluster",
  url = "https://jupyter.company.com:8443",
  token = "your-jupyter-token",
  headers = {
    ["X-Custom-Header"] = "value",
  },
})

-- Connect to remote kernel
require("uranus.remote").connect("work-cluster", "python3")
```

#### Telescope Integration
```lua
-- Browse local kernels
vim.keymap.set("n", "<leader>jl", function()
  require("uranus.telescope").kernels()
end)

-- Browse remote servers
vim.keymap.set("n", "<leader>jr", function()
  require("uranus.telescope").remote_servers()
end)

-- Browse remote kernels
vim.keymap.set("n", "<leader>jk", function()
  require("uranus.telescope").remote_kernels()
end)
```

---

## 🔧 Configuration

### Complete Configuration Example

```lua
require("uranus").setup({
  -- Core settings
  debug = false,
  log_level = "INFO",

  -- LSP integration
  lsp = {
    enable = true,
    server = "pyright",
    auto_attach = true,
    diagnostics = true,
  },

  -- UI customization
  ui = {
    mode = "both",
    theme = "auto", -- "light" | "dark" | "auto"
    icons = {
      kernel = "🧠",
      running = "⚡",
      success = "✅",
      error = "❌",
    },
    repl = {
      view = "floating",
      position = "auto", -- "auto" | "cursor" | "center"
      border = "rounded",
      title = "Uranus Output",
    },
    notebook = {
      renderer = "markview",
      live_update = true,
      show_line_numbers = true,
    },
  },

  -- Kernel management
  kernels = {
    auto_start = true,
    default = "python3",
    timeout = 10000,
    max_restarts = 3,
    discovery_paths = {
      "~/.local/share/jupyter/runtime",
      "~/.jupyter/runtime",
      "/tmp/jupyter/runtime",
    },
  },

  -- Remote configuration
  remote = {
    timeout = 15000,
    retry_attempts = 3,
    ssl_verify = true,
    proxy = os.getenv("HTTPS_PROXY"),
  },

  -- Cell configuration
  cell = {
    marker = "# %%",
    highlight = {
      enable = true,
      fg = "#ff6b6b",
      bg = "#f8f9fa",
    },
    folding = true,
    auto_save = true,
  },

  -- Output handling
  output = {
    max_lines = 1000,
    truncate_long_lines = true,
    image = {
      max_width = 800,
      max_height = 600,
      format = "png",
      quality = 90,
    },
    cleanup = {
      enable = true,
      interval = 300000, -- 5 minutes
      max_age = 3600000, -- 1 hour
    },
  },

  -- Keymaps
  keymaps = {
    enable = true,
    prefix = "<leader>u",
    mappings = {
      run_cell = "c",
      run_all = "a",
      run_selection = "s",
      next_cell = "j",
      prev_cell = "k",
      kernel_select = "k",
      notebook_toggle = "n",
    },
  },
})
```

### Configuration Validation

Uranus validates your configuration and provides helpful error messages:

```lua
-- Check configuration
local result = require("uranus").validate_config()
if not result.success then
  vim.notify("Uranus config error: " .. result.error, vim.log.levels.ERROR)
end
```

---

## 🔌 API Reference

### Core Functions

```lua
-- Plugin management
require("uranus").setup(config)           -- Initialize plugin
require("uranus").start_backend()         -- Start Rust backend
require("uranus").stop_backend()          -- Stop Rust backend
require("uranus").status()                -- Get plugin status

-- Kernel operations
require("uranus").connect_kernel(name)    -- Connect to local kernel
require("uranus").disconnect_kernel()     -- Disconnect current kernel
require("uranus").list_kernels()          -- List available kernels
require("uranus").current_kernel()        -- Get current kernel info

-- Execution
require("uranus").execute(code)           -- Execute code string
require("uranus").execute_file(path)      -- Execute file
require("uranus").interrupt()             -- Interrupt execution
```

### REPL Module

```lua
local repl = require("uranus.repl")

repl.run_cell()                          -- Run current cell
repl.run_all()                           -- Run all cells
repl.run_selection()                     -- Run visual selection
repl.run_to_cursor()                     -- Run to cursor position
repl.clear_outputs()                     -- Clear all outputs
repl.next_cell()                         -- Go to next cell
repl.prev_cell()                         -- Go to previous cell
```

### Notebook Module

```lua
local notebook = require("uranus.notebook")

notebook.create()                        -- Create notebook from buffer
notebook.open(path)                      -- Open notebook file
notebook.save(path)                      -- Save notebook
notebook.export(format)                  -- Export to format
notebook.toggle_preview()                -- Toggle live preview
```

### Remote Module

```lua
local remote = require("uranus.remote")

remote.add_server(config)               -- Add remote server
remote.remove_server(name)              -- Remove server
remote.list_servers()                    -- List servers
remote.connect(name, kernel)             -- Connect to remote
remote.disconnect()                      -- Disconnect remote
```

---

## 🏗️ Architecture

```
        ┌─────────────────────────────────────┐
        │             Neovim                  │
        │             (Lua)                   │
        └─────────────────┬───────────────────┘
                          │ JSON Protocol
        ┌─────────────────▼───────────────────┐
        │         Uranus Backend               │
        │           (Rust)                     │
        └─────────────────┬───────────────────┘
           ┌──────────────┴──────────────┐
           │                             │
┌──────────▼─────────┐        ┌─────────▼──────────┐
│   Local Kernel     │        │   Remote Kernel    │
│     (ZMQ)          │        │   (WebSocket)      │
└────────────────────┘        └────────────────────┘
```

### Component Responsibilities

- **Lua Frontend**: UI, cell parsing, output rendering, user interaction
- **Rust Backend**: Kernel communication, protocol handling, performance-critical operations
- **Local Kernels**: Direct ZMQ connection to Jupyter kernels
- **Remote Kernels**: WebSocket streaming via JupyterHub/JupyterLab

### JSON Protocol

**Lua → Rust:**
```json
{ "cmd": "start_kernel", "kernel": "python3" }
{ "cmd": "connect", "conn_file": "/tmp/kernel-123.json" }
{ "cmd": "connect_remote", "server": "...", "token": "...", "kernel_id": "abc123" }
{ "cmd": "execute", "code": "print(2+2)" }
{ "cmd": "interrupt" }
```

**Rust → Lua:**
```json
{ "event": "kernel_started", "kernel": "python3" }
{ "event": "result", "stdout": "4\n" }
{ "event": "display_data", "mime": "image/png", "base64": "..." }
{ "event": "error", "ename": "NameError", "evalue": "name 'x' is not defined" }
{ "event": "execution_state", "state": "busy" }
```

---

## 🗺️ Roadmap

### **Phase 1: Core Foundation (MVP) - Q1 2025** ✅ 15% Complete
- [ ] **Plugin Architecture Setup**
  - [ ] Modern Neovim 0.11.4+ plugin structure
  - [ ] Lua ↔ Rust JSON communication protocol
  - [ ] Configuration validation system
  - [ ] Error handling framework

- [ ] **Basic Kernel Integration**
  - [ ] Local Jupyter kernel discovery
  - [ ] Simple kernel startup/shutdown
  - [ ] Basic code execution
  - [ ] Text output rendering

- [ ] **Minimal REPL Mode**
  - [ ] Cell marker parsing (`#%%`)
  - [ ] Basic cell execution
  - [ ] Simple output display

### **Phase 2: Enhanced Features - Q2 2025** 🔄 In Progress
- [ ] **Rich Output Rendering**
  - [ ] Image display with snacks.nvim
  - [ ] HTML/Markdown rendering
  - [ ] Table formatting
  - [ ] LaTeX/MathJax support

- [ ] **UI System**
  - [ ] Floating window outputs
  - [ ] Virtual text integration
  - [ ] Terminal/tmux output
  - [ ] Customizable layouts

- [ ] **Notebook Mode**
  - [ ] Markdown buffer creation
  - [ ] Interleaved code + output
  - [ ] markview/render-markdown integration
  - [ ] Live preview updates

### **Phase 3: Remote & Advanced Features - Q3 2025**
- [ ] **Remote Kernel Support**
  - [ ] JupyterHub integration
  - [ ] WebSocket connections
  - [ ] Authentication handling
  - [ ] Remote server management

- [ ] **Telescope Integration**
  - [ ] Kernel selection picker
  - [ ] Remote server picker
  - [ ] Custom telescope extensions

- [ ] **LSP Integration**
  - [ ] LSP server management
  - [ ] Completion in cells
  - [ ] Diagnostics display
  - [ ] Hover information

### **Phase 4: Polish & Distribution - Q4 2025**
- [ ] **Quality Assurance**
  - [ ] Comprehensive test suite
  - [ ] Integration tests
  - [ ] Performance benchmarks
  - [ ] Documentation

- [ ] **Distribution**
  - [ ] Prebuilt Rust binaries
  - [ ] Luarocks package
  - [ ] GitHub Actions CI/CD
  - [ ] Release automation

- [ ] **User Experience**
  - [ ] Default keymaps
  - [ ] Configuration presets
  - [ ] Tutorial/documentation
  - [ ] Community support

### **Future Enhancements (2026+)**
- [ ] **Multi-language Support**
  - [ ] Enhanced R kernel support
  - [ ] Julia kernel integration
  - [ ] Custom kernel support

- [ ] **Advanced Features**
  - [ ] Collaborative editing
  - [ ] Version control integration
  - [ ] Plugin ecosystem
  - [ ] Cloud deployment

- [ ] **Performance & Scale**
  - [ ] Large notebook handling
  - [ ] Memory optimization
  - [ ] Async processing
  - [ ] Caching system

---

## 🤝 Contributing

We welcome contributions! See our [Contributing Guide](CONTRIBUTING.md) for details.

### Priority Areas
- 🦀 **Rust backend development**
- 🎨 **UI/UX improvements**
- 🔌 **Kernel protocol implementations**
- 🧪 **Testing and documentation**

### Getting Started
1. Fork the repository
2. Set up development environment (`make setup`)
3. Pick an issue from the roadmap
4. Submit a pull request

### Development Setup
```bash
# Clone and setup
git clone https://github.com/yourname/uranus.nvim.git
cd uranus.nvim

# Install dependencies
make setup

# Run tests
make test

# Build documentation
make docs
```

---

## 📞 Support & Community

- **📖 Documentation**: [Full Docs](https://uranus-nvim.dev)
- **🐛 Issues**: [GitHub Issues](https://github.com/yourname/uranus.nvim/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/yourname/uranus.nvim/discussions)
- **💻 Discord**: [Join our community](https://discord.gg/uranus-nvim)

---

## 🙏 Acknowledgments

- **snacks.nvim** - Image rendering and UI components
- **markview.nvim** - Markdown preview capabilities
- **render-markdown.nvim** - Alternative markdown rendering
- **telescope.nvim** - Fuzzy finding and selection
- **plenary.nvim** - Lua utilities and async support

---

## 📜 License

Licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">

**Made with ❤️ for the Neovim community**

[⭐ Star us on GitHub](https://github.com/yourname/uranus.nvim) • [📖 Read the docs](https://uranus-nvim.dev) • [💬 Join the discussion](https://github.com/yourname/uranus.nvim/discussions)

</div>
