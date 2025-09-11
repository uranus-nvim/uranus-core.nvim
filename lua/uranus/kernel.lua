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

  -- Discover local kernels on startup
  if config.kernels.auto_start then
    local result = M.discover_local_kernels()
    if not result.success then
      return result
    end
  end

  return M.ok(true)
end

--- Discover local Jupyter kernels
---@return UranusResult<UranusKernelInfo[]>
function M.discover_local_kernels()
  local kernels = {}

  -- Search in configured discovery paths
  for _, path in ipairs(M.config.kernels.discovery_paths) do
    local expanded_path = vim.fn.expand(path)
    if vim.fn.isdirectory(expanded_path) == 1 then
      local result = M._scan_directory(expanded_path)
      if result.success then
        vim.list_extend(kernels, result.data)
      end
    end
  end

  -- Remove duplicates by kernel name
  local unique_kernels = {}
  local seen = {}
  for _, kernel in ipairs(kernels) do
    if not seen[kernel.name] then
      seen[kernel.name] = true
      table.insert(unique_kernels, kernel)
    end
  end

  M.discovered_kernels = unique_kernels

  vim.notify("Discovered " .. #unique_kernels .. " local kernels", vim.log.levels.INFO)

  return M.ok(unique_kernels)
end

--- Scan directory for kernel connection files
---@param directory string Directory to scan
---@return UranusResult<UranusKernelInfo[]>
function M._scan_directory(directory)
  local kernels = {}

  -- Find all .json files in the directory
  local files = vim.fn.glob(directory .. "/*.json", false, true)

  for _, file in ipairs(files) do
    local result = M._parse_connection_file(file)
    if result.success then
      table.insert(kernels, result.data)
    end
  end

  return M.ok(kernels)
end

--- Parse Jupyter connection file
---@param file_path string Path to connection file
---@return UranusResult<UranusKernelInfo>
function M._parse_connection_file(file_path)
  local ok, content = pcall(vim.fn.readfile, file_path)
  if not ok then
    return M.err("READ_FAILED", "Failed to read connection file: " .. file_path)
  end

  local ok, data = pcall(vim.json.decode, table.concat(content, "\n"))
  if not ok then
    return M.err("PARSE_FAILED", "Failed to parse connection file: " .. file_path)
  end

  -- Validate required fields
  if not data.kernel_name then
    return M.err("INVALID_CONNECTION", "Connection file missing kernel_name: " .. file_path)
  end

  local kernel_info = {
    id = data.kernel_name .. "_" .. vim.fn.fnamemodify(file_path, ":t:r"),
    name = data.kernel_name,
    language = M._detect_language(data),
    connection_file = file_path,
    status = "running", -- Assume running if file exists
    type = "local",
  }

  return M.ok(kernel_info)
end

--- Detect programming language from kernel info
---@param kernel_data table Kernel connection data
---@return string Detected language
function M._detect_language(kernel_data)
  local name = kernel_data.kernel_name:lower()

  -- Common language mappings
  if name:match("python") then
    return "python"
  elseif name:match("r") then
    return "r"
  elseif name:match("julia") then
    return "julia"
  elseif name:match("javascript") or name:match("node") then
    return "javascript"
  elseif name:match("bash") or name:match("shell") then
    return "bash"
  else
    return "unknown"
  end
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

  -- Connect via backend
  local backend = require("uranus.backend")
  local result

  if kernel.type == "local" then
    result = backend.send_command("connect", {
      conn_file = kernel.connection_file,
    })
  else
    -- Remote kernel connection
    result = backend.send_command("connect_remote", {
      server = kernel.server.url,
      token = kernel.server.token,
      kernel_id = kernel.id,
    })
  end

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

  -- Send execution command to backend
  local backend = require("uranus.backend")
  local result = backend.send_command("execute", {
    code = code,
    kernel_id = opts.kernel_id or M.current_kernel.id,
  })

  if not result.success then
    return result
  end

  -- Wait for result (simplified - in real implementation this would be async)
  -- TODO: Implement proper async result handling
  return M.ok({
    success = true,
    stdout = "",
    stderr = "",
    display_data = {},
    execution_count = 1,
  })
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

  -- Wait for kernel to start and discover it
  vim.defer_fn(function()
    M.discover_local_kernels()
  end, 1000) -- Wait 1 second for kernel to start

  return M.ok({
    id = kernel_name,
    name = kernel_name,
    language = M._detect_language({ kernel_name = kernel_name }),
    status = "starting",
    type = "local",
  })
end

--- Stop a kernel
---@param kernel_id string Kernel ID to stop
---@return UranusResult
function M.stop_kernel(kernel_id)
  local backend = require("uranus.backend")
  local result = backend.send_command("stop_kernel", {
    kernel_id = kernel_id,
  })

  if result.success then
    M.active_kernels[kernel_id] = nil
    if M.current_kernel and M.current_kernel.id == kernel_id then
      M.current_kernel = nil
    end
  end

  return result
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
  return backend.send_command("interrupt")
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