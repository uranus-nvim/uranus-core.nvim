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

Uranus.nvim provides **experimental Jupyter kernel integration** with foundational capabilities:

### 🔬 REPL / Cell Mode (In Development)
- **Cell marker parsing** with `#%%` markers (basic implementation)
- **Interactive execution** of code selections (foundation in place)
- **Basic output display** (currently simulating output for development)
- **Single language support** (Python-focused development)

### 🌐 Kernel Management (Foundation)
- **Local kernel discovery** via Jupyter runtime (using runtimelib)
- **Kernel connection management** (basic implementation)
- **Process-based kernel control** (start/stop)

### 🔧 Development Features
- **Msgpack-RPC communication** between Lua and Rust
- **Configuration system** with validation
- **Command interface** for kernel operations
- **Status reporting** and error handling

---

## 📦 Installation

### Requirements

- **Neovim ≥ 0.11.4**

### Manual Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/uranus.nvim.git
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
## 📖 Usage Guide (Development Preview)

### Basic Operations
The current implementation provides foundational kernel management and execution capabilities:

#### Starting the Backend
```vim
:UranusStart
```

#### Checking Status
```vim
:UranusStatus
```

#### Listing Available Kernels
```vim
:UranusListKernels
```

#### Connecting to a Kernel
```vim
:UranusConnect python3
```

#### Executing Code
```vim
:UranusExecute print("Hello, World!")
```

#### Stopping the Backend
```vim
:UranusStop
```

### Current Limitations (Development Stage)
Please note that this is an active development version with the following limitations:

- **Kernel Communication**: Currently simulating Jupyter protocol interactions (planned enhancement)
- **Code Execution**: Basic execution simulation (planned enhancement with real jupyter-protocol)
- **Output Display**: Limited to basic notifications (planned enhancement with virtual text/floating windows)
- **Cell Parsing**: Not yet implemented (planned enhancement with extmarks)
- **Notebook Mode**: Not yet implemented (planned enhancement)
- **Remote Kernels**: Not yet implemented (planned enhancement with jupyter-websocket-client)

These features are actively being developed to provide a complete Jupyter kernel integration experience.

---

## 🔧 Configuration
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
                          │ Msgpack-RPC Protocol
        ┌─────────────────▼───────────────────┐
        │         Uranus Backend (Rust)        │
        │                                     │
        └─────────────────┬───────────────────┘
           ┌──────────────┴──────────────┐
           │                             │
┌──────────▼─────────┐        ┌──────────▼─────────┐
│   Local Kernel     │        │   Remote Kernel  │
│   (ZeroMQ)         │        │   (WebSocket)    │
└────────────────────┘        └────────────────────┘
```

### Foundation Libraries

Uranus is built on these battle-tested Rust crates:

| Crate | Version | Purpose |
|-------|---------|---------|
| [runtimelib](https://docs.rs/runtimelib/1.5.0) | 1.5 | Jupyter kernel discovery, start, and management over ZeroMQ |
| [jupyter-protocol](https://docs.rs/jupyter-protocol/1.4.0) | 1.4 | Complete Jupyter messaging protocol implementation |
| [nbformat](https://docs.rs/nbformat/1.2.2) | 1.2 | Jupyter notebook parsing and serialization |
| [tokio](https://crates.io/crates/tokio) | 1 | Async runtime for non-blocking kernel communication |

### Component Responsibilities

- **Lua Frontend**: UI, cell parsing with extmarks, output rendering (virtual text, floating windows)
- **Rust Backend**: Kernel management, code execution, protocol handling via runtimelib + jupyter-protocol
- **Local Kernels**: ZeroMQ connection using runtimelib for direct kernel communication
- **Remote Kernels**: WebSocket streaming via JupyterHub/JupyterLab

### Msgpack-RPC Protocol

Uranus uses Neovim's standard msgpack-RPC for efficient communication between Lua and Rust, providing better performance than JSON for binary data and complex structures.

**Lua → Rust:**
```lua
{ method = "start_kernel", params = { kernel = "python3" } }
{ method = "connect", params = { conn_file = "/tmp/kernel-123.json" } }
{ method = "connect_remote", params = { server = "...", token = "...", kernel_id = "abc123" } }
{ method = "execute", params = { code = "print(2+2)" } }
{ method = "interrupt", params = {} }
```

**Rust → Lua:**
```lua
{ event = "kernel_started", data = { kernel = "python3" } }
{ event = "result", data = { stdout = "4\n" } }
{ event = "display_data", data = { mime = "image/png", base64 = "..." } }
{ event = "error", data = { ename = "NameError", evalue = "name 'x' is not defined" } }
{ event = "execution_state", data = { state = "busy" } }
```

---

## 🗺️ Roadmap

### **Phase 1: Core Foundation (MVP) - Q1 2025** ✅ 25% Complete
- [ ] **Plugin Architecture Setup**
  - [ ] Modern Neovim 0.11.4+ plugin structure
  - [ ] Lua ↔ Rust msgpack-RPC communication protocol
  - [ ] Configuration validation system
  - [ ] Error handling framework

- [ ] **Kernel Integration with `runtimelib`**
  - [ ] Local Jupyter kernel discovery using `runtimelib::list_kernelspecs()`
  - [ ] Kernel startup/shutdown via `runtimelib::KernelspecDir::command()`
  - [ ] Basic code execution over ZeroMQ with `runtimelib`
  - [ ] Text output rendering with `jupyter-protocol` message types

- [ ] **Remote Kernel Support with `jupyter-websocket-client`**
  - [ ] JupyterHub integration using `jupyter-websocket-client`
  - [ ] WebSocket connections for remote kernels
  - [ ] Authentication handling with `jupyter-websocket-client`
  - [ ] Remote server management and connection pooling

- [ ] **Minimal REPL Mode**
  - [ ] Cell marker parsing (`#%%`)
  - [ ] Basic cell execution with `jupyter-protocol::ExecuteRequest`
  - [ ] Simple output display using `jupyter-protocol::ExecuteReply`

### **Phase 2: Enhanced Features - Q2 2025** 🔄 In Progress
- [ ] **Rich Output Rendering with `jupyter-protocol`**
  - [ ] Image display with snacks.nvim using `jupyter-protocol::DisplayData`
  - [ ] HTML/Markdown rendering from `jupyter-protocol::Media`
  - [ ] Table formatting with `jupyter-protocol` data types
  - [ ] LaTeX/MathJax support for `jupyter-protocol::Media`

- [ ] **UI System**
  - [ ] Floating window outputs
  - [ ] Virtual text integration
  - [ ] Terminal/tmux output
  - [ ] Customizable layouts

- [ ] **Notebook Mode with `nbformat`**
  - [ ] Notebook parsing and creation using `nbformat::Notebook`
  - [ ] Interleaved code + output with `nbformat::v4` cell parsing
  - [ ] markview/render-markdown integration
  - [ ] Live preview updates with `nbformat` cell execution

### **Phase 3: Remote & Advanced Features - Q3 2025**
- [ ] **Telescope Integration**
  - [ ] Kernel selection picker with `runtimelib` kernel specs
  - [ ] Remote server picker with `jupyter-websocket-client` servers
  - [ ] Custom telescope extensions for kernel management

- [ ] **LSP Integration**
  - [ ] LSP server management
  - [ ] Completion in cells using kernel introspection
  - [ ] Diagnostics display from `jupyter-protocol::Error` messages
  - [ ] Hover information from kernel help system

### **Phase 4: Polish & Distribution - Q4 2025**
- [ ] **Quality Assurance**
  - [ ] Comprehensive test suite with `jupyter-protocol` message testing
  - [ ] Integration tests with `runtimelib` and `jupyter-websocket-client`
  - [ ] Performance benchmarks for ZeroMQ/WebSocket throughput
  - [ ] Documentation with crate-specific examples

- [ ] **Distribution**
  - [ ] Prebuilt Rust binaries with all crates bundled
  - [ ] Luarocks package with Rust dependencies
  - [ ] GitHub Actions CI/CD with crate testing
  - [ ] Release automation with dependency updates

- [ ] **User Experience**
  - [ ] Default keymaps for `runtimelib` and `jupyter-protocol` operations
  - [ ] Configuration presets for common `runtimelib` setups
  - [ ] Tutorial/documentation with `nbformat` examples
  - [ ] Community support and crate ecosystem integration

### **Future Enhancements (2026+)**
- [ ] **Multi-language Support**
  - [ ] Enhanced R kernel support with `runtimelib` R kernels
  - [ ] Julia kernel integration via `jupyter-protocol`
  - [ ] Custom kernel support with extensible `jupyter-protocol` types

- [ ] **Advanced Features**
  - [ ] Collaborative editing with `jupyter-websocket-client` multi-user
  - [ ] Version control integration with `nbformat` diffing
  - [ ] Plugin ecosystem for custom `jupyter-protocol` message handlers
  - [ ] Cloud deployment with `jupyter-websocket-client` scaling

- [ ] **Performance & Scale**
  - [ ] Large notebook handling with `nbformat` streaming
  - [ ] Memory optimization for `jupyter-protocol` message processing
  - [ ] Async processing with `runtimelib` concurrent kernel operations
  - [ ] Caching system for `jupyter-websocket-client` connections

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
git clone https://github.com/your-username/uranus.nvim.git
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

[⭐ Star us on GitHub](https://github.com/your-username/uranus.nvim) • [📖 Read the docs](https://uranus-nvim.dev) • [💬 Join the discussion](https://github.com/your-username/uranus.nvim/discussions)

</div>
