--- Uranus factory module
--- Centralized lazy-loading for common dependencies
--- Eliminates duplicate get_*() functions across modules
---
--- @module uranus.factory

local M = {}

--- Lazy-loaded module cache
local modules = {}

--- Lazy-load a module
---@param name string Module name (e.g., "uranus", "uranus.output")
---@return any? The loaded module or nil
local function require_module(name)
  if modules[name] ~= nil then
    return modules[name]
  end

  local ok, mod = pcall(require, name)
  if ok then
    modules[name] = mod
    return mod
  end

  return nil
end

--- Get the main uranus module (Rust backend bridge)
---@return table?
function M.get_uranus()
  return require_module("uranus")
end

--- Get the output module
---@return table?
function M.get_output()
  return require_module("uranus.ui.output")
end

--- Get the kernel module
---@return table?
function M.get_kernel()
  return require_module("uranus.kernel.kernel_manager")
end

--- Get the LSP module
---@return table?
function M.get_lsp()
  return require_module("uranus.lsp.lsp")
end

--- Get the notebook module
---@return table?
function M.get_notebook()
  return require_module("uranus.notebook.notebook")
end

--- Get the notebook UI module
---@return table?
function M.get_notebook_ui()
  return require_module("uranus.notebook.notebook_ui")
end

--- Get the REPL module
---@return table?
function M.get_repl()
  return require_module("uranus.ui.repl")
end

--- Get the UI module
---@return table?
function M.get_ui()
  return require_module("uranus.ui.ui")
end

--- Get the inspector module
---@return table?
function M.get_inspector()
  return require_module("uranus.ui.inspector")
end

--- Get the remote module
---@return table?
function M.get_remote()
  return require_module("uranus.remote.remote")
end

--- Get the kernel manager module
---@return table?
function M.get_kernel_manager()
  return require_module("uranus.kernel.kernel_manager")
end

--- Get the cache module
---@return table?
function M.get_cache()
  return require_module("uranus.kernel.cache")
end

--- Get the config module
---@return table?
function M.get_config()
  return require_module("uranus.core.config")
end

--- Get the state module
---@return table?
function M.get_state()
  return require_module("uranus.core.state")
end

--- Get snacks (optional dependency)
---@return table? snacks module if available
function M.get_snacks()
  return require_module("snacks")
end

--- Get telescope (optional dependency)
---@return table? telescope module if available
function M.get_telescope()
  return require_module("telescope")
end

--- Clear module cache (useful for testing)
function M.clear_cache()
  modules = {}
end

--- Pre-load specific modules (eager loading)
---@param names string[] Array of module names to pre-load
function M.preload(names)
  for _, name in ipairs(names) do
    require_module(name)
  end
end

return M