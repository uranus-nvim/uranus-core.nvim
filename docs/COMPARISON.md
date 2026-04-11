# Uranus.nvim vs ipynb.nvim Feature Comparison

## Overview

| Feature | Uranus.nvim (Current) | ipynb.nvim | Notes |
|---------|----------------------|------------|-------|
| **Core** | | | |
| Read .ipynb files | ✅ Basic | ✅ Complete | Both parse JSON |
| Write .ipynb files | ✅ Basic | ✅ Complete | |
| Cell navigation | ✅ ]]/[[, j/k | ✅ j/k, G, gg | |
| Cell editing | ✅ Cell mode (float) | ✅ Cell mode (buffer) | ipynb uses normal buffer |
| **Execution** | | | |
| Kernel execution | ✅ ZeroMQ | ✅ ZeroMQ | Both use jupyter_client |
| Output capture | ✅ Basic | ✅ Complete | Streams + execute_result |
| Async execution | ⚠️ Basic | ✅ Full | ipynb has better async |
| **UI** | | | |
| Cell borders | ✅ [In/N]: | ✅ [In/N]: | Very similar design |
| Virtual text output | ✅ | ✅ | |
| Image rendering | ⚠️ Via output.lua | ✅ Inline | Need integration |
| Floating windows | ✅ | ✅ | |
| **Advanced** | | | |
| Variable inspector | ⚠️ Separate module | ✅ Integrated | Need integration |
| LSP integration | ⚠️ Separate module | ✅ Complete | Need integration |
| Auto-hover | ❌ Not implemented | ✅ | ipynb has this |
| Cell folding | ⚠️ Basic vim fold | ✅ Via treesitter | |
| Code lens | ❌ Not implemented | ✅ | |
| Health check | ❌ Not implemented | ✅ | |
| **Performance** | | | |
| Caching | ✅ TTL-based | ✅ | |
| Shadow buffer | ✅ | ✅ | For LSP proxying |

## What's Done Better in Uranus

1. **Rust Backend** - nvim-oxi FFI for better performance
2. **Remote Kernel Support** - WebSocket via jupyter-websocket-client
3. **Modular Architecture** - Separate modules (repl, notebook, lsp, completion, cache)
4. **Cache Module** - TTL-based caching with O(1) LRU
5. **Multiple REPL Modes** - REPL buffer, cell mode, notebook UI

## What's Done Better in ipynb.nvim

1. **Variable Inspector Integration** - Full Jupyter inspect protocol + auto-hover
2. **LSP Cell Integration** - Diagnostics, completion embedded in cells
3. **Treesitter Integration** - Better syntax highlighting in cells
4. **Health Check** - Built-in diagnostics
5. **Code Lens** - Shows execution count as code lens
6. **Cell Formatting** - Via LSP format
7. **Complete Feature Set** - More polished overall

## Gap Analysis

### High Priority
- [ ] Variable inspector auto-hover in notebook UI
- [ ] LSP integration for cells (diagnostics, completion in cell mode)
- [ ] Image rendering inline

### Medium Priority
- [ ] Health check command
- [ ] Code lens for execution counts
- [ ] Better async execution handling
- [ ] Treesitter integration

### Low Priority
- [ ] Multi-language support (beyond Python)
- [ ] Document symbols in notebook
- [ ] Signature help

## Implementation Notes

ipynb.nvim uses a different approach:
- Cell mode opens actual buffer (not floating window)
- More invasive to Neovim's normal editing
- Better LSP integration (shadow buffer concept similar)

Uranus uses:
- Floating window for cell mode (less invasive)
- Modular approach across multiple files
- Rust backend for kernel communication