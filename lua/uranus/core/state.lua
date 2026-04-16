--- Uranus state module
--- Centralized global state management
--- Provides cross-module state synchronization
---
--- @module uranus.state

local M = {}

--- Global state container
local state = {
  initialized = false,
  backend_running = false,
  current_kernel = nil,
  current_kernel_name = nil,
  active_notebook_buffers = {},
  notebook_ui_mode = "notebook",
  notebook_current_cell = 1,
  executing_cells = {},
  dirty_notebooks = {},
  ui = {
    inspector_open = false,
    repl_buffer_open = false,
    debug_view_open = false,
    status_visible = false,
  },
  last_error = nil,
  module_load_start = os.time(),
  module_load_end = nil,
}

--- State change callbacks
local watchers = {}

--- Subscribe to state changes
---@param key string State key to watch (e.g., "current_kernel")
---@param callback function Function to call on change
function M.watch(key, callback)
  if not watchers[key] then
    watchers[key] = {}
  end
  table.insert(watchers[key], callback)
end

--- Notify watchers of state change
local function notify(key, value)
  if watchers[key] then
    for _, callback in ipairs(watchers[key]) do
      callback(value, state[key])
    end
  end
end

--- Get the entire state or a specific key
---@param key? string Optional key to get specific value
---@return any State table or specific value
function M.get(key)
  if key then
    return state[key]
  end
  return state
end

--- Set a state value and notify watchers
---@param key string State key to set
---@param value any Value to set
function M.set(key, value)
  state[key] = value
  notify(key, value)
end

--- Update multiple state values at once
---@param updates table Key-value pairs to update
function M.update(updates)
  for key, value in pairs(updates) do
    state[key] = value
    notify(key, value)
  end
end

--- Check if plugin is initialized
---@return boolean
function M.is_initialized()
  return state.initialized
end

--- Mark plugin as initialized
function M.set_initialized()
  state.initialized = true
  state.module_load_end = os.time()
  notify("initialized", true)
end

--- Check if backend is running
---@return boolean
function M.is_backend_running()
  return state.backend_running
end

--- Set backend running state
---@param running boolean
function M.set_backend_running(running)
  state.backend_running = running
  notify("backend_running", running)
end

--- Get current kernel info
---@return table? { name, language, status }
function M.get_current_kernel()
  return state.current_kernel
end

--- Set current kernel
---@param kernel table? Kernel info { name, language, status }
function M.set_current_kernel(kernel)
  state.current_kernel = kernel
  state.current_kernel_name = kernel and kernel.name or nil
  notify("current_kernel", kernel)
end

--- Clear current kernel
function M.clear_current_kernel()
  state.current_kernel = nil
  state.current_kernel_name = nil
  notify("current_kernel", nil)
end

--- Register an active notebook buffer
---@param bufnr number Buffer number
---@param path string? Notebook file path
function M.register_notebook(bufnr, path)
  state.active_notebook_buffers[bufnr] = {
    path = path,
    opened_at = os.time(),
  }
  notify("active_notebook_buffers", state.active_notebook_buffers)
end

--- Unregister a notebook buffer
---@param bufnr number Buffer number
function M.unregister_notebook(bufnr)
  state.active_notebook_buffers[bufnr] = nil
  notify("active_notebook_buffers", state.active_notebook_buffers)
end

--- Get active notebook buffers
---@return table
function M.get_notebook_buffers()
  return state.active_notebook_buffers
end

--- Check if buffer is a notebook
---@param bufnr number Buffer number
---@return boolean
function M.is_notebook_buffer(bufnr)
  return state.active_notebook_buffers[bufnr] ~= nil
end

--- Set notebook UI mode
---@param mode string "notebook" or "cell"
function M.set_notebook_mode(mode)
  state.notebook_ui_mode = mode
  notify("notebook_ui_mode", mode)
end

--- Get notebook UI mode
---@return string
function M.get_notebook_mode()
  return state.notebook_ui_mode
end

--- Set current cell index
---@param idx number Cell index
function M.set_current_cell(idx)
  state.notebook_current_cell = idx
  notify("notebook_current_cell", idx)
end

--- Get current cell index
---@return number
function M.get_current_cell()
  return state.notebook_current_cell
end

--- Mark cell as executing
---@param cell_idx number Cell index
function M.add_executing_cell(cell_idx)
  state.executing_cells[cell_idx] = true
  notify("executing_cells", state.executing_cells)
end

--- Mark cell as done executing
---@param cell_idx number Cell index
function M.remove_executing_cell(cell_idx)
  state.executing_cells[cell_idx] = nil
  notify("executing_cells", state.executing_cells)
end

--- Check if any cell is executing
---@return boolean
function M.is_executing()
  return next(state.executing_cells) ~= nil
end

--- Mark notebook as dirty (unsaved changes)
---@param bufnr number Buffer number
function M.set_dirty(bufnr)
  state.dirty_notebooks[bufnr] = true
  notify("dirty_notebooks", state.dirty_notebooks)
end

--- Mark notebook as clean (saved)
---@param bufnr number Buffer number
function M.set_clean(bufnr)
  state.dirty_notebooks[bufnr] = nil
  notify("dirty_notebooks", state.dirty_notebooks)
end

--- Check if notebook is dirty
---@param bufnr number Buffer number
---@return boolean
function M.is_dirty(bufnr)
  return state.dirty_notebooks[bufnr] == true
end

--- Set UI component state
---@param component string Component name
---@param open boolean Whether it's open
function M.set_ui_state(component, open)
  state.ui[component] = open
  notify("ui", state.ui)
end

--- Get UI component state
---@param component string Component name
---@return boolean
function M.get_ui_state(component)
  return state.ui[component] or false
end

--- Set last error
---@param error table Error info { code, message }
function M.set_error(error)
  state.last_error = error
  notify("last_error", error)
end

--- Clear last error
function M.clear_error()
  state.last_error = nil
  notify("last_error", nil)
end

--- Get last error
---@return table?
function M.get_error()
  return state.last_error
end

--- Reset entire state (for testing)
function M.reset()
  state = {
    initialized = false,
    backend_running = false,
    current_kernel = nil,
    current_kernel_name = nil,
    active_notebook_buffers = {},
    notebook_ui_mode = "notebook",
    notebook_current_cell = 1,
    executing_cells = {},
    dirty_notebooks = {},
    ui = {
      inspector_open = false,
      repl_buffer_open = false,
      debug_view_open = false,
      status_visible = false,
    },
    last_error = nil,
  }
  watchers = {}
end

--- Get state summary for debugging
---@return string
function M.summary()
  local kernel_name = state.current_kernel and state.current_kernel.name or "none"
  local notebook_count = 0
  for _ in pairs(state.active_notebook_buffers) do
    notebook_count = notebook_count + 1
  end
  local executing_count = 0
  for _ in pairs(state.executing_cells) do
    executing_count = executing_count + 1
  end

  return string.format(
    "Uranus State: initialized=%s, backend=%s, kernel=%s, notebooks=%d, executing=%d",
    tostring(state.initialized),
    tostring(state.backend_running),
    kernel_name,
    notebook_count,
    executing_count
  )
end

return M