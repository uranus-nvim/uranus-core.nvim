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

Uranus.nvim provides **Jupyter kernel integration** with real kernel communication:

### 🔌 Auto-Installation
- **Automatic Jupyter installation** on first plugin load
- **Prompt for installation** if Jupyter not found
- **Skip with** `URANUS_AUTO_INSTALL_JUPYTER=0` environment variable

### 🔬 REPL / Cell Mode
- **Cell marker parsing** with `#%%` markers (extmarks)
- **Interactive execution** of code via ZeroMQ
- **Output display** (virtual text, floating windows)
- **Multi-language support** (any Jupyter kernel)

### 🌐 Kernel Management
- **Local kernel discovery** via runtimelib
- **Remote kernel support** via Jupyter Server WebSocket
- **Kernel connection management** 
- **Process-based kernel control** (start/stop)
- **ZeroMQ communication** with actual kernels

### 📓 Notebook UI (Jupyter-like TUI)
- **Modal interface** - Notebook mode + Cell mode (like ipynb.nvim)
- **Visual cell borders** with `[In/N]:` execution count
- **Cell folding** - Collapse/expand cells
- **Action hints** on cell borders
- **Shadow buffer** for LSP proxying
- **Auto-hover** variable inspection (Jupyter inspect protocol)
- **LSP integration** - Diagnostics, formatting, code actions
- **Code lens** - Execution count display
- **Health check** - Built-in diagnostics
- **Inline images** - PNG, SVG rendering
- **Async execution** - Sequential or parallel cell execution
- **Treesitter support** - Syntax highlighting in cells

### 🔧 Development Features
- **nvim-oxi FFI** between Lua and Rust
- **runtimelib** for kernel management
- **jupyter-protocol** for message handling
- **Configuration system** with validation

---

## 📦 Installation

### Requirements

- **Neovim ≥ 0.11.4**
- **Jupyter** - Automatically installed on first plugin load if not present

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

3. **Copy to lua directory:**
   ```bash
   # macOS
   cp target/release/liburanus.dylib lua/uranus.so
   
   # Linux
   cp target/release/liburanus.so lua/uranus.so
   ```

4. **Add to Neovim runtimepath:**
   ```vim
   " In your init.lua or vimrc
   set runtimepath+=~/path/to/uranus.nvim
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

#### REPL Commands
```vim
:UranusRunCell       " Run current cell
:UranusRunAll        " Run all cells
:UranusRunSelection  " Run visual selection
:UranusNextCell      " Go to next cell
:UranusPrevCell      " Go to previous cell
:UranusInsertCell    " Insert cell marker
:UranusMarkCells     " Mark cells in buffer
```

#### UI Commands
```vim
:UranusPickKernel    " Pick kernel via UI
:UranusDebug         " Show debug info
:UranusUIStatus      " Update status bar
```

#### Keymaps
```lua
-- REPL mode
<leader>urc  -- Run cell
<leader>ura  -- Run all cells
<leader>urn  -- Next cell
<leader>urp  -- Previous cell
<leader>uri  -- Insert cell
<leader>ure  -- Run selection (also REPL buffer)

-- UI
<leader>urk  -- Pick kernel
<leader>urd  -- Debug view

-- Notebook
<leader>ujn  -- New notebook
<leader>ujo  -- Open notebook
<leader>ujs  -- Save notebook
<leader>ujr  -- Run cell
<leader>uja  -- Run all
<leader>ujd  -- Delete cell
<leader>ujt  -- Toggle cell type
<leader>ujc  -- Clear output
<leader>ujt  -- TOC
<leader>uji  -- Inspector toggle

-- REPL Buffer
<leader>ure  -- Toggle REPL buffer
<leader>uec  -- Clear REPL

-- Modal Cell Mode
<leader>ucm  -- Toggle cell mode
<leader>ucr  -- Run cell in cell mode

-- Notebook UI (Jupyter-like TUI)
<leader>kn  -- Execute cell
<leader>kN  -- Execute and next
<leader>k]  -- Next cell
<leader>k[  -- Previous cell
<leader>kj  -- Go to cell
<leader>ki  -- Insert cell
<leader>kt  -- Toggle cell type
<leader>kl  -- Toggle fold
K       -- Show variable hover
<leader>kh  -- Hide hover
<leader>ke  -- Format cell via LSP
<leader>kE  -- Format all cells via LSP
<leader>ks  -- Health check
<leader>kH  -- Toggle auto-hover
<leader>kD  -- Toggle LSP diagnostics
<leader>kL  -- Toggle code lens
<leader>ka  -- Run all cells async
<leader>kA  -- Run all cells parallel
<leader>ku  -- Stop execution
<leader>km  -- Toggle async mode (seq/parallel)

-- LSP (connects to existing LSP)
<leader>uls  -- LSP status
<leader>ulu  -- Enhanced hover
<leader>ulg  -- Go to definition
<leader>ulr  -- References
<leader>uld  -- Diagnostics
<leader>ulw  -- Workspace symbols
<leader>uln  -- Rename
<leader>ula  -- Code actions
<leader>ulf  -- Format
<leader>ulh  -- Inlay hints
<leader>uli  -- Incoming calls
<leader>ulo  -- Outgoing calls

-- Completion
<leader>ucv  -- Kernel variables

-- Remote
<leader>urr  -- Remote connect
<leader>url  -- Remote list
<leader>urm  -- Remote manager
```

### Current Status
This implementation provides working kernel management and code execution via ZeroMQ.

- Kernel discovery: `list_kernels()` returns available Jupyter kernels
- Kernel connection: `connect_kernel(name)` starts and connects to a kernel
- Code execution: `execute(code)` runs code in the connected kernel
- **stdout/stderr capture**: Stream messages properly captured via all four ZeroMQ sockets
- Rich output: ExecuteResult with text/html/png/jpeg/svg support
- Error handling: ErrorOutput messages with traceback
- Jupyter auto-installation on first load
- **stdin support**: stdin ZeroMQ socket with allow_stdin=true
- **Rich output display**: Virtual text and snacks.nvim integration
- **Output rendering**: Images, HTML, SVG display in floating windows
- **Embedded REPL Buffer**: Dedicated output window with execution history
- **Modal Cell Mode**: Focus on one cell at a time
- **Variable Inspector**: Inspect variables at cursor
- **Table of Contents**: Navigate markdown headings
- **Auto Virtualenv**: Detect python environments automatically
- **Output Persistence**: Save/load cell outputs to .ipynb
- **Remote Kernel Support**: Connect to Jupyter Server via WebSocket
- **LSP Integration**: Connect to external ty language server
- **Extended LSP Features**: workspace symbols, code actions, inlay hints, call hierarchy
- **blink.cmp Integration**: Kernel-aware completions
- **Cache Module**: TTL-based caching for performance
- **Remote Kernel UI**: Start/stop kernels from Neovim
- **Async Cell Execution**: Parallel cell running with callbacks
- **Notebook UI (TUI)**: Jupyter-like modal interface with cell borders, auto-hover, LSP diagnostics, code lens, inline images

### Configuration Presets

```lua
-- Performance preset (faster execution)
require("uranus").setup({
  async_execution = true,
  parallel_cells = 4,
})

-- Output preset (rich display)
require("uranus.output").configure({
  use_virtual_text = true,
  use_snacks = true,
  max_image_width = 800,
})

-- Cache preset
require("uranus.cache").configure({
  max_size = 100,
  ttl = 30000,
})

-- LSP preset
require("uranus.lsp").configure({
  prefer_static = true,
  merge_with_kernel = true,
  use_cache = true,
  cache_ttl = 5000,
})

-- Remote preset
require("uranus.remote").configure({
  server_url = "http://localhost:8888",
  token = "",
})
```

### Tutorial: Working with Notebooks

```lua
local nb = require("uranus.notebook")

-- Open or create a notebook
nb.open("analysis.ipynb")

-- Run the current cell
nb.run_cell()

-- Run all cells
nb.run_all()

-- Navigate cells (j/k in notebook buffer)
nb.next_cell()
nb.prev_cell()

-- Insert cells
nb.insert_cell_below()
nb.insert_cell_above()

-- Delete current cell
nb.delete_cell()

-- Toggle cell type (code/markdown)
nb.toggle_cell_type()

-- Get table of contents
local toc = nb.get_toc()
nb.open_toc()

-- Save notebook
nb.save("analysis.ipynb")

-- Auto-detect notebook on file open
vim.api.nvim_create_autocmd({ "BufReadPost" }, {
  pattern = "*.ipynb",
  callback = function()
    require("uranus.notebook").open(vim.fn.expand("%:p"))
  end,
})
```

---

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
require("uranus").list_remote_kernels(url) -- List remote kernels (Jupyter Server)
require("uranus").connect_remote_kernel(url, kernel_id) -- Connect to remote kernel

-- Execution
require("uranus").execute(code)           -- Execute code string
require("uranus").execute_file(path)      -- Execute file
require("uranus").interrupt()            -- Interrupt execution

-- stdin support (for input() in headless mode)
local result = require("uranus").execute([=[
def _fake_input(prompt, ident, parent, password=False):
    return "my_answer"
get_ipython().kernel._input_request = _fake_input
x = input('prompt: ')
print(x)
]=])

-- Output rendering
require("uranus.output").display()     -- Display execution result
require("uranus.output").display_snacks() -- Display via snacks.nvim
require("uranus.output").display_virtual_text() -- Display inline text
require("uranus.output").display_image() -- Display image in floating window
require("uranus.output").display_html() -- Display HTML in floating window

### UI Module

```lua
local ui = require("uranus.ui")

ui.pick_kernel(kernels, on_select)    -- Pick kernel via UI
ui.notify(msg, level)                 -- Show notification
ui.dashboard(opts)                    -- Show dashboard
ui.show_status(status)                -- Show status in statusbar
ui.update_status()                   -- Update status bar
ui.floating_window(opts)              -- Create floating window
ui.show_image(path, opts)             -- Display image
ui.debug_view()                       -- Show debug info
ui.confirm(msg, on_confirm)          -- Show confirm dialog
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

-- File operations
notebook.open(path)               -- Open .ipynb file
notebook.new(name, path)          -- Create new notebook
notebook.save(path)              -- Save buffer to .ipynb

-- Cell operations
notebook.run_cell()               -- Run current cell
notebook.run_all()                -- Run all cells
notebook.get_current_cell()       -- Get cell at cursor
notebook.insert_cell_above()      -- Insert cell above
notebook.insert_cell_below()      -- Insert cell below
notebook.delete_cell()            -- Delete current cell
notebook.toggle_cell_type()       -- Toggle code/markdown
notebook.clear_output()           -- Clear cell output
notebook.render_markdown()        -- Render markdown highlighting
notebook.show_execution_state()   -- Show run indicator

-- Navigation
notebook.next_cell()             -- Go to next cell (j)
notebook.prev_cell()             -- Go to previous cell (k)
notebook.get_toc()               -- Get markdown headings
notebook.open_toc()              -- Open table of contents
```

### Inspector Module

```lua
local inspector = require("uranus.inspector")

inspector.inspect_at_cursor()    -- Inspect variable at cursor
inspector.show_hover(info)       -- Show hover float
inspector.open_inspector()       -- Open variable window
inspector.toggle_inspector()     -- Toggle inspector
inspector.close_inspector()      -- Close inspector
```

### REPL Buffer Module

```lua
local repl_buffer = require("uranus.repl_buffer")

repl_buffer.open()           -- Open REPL window
repl_buffer.toggle()         -- Toggle REPL window
repl_buffer.clear()         -- Clear REPL output
repl_buffer.write(text)      -- Write to REPL
repl_buffer.execute(code)     -- Execute code in REPL
repl_buffer.execute_cell()  -- Execute cell
```

### Modal Cell Mode Module

```lua
local cell_mode = require("uranus.cell_mode")

cell_mode.enter_cell_mode()   -- Enter isolated cell buffer
cell_mode.exit_cell_mode() -- Exit and save changes
cell_mode.toggle_cell_mode() -- Toggle cell mode
cell_mode.run_cell()      -- Run current cell
cell_mode.goto_cell(n)    -- Go to specific cell
cell_mode.save_cell()     -- Save cell back to notebook
```

### Notebook UI Module (ipynb-style TUI)

```lua
local nb_ui = require("uranus.notebook_ui")

-- Configuration
nb_ui.configure({
  auto_connect = false,
  show_outputs = true,
  auto_hover = {
    enabled = true,
    delay = 300,
    inspect = true,
  },
  lsp = {
    enabled = true,
    diagnostics = true,
    format_on_save = false,
  },
  code_lens = {
    enabled = true,
    show_execution_count = true,
  },
  images = {
    enabled = true,
    max_width = 800,
    max_height = 600,
    inline = true,
  },
  async = {
    enabled = true,
    parallel = false,
    max_parallel = 4,
    sequential_delay = 10,
  },
  treesitter = {
    enabled = false,
    auto_highlight = true,
    language = "python",
  },
  border_hints = {
    enabled = true,
    show_on_hover = true,
  },
})

-- File operations
nb_ui.open("notebook.ipynb")     -- Open with TUI
nb_ui.save()                     -- Save notebook

-- Cell mode (isolated editing)
nb_ui.enter_cell_mode()          -- Enter cell mode (isolated buffer)
nb_ui.exit_cell_mode()           -- Exit cell mode, save changes

-- Navigation
nb_ui.next_cell()                -- Go to next cell
nb_ui.prev_cell()                -- Go to previous cell
nb_ui.goto_cell(3)               -- Go to cell 3

-- Execution
nb_ui.execute_cell()             -- Execute current cell
nb_ui.execute_and_next()         -- Execute, move to next cell

-- Cell operations
nb_ui.add_cell_below()           -- Insert cell below
nb_ui.add_cell_above()           -- Insert cell above
nb_ui.delete_cell()              -- Delete current cell
nb_ui.toggle_cell_type()         -- Toggle code/markdown
nb_ui.move_cell_up()             -- Move cell up
nb_ui.move_cell_down()           -- Move cell down

-- Output
nb_ui.output()                   -- Open output in split
nb_ui.clear_output()              -- Clear cell output
nb_ui.clear_all_outputs()        -- Clear all outputs

-- Folding
nb_ui.fold_cell()                -- Fold current cell
nb_ui.unfold_cell()              -- Unfold current cell
nb_ui.fold_toggle()              -- Toggle fold

-- Variable Inspector (auto-hover)
nb_ui.show_hover_at_cursor()     -- Show variable hover at cursor
nb_ui.hide_hover()               -- Hide hover window
nb_ui.toggle_auto_hover()        -- Toggle auto-hover

-- LSP Integration
nb_ui.format_cell()              -- Format current cell via LSP
nb_ui.format_all_cells()         -- Format all cells via LSP
nb_ui.toggle_lsp_diagnostics()   -- Toggle LSP diagnostics display

-- Code Lens
nb_ui.toggle_code_lens()         -- Toggle execution count code lens

-- Health Check
nb_ui.health_check()             -- Run health check

-- Async Execution
nb_ui.execute_cell_async()       -- Execute cell asynchronously
nb_ui.run_all_async()            -- Run all cells sequentially
nb_ui.run_all_parallel()         -- Run all cells in parallel (max 4 concurrent)
nb_ui.stop_execution()          -- Stop running execution
nb_ui.toggle_async_mode()        -- Toggle sequential/parallel mode

-- Treesitter
nb_ui.enable_treesitter(enabled) -- Enable/disable treesitter
nb_ui.get_treesitter_status()    -- Get treesitter status
nb_ui.highlight_cell_syntax()    -- Apply syntax highlighting
```

### Notebooks (Legacy)

```lua
local notebook = require("uranus.notebook")

notebook.open(path)               -- Open .ipynb file
notebook.new(name, path)          -- Create new notebook
notebook.save(path)               -- Save buffer to .ipynb

### LSP Module

```lua
local lsp = require("uranus.lsp")

-- Configuration
lsp.configure({
    prefer_static = true,
    merge_with_kernel = true,
    use_cache = true,
    cache_ttl = 5000,
})

-- Check if any Python LSP is connected
lsp.is_available()  -- returns true/false

-- Get all connected Python LSP clients
lsp.get_clients()  -- returns array of LSP clients

-- Get status of connected LSPs
lsp.status()  -- returns { running = true/false, clients = {...} }

-- Get merged hover info (LSP + kernel)
lsp.hover(word)           -- returns merged LSP/kernel info
lsp.show_hover_enhanced(word) -- shows floating window

-- Get LSP-specific info
lsp.get_lsp_hover(word)        -- LSP only
lsp.get_lsp_definition(word)   -- LSP definition
lsp.get_lsp_references(word)   -- LSP references
lsp.get_lsp_completions()      -- LSP completions

-- Navigation functions
lsp.goto_definition()     -- Go to definition
lsp.goto_type_definition() -- Go to type definition
lsp.references()          -- Find references
lsp.implementation()       -- Find implementations

-- Extended navigation
lsp.workspace_symbols(query)   -- Search workspace symbols
lsp.get_document_symbols()      -- Document symbols
lsp.get_folding_ranges()      -- Folding ranges
lsp.incoming_calls()          -- Incoming call hierarchy
lsp.outgoing_calls()        -- Outgoing call hierarchy

-- Code actions
lsp.rename()              -- Rename symbol
lsp.rename_with_preview()  -- Rename with preview
lsp.code_action()         -- Show code actions
lsp.get_code_actions()    -- Get available code actions
lsp.execute_code_action() -- Execute code action
lsp.format()              -- Format document
lsp.hover()               -- Show LSP hover
lsp.signature_help()      -- Show signature help

-- Inlay hints
lsp.show_inlay_hints()    -- Show inlay hints
lsp.hide_inlay_hints()    -- Hide inlay hints
lsp.toggle_inlay_hints() -- Toggle inlay hints

-- Semantic tokens
lsp.get_semantic_tokens() -- Get semantic tokens
lsp.refresh_semantic_tokens() -- Refresh semantic tokens

-- Diagnostics
lsp.get_diagnostics()     -- Get buffer diagnostics
lsp.diagnostics()         -- Show diagnostic float
lsp.list_diagnostics()   -- Show quickfix list

-- Cache
lsp.clear_cache()        -- Clear LSP cache
lsp.cache_stats()       -- Get cache stats

-- Server info
lsp.server_info()       -- Get server info
```

### Completion Module

```lua
local completion = require("uranus.completion")

completion.configure({
    enable_kernel_completion = true,
    max_kernel_items = 20,
    priority_kernel = 50,
    priority_lsp = 100,
})

completion.get_kernel_completions(word)  -- Get kernel variable completions
completion.get_lsp_completions()    -- Get LSP completions
completion.get_all_completions(word) -- Merge kernel + LSP
completion.setup()                  -- Set up blink.cmp integration
completion.complete_kernel_variables() -- Complete all kernel variables
```

### Cache Module

```lua
local cache = require("uranus.cache")

cache.configure({
    max_size = 100,
    ttl = 30000,
    enabled = true,
})

cache.set(key, value, ttl)     -- Set cache entry
cache.get(key)              -- Get cache entry
cache.has(key)              -- Check if key exists
cache.invalidate(key)        -- Invalidate key
cache.clear()               -- Clear all cache
cache.size()               -- Get cache size
cache.keys()              -- Get all keys
cache.stats()              -- Get cache stats
cache.memoize(fn)          -- Create memoized function
```

### Remote Module

```lua
local remote = require("uranus.remote")

remote.configure({
    server_url = "http://localhost:8888",
    token = "",
})

remote.set_server(url)              -- Set server URL
remote.set_token(token)           -- Set authentication token
remote.list_servers()             -- List known servers
remote.connect_server(url)        -- Connect to server
remote.start_kernel(name, url)    -- Start remote kernel
remote.stop_kernel(kernel_id, url) -- Stop remote kernel
remote.list_remote_kernels(url)    -- List remote kernels
remote.pick_remote_kernel()        -- Show server picker
remote.show_manager()            -- Show manager UI
```

### LSP Commands

---

## 🏗️ Architecture

```
        ┌─────────────────────────────────────┐
        │             Neovim                  │
        │             (Lua)                   │
        └─────────────────┬───────────────────┘
                          │ nvim-oxi FFI
        ┌─────────────────▼───────────────────┐
        │         Uranus Backend (Rust)        │
        │         runtimelib + jupyter-protocol│
        └─────────────────┬───────────────────┘
           ┌──────────────┴──────────────┐
           │                             │
┌──────────▼─────────┐        ┌──────────▼─────────┐
│   Local Kernel     │        │   Remote Kernel    │
│   (ZeroMQ)         │        │   (WebSocket)      │
└────────────────────┘        └────────────────────┘
```

### Foundation Libraries

Uranus is built on these battle-tested Rust crates:

| Crate | Version | Purpose |
|-------|---------|---------|
| [runtimelib](https://docs.rs/runtimelib/1.5.0) | 1.5 | Jupyter kernel discovery, start, and management over ZeroMQ |
| [jupyter-protocol](https://docs.rs/jupyter-protocol/1.4.0) | 1.4 | Complete Jupyter messaging protocol implementation |
| [nbformat](https://docs.rs/nbformat/1.2.2) | 1.2 | Jupyter notebook parsing and serialization |
| [nvim-oxi](https://docs.rs/nvim-oxi/0.6.0) | 0.6 | Neovim Rust plugin API (FFI) |
| [jupyter-websocket-client](https://docs.rs/jupyter-websocket-client/1.1.0) | 1.1 | Remote kernel WebSocket connection to Jupyter Server |
| [tokio](https://crates.io/crates/tokio) | 1 | Async runtime for non-blocking kernel communication |

### Component Responsibilities

- **Lua Frontend**: UI, cell parsing with extmarks, output rendering (virtual text, floating windows)
- **Rust Backend**: Kernel management, code execution, protocol handling via runtimelib + jupyter-protocol
- **Output Module**: Rich output display via snacks.nvim virtual text for inline output
- **Local Kernels**: ZeroMQ connection using runtimelib for direct kernel communication
- **Remote Kernels**: WebSocket streaming via JupyterHub/JupyterLab

---

## 🗺️ Roadmap

### **Phase 1: Core Foundation (MVP) - Q1 2025** ✅ Complete
- [x] **Plugin Architecture Setup**
  - [x] Modern Neovim 0.11.4+ plugin structure
  - [x] Lua ↔ Rust nvim-oxi FFI communication
  - [x] Configuration validation system
  - [x] Error handling framework

- [x] **Kernel Integration with `runtimelib`**
  - [x] Local Jupyter kernel discovery using `runtimelib::list_kernelspecs()`
  - [x] Kernel startup/shutdown via `runtimelib::find_kernelspec()` and command()
  - [x] Basic code execution over ZeroMQ with runtimelib
  - [x] Text output rendering with jupyter-protocol message types
- [x] **stdout/stderr capture** via Stream messages (requires all four ZeroMQ sockets)
   - [x] **Jupyter auto-installation** on first plugin load

- [x] **Remote Kernel Support** (NOW COMPLETE!)
   - [x] WebSocket connections for remote kernels via `jupyter-websocket-client`
   - [x] Jupyter Server integration with HTTP API for kernel listing
   - [x] Authentication handling (token-based)

- [x] **Minimal REPL Mode**
  - [x] Cell marker parsing (`#%%`)
  - [x] Basic cell execution with `jupyter-protocol::ExecuteRequest`
  - [x] Simple output display using `jupyter-protocol::ExecuteReply`

### **Phase 2: Enhanced Features - Q2 2025** ✅ Complete
- [x] **Rich Output Rendering**
  - [x] Image display with snacks.nvim
  - [x] HTML rendering
  - [x] Virtual text integration
  - [x] SVG support
- [x] **UI System**
  - [x] Floating window outputs
  - [x] REPL module with cell markers
  - [x] Cell execution commands

- [x] **Notebook Mode with `nbformat`**
  - [x] Notebook parsing and creation using `nbformat::Notebook`
  - [x] Interleaved code + output with `nbformat::v4` cell parsing
  - [x] markview/render-markdown integration
  - [x] Live preview updates with `nbformat` cell execution

### **Phase 3: UI Enhancements with snacks.nvim - Q3 2025** ✅ Complete
- [x] **snacks.nvim Integration**
  - [x] Kernel picker with snacks.notifier
  - [x] Output dashboard with snacks.winbar
  - [x] Status visualization with snacks.statusbar
  - [x] Customizable UI components

- [x] **LSP Integration**
  - [x] LSP server management (ty)
  - [x] Completion via blink.cmp integration
  - [x] Hover information (LSP + kernel merge)
  - [x] Diagnostics display from ty language server

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

- [x] **User Experience**
  - [x] Default keymaps for `runtimelib` and `jupyter-protocol` operations
  - [x] Configuration presets for common `runtimelib` setups
  - [x] Tutorial/documentation with `nbformat` examples
  - [x] Community support and crate ecosystem integration

### **Future Enhancements (2026+)**
- [ ] **Advanced Features**
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
- ⚡ **Performance optimization**

### Performance Recommendations

Add to your `init.lua` for optimal performance:

```lua
-- Enable bytecode caching (60-80% faster require)
vim.loader.enable(true)

-- Reduce garbage collection pause
vim.opt.gctime = 100
```

### Key Caching Settings

All modules include performance optimizations:

- **LSP module**: Client caching with 2s TTL
- **Cache module**: O(1) LRU eviction
- **REPL module**: Cell parsing cache with 2s TTL  
- **Output module**: Batch virtual text updates (10ms delay)
- **Inspector module**: Variables cache with 5s TTL

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

Uranus.nvim draws heavy inspiration from these excellent projects:

- **ipynb.nvim** - Primary inspiration for the Notebook UI (modal architecture, cell borders, isolated cell editing, shadow buffer for LSP proxying)
- **molten-nvim** - Pioneer in Rust-based Jupyter integration for Neovim with nvim-oxi
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
