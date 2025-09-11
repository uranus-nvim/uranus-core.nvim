--- Uranus kernel management
---
--- Handles discovery, connection, and management of Jupyter kernels
--- for both local and remote execution environments.
---
--- @module uranus.kernel
--- @license MIT

local M = {}

---@class UranusKernelInfo
---@field id string Unique kernel identifier
---@field name string Kernel display name
---@field language string Programming language
---@field connection_file? string Path to connection file (local kernels)
---@field status "starting"|"running"|"stopped"|"error" Kernel status
---@field type "local"|"remote" Kernel type
---@field server? UranusRemoteServer Remote server info (remote kernels)

---@class UranusExecutionOptions
---@field kernel_id? string Specific kernel to use
---@field timeout? number Execution timeout in milliseconds
---@field on_result? fun(result: UranusExecutionResult) Result callback
---@field on_error? fun(error: UranusError) Error callback
---@field silent? boolean Suppress notifications

---@class UranusExecutionResult
---@field success boolean Execution success
---@field stdout? string Standard output
---@field stderr? string Standard error
---@field display_data? UranusDisplayData[] Rich display data
---@field execution_count number Execution count

---@class UranusDisplayData
---@field mime_type string MIME type (e.g., "text/plain", "image/png")
---@field data string|table Display data content
---@field metadata? table Additional metadata

--- Module state
---@type UranusKernelInfo[]
M.discovered_kernels = {}

---@type UranusKernelInfo|nil
M.current_kernel = nil

---@type table<string, UranusKernelInfo>
M.active_kernels = {}

--- Initialize kernel management
---@param config UranusConfig Uranus configuration
---@return UranusResult
function M.init(config)
  M.config = config

  -- Discover local kernels on startup (only if backend is available)
  if config.kernels.auto_start then
    local backend = require("uranus.backend")
    if backend.state.connected then
      local result = M.discover_local_kernels()
      if not result.success then
        return result
      end
    end
  end

  return M.ok(true)
end

--- Discover local Jupyter kernels using Rust backend
---@return UranusResult<UranusKernelInfo[]>
function M.discover_local_kernels()
  local backend = require("uranus.backend")
  local result = backend.send_command("list_kernels", {})

  if not result.success then
    return result
  end

  -- Transform Rust response to Lua kernel info format
  local kernels = {}
  for _, kernel in ipairs(result.data.kernels or {}) do
    table.insert(kernels, {
      id = kernel.name,
      name = kernel.name,
      language = kernel.language or "unknown",
      status = "available",
      type = "local",
    })
  end

  M.discovered_kernels = kernels

  vim.notify("Discovered " .. #kernels .. " local kernels", vim.log.levels.INFO)

  return M.ok(kernels)
end

--- Connect to a kernel
---@param kernel_name string Kernel name or ID
---@return UranusResult<UranusKernelInfo>
function M.connect(kernel_name)
  -- Find kernel by name or ID
  local kernel = M._find_kernel(kernel_name)
  if not kernel then
    return M.err("KERNEL_NOT_FOUND", "Kernel not found: " .. kernel_name)
  end

  -- Check if already connected
  if M.current_kernel and M.current_kernel.id == kernel.id then
    return M.ok(M.current_kernel)
  end

  -- Connect via backend (start kernel)
  local backend = require("uranus.backend")
  local result = backend.send_command("start_kernel", {
    kernel = kernel.name,
  })

  if not result.success then
    return result
  end

  -- Update state
  M.current_kernel = kernel
  M.active_kernels[kernel.id] = kernel

  vim.notify("Connected to kernel: " .. kernel.name, vim.log.levels.INFO)

  return M.ok(kernel)
end

--- Disconnect from current kernel
---@return UranusResult
function M.disconnect()
  if not M.current_kernel then
    return M.ok(true)
  end

  local backend = require("uranus.backend")
  local result = backend.send_command("disconnect")

  if result.success then
    M.active_kernels[M.current_kernel.id] = nil
    M.current_kernel = nil
    vim.notify("Disconnected from kernel", vim.log.levels.INFO)
  end

  return result
end

--- Execute code in the current kernel
---@param code string Code to execute
---@param opts? UranusExecutionOptions Execution options
---@return UranusResult<UranusExecutionResult>
function M.execute(code, opts)
  opts = opts or {}

  if not M.current_kernel then
    return M.err("NO_KERNEL", "No kernel connected")
  end

  -- Send execute to backend
  local backend = require("uranus.backend")
  local result = backend.send_command("execute", {
    code = code,
  })

  if not result.success then
    return result
  end

  -- Backend will handle async result delivery via events
  return M.ok(result.data)
end

--- Start a new kernel
---@param kernel_name string Kernel name to start
---@return UranusResult<UranusKernelInfo>
function M.start_kernel(kernel_name)
  local backend = require("uranus.backend")
  local result = backend.send_command("start_kernel", {
    kernel = kernel_name,
  })

  if not result.success then
    return result
  end

  -- Backend handles kernel startup and will send events when ready
  return M.ok({
    id = kernel_name,
    name = kernel_name,
    language = "unknown", -- Will be updated when kernel starts
    status = "starting",
    type = "local",
  })
end

--- Stop a kernel
---@param kernel_id string Kernel ID to stop
---@return UranusResult
function M.stop_kernel(kernel_id)
  -- Note: The Rust backend doesn't support stopping individual kernels,
  -- only shutting down the entire backend. For now, we'll just update local state.
  M.active_kernels[kernel_id] = nil
  if M.current_kernel and M.current_kernel.id == kernel_id then
    M.current_kernel = nil
  end

  vim.notify("Kernel " .. kernel_id .. " stopped (local state only)", vim.log.levels.INFO)
  return M.ok(true)
end

--- List all available kernels
---@return UranusResult<UranusKernelInfo[]>
function M.list_kernels()
  local all_kernels = {}

  -- Add discovered local kernels
  vim.list_extend(all_kernels, M.discovered_kernels)

  -- Add remote kernels
  local remote = require("uranus.remote")
  local remote_result = remote.list_all_kernels()
  if remote_result.success then
    vim.list_extend(all_kernels, remote_result.data)
  end

  return M.ok(all_kernels)
end

--- Get current kernel information
---@return UranusKernelInfo|nil
function M.get_current_kernel()
  return M.current_kernel
end

--- Select kernel interactively
---@return UranusResult<UranusKernelInfo>
function M.select_kernel()
  local kernels_result = M.list_kernels()
  if not kernels_result.success then
    return kernels_result
  end

  local kernels = kernels_result.data
  if #kernels == 0 then
    return M.err("NO_KERNELS", "No kernels available")
  end

  -- Use Telescope if available
  if pcall(require, "telescope") then
    return M._select_kernel_telescope(kernels)
  else
    return M._select_kernel_vim(kernels)
  end
end

--- Select kernel using Telescope
---@param kernels UranusKernelInfo[]
---@return UranusResult<UranusKernelInfo>
function M._select_kernel_telescope(kernels)
  local telescope = require("telescope")
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local sorters = require("telescope.sorters")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Select Kernel",
    finder = finders.new_table({
      results = kernels,
      entry_maker = function(kernel)
        return {
          value = kernel,
          display = kernel.name .. " (" .. kernel.language .. ") [" .. kernel.type .. "]",
          ordinal = kernel.name,
        }
      end,
    }),
    sorter = sorters.get_generic_fuzzy_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      map("i", "<CR>", function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          M.connect(selection.value.name)
        end
      end)
      return true
    end,
  }):find()

  return M.ok(nil) -- Async operation
end

--- Select kernel using vim.ui.select
---@param kernels UranusKernelInfo[]
---@return UranusResult<UranusKernelInfo>
function M._select_kernel_vim(kernels)
  local options = {}
  for i, kernel in ipairs(kernels) do
    options[i] = kernel.name .. " (" .. kernel.language .. ") [" .. kernel.type .. "]"
  end

  vim.ui.select(options, {
    prompt = "Select Kernel:",
  }, function(choice, idx)
    if choice and idx then
      M.connect(kernels[idx].name)
    end
  end)

  return M.ok(nil) -- Async operation
end

--- Find kernel by name or ID
---@param identifier string Kernel name or ID
---@return UranusKernelInfo|nil
function M._find_kernel(identifier)
  -- First try exact match by ID
  for _, kernel in ipairs(M.discovered_kernels) do
    if kernel.id == identifier then
      return kernel
    end
  end

  -- Then try match by name
  for _, kernel in ipairs(M.discovered_kernels) do
    if kernel.name == identifier then
      return kernel
    end
  end

  -- Check active kernels
  return M.active_kernels[identifier]
end

--- Interrupt current execution
---@return UranusResult
function M.interrupt()
  if not M.current_kernel then
    return M.err("NO_KERNEL", "No kernel connected")
  end

  local backend = require("uranus.backend")
  return backend.send_command("interrupt_request", {
    kernel_id = M.current_kernel.id,
  })
end

--- Create success result
---@generic T
---@param data T Data
---@return UranusResult<T>
function M.ok(data)
  return { success = true, data = data }
end

--- Create error result
---@param code string Error code
---@param message string Error message
---@param context? table Additional context
---@return UranusResult
function M.err(code, message, context)
  return {
    success = false,
    error = {
      code = code,
      message = message,
      context = context,
    }
  }
end

return M