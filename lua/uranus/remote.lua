--- Uranus remote kernel support
---
--- Provides connection to remote Jupyter kernels via JupyterHub,
--- JupyterLab, and other remote Jupyter servers.
---
--- @module uranus.remote
--- @license MIT

local M = {}

---@class UranusRemoteServer
---@field name string Server display name
---@field url string Server URL
---@field token string Authentication token
---@field headers? table Additional HTTP headers

---@class UranusRemoteKernel
---@field id string Kernel ID
---@field name string Kernel name
---@field server UranusRemoteServer Remote server
---@field status string Kernel status

--- Module state
---@type UranusRemoteServer[]
M.servers = {}

---@type table<string, UranusRemoteKernel>
M.kernels = {}

--- Initialize remote support
---@param config UranusConfig Uranus configuration
---@return UranusResult
function M.init(config)
  M.config = config

  -- Load configured remote servers
  if config.remote_servers then
    M.servers = vim.deepcopy(config.remote_servers)
  end

  return M.ok(true)
end

--- Add a remote server configuration
---@param server UranusRemoteServer Server configuration
---@return UranusResult
function M.add_server(server)
  -- Validate server configuration
  local result = M._validate_server(server)
  if not result.success then
    return result
  end

  -- Check for duplicate names
  for _, existing in ipairs(M.servers) do
    if existing.name == server.name then
      return M.err("DUPLICATE_SERVER", "Server with name '" .. server.name .. "' already exists")
    end
  end

  table.insert(M.servers, server)

  vim.notify("Remote server '" .. server.name .. "' added", vim.log.levels.INFO)

  return M.ok(true)
end

--- Remove a remote server
---@param name string Server name
---@return UranusResult
function M.remove_server(name)
  for i, server in ipairs(M.servers) do
    if server.name == name then
      table.remove(M.servers, i)
      M._cleanup_server_kernels(name)
      vim.notify("Remote server '" .. name .. "' removed", vim.log.levels.INFO)
      return M.ok(true)
    end
  end

  return M.err("SERVER_NOT_FOUND", "Server '" .. name .. "' not found")
end

--- List configured remote servers
---@return UranusResult<UranusRemoteServer[]>
function M.list_servers()
  return M.ok(vim.deepcopy(M.servers))
end

--- Connect to remote kernel
---@param server_name string Server name
---@param kernel_name string Kernel name
---@return UranusResult<UranusRemoteKernel>
function M.connect(server_name, kernel_name)
  -- Find server
  local server = M._find_server(server_name)
  if not server then
    return M.err("SERVER_NOT_FOUND", "Server '" .. server_name .. "' not found")
  end

  -- Get available kernels from server
  local kernels_result = M._list_server_kernels(server)
  if not kernels_result.success then
    return kernels_result
  end

  -- Find requested kernel
  local kernel_info = nil
  for _, kernel in ipairs(kernels_result.data) do
    if kernel.name == kernel_name then
      kernel_info = kernel
      break
    end
  end

  if not kernel_info then
    return M.err("KERNEL_NOT_FOUND", "Kernel '" .. kernel_name .. "' not found on server '" .. server_name .. "'")
  end

  -- Connect via backend
  local backend = require("uranus.backend")
  local result = backend.send_command("connect_remote", {
    server = server.url,
    token = server.token,
    kernel_id = kernel_info.id,
  })

  if not result.success then
    return result
  end

  -- Create kernel object
  local kernel = {
    id = kernel_info.id,
    name = kernel_info.name,
    server = server,
    status = "connecting",
  }

  M.kernels[kernel.id] = kernel

  vim.notify("Connecting to remote kernel '" .. kernel.name .. "' on '" .. server.name .. "'",
    vim.log.levels.INFO)

  return M.ok(kernel)
end

--- List all available remote kernels
---@return UranusResult<UranusRemoteKernel[]>
function M.list_all_kernels()
  local all_kernels = {}

  for _, server in ipairs(M.servers) do
    local result = M._list_server_kernels(server)
    if result.success then
      for _, kernel in ipairs(result.data) do
        table.insert(all_kernels, {
          id = kernel.id,
          name = kernel.name,
          server = server,
          status = kernel.status or "unknown",
        })
      end
    end
  end

  return M.ok(all_kernels)
end

--- Disconnect from remote kernel
---@param kernel_id string Kernel ID
---@return UranusResult
function M.disconnect(kernel_id)
  local kernel = M.kernels[kernel_id]
  if not kernel then
    return M.err("KERNEL_NOT_FOUND", "Remote kernel '" .. kernel_id .. "' not found")
  end

  -- Disconnect via backend
  local backend = require("uranus.backend")
  local result = backend.send_command("disconnect_remote", {
    kernel_id = kernel_id,
  })

  if result.success then
    M.kernels[kernel_id] = nil
    vim.notify("Disconnected from remote kernel '" .. kernel.name .. "'", vim.log.levels.INFO)
  end

  return result
end

--- Get server kernels via REST API
---@param server UranusRemoteServer Server configuration
---@return UranusResult<table[]> Server kernels
function M._list_server_kernels(server)
  -- Use plenary.curl for HTTP requests
  local ok, curl = pcall(require, "plenary.curl")
  if not ok then
    return M.err("CURL_NOT_FOUND", "plenary.curl not found - required for remote kernels")
  end

  local url = server.url .. "/api/kernels"
  local headers = {
    ["Authorization"] = "token " .. server.token,
  }

  -- Add custom headers
  if server.headers then
    for k, v in pairs(server.headers) do
      headers[k] = v
    end
  end

  local response = curl.get(url, {
    headers = headers,
    timeout = M.config.remote.timeout or 10000,
  })

  if response.status ~= 200 then
    return M.err("HTTP_ERROR", "Failed to list kernels: HTTP " .. response.status, {
      url = url,
      response = response.body,
    })
  end

  local ok, kernels = pcall(vim.json.decode, response.body)
  if not ok then
    return M.err("PARSE_ERROR", "Failed to parse kernel list response", {
      body = response.body,
    })
  end

  return M.ok(kernels)
end

--- Validate server configuration
---@param server UranusRemoteServer Server to validate
---@return UranusResult<UranusRemoteServer>
function M._validate_server(server)
  if type(server) ~= "table" then
    return M.err("INVALID_TYPE", "Server must be a table", { got = type(server) })
  end

  -- Required fields
  if type(server.name) ~= "string" or server.name == "" then
    return M.err("INVALID_NAME", "Server name must be a non-empty string", { got = server.name })
  end

  if type(server.url) ~= "string" or server.url == "" then
    return M.err("INVALID_URL", "Server URL must be a non-empty string", { got = server.url })
  end

  -- Basic URL validation
  if not server.url:match("^https?://") then
    return M.err("INVALID_URL", "Server URL must start with http:// or https://", { got = server.url })
  end

  if type(server.token) ~= "string" or server.token == "" then
    return M.err("INVALID_TOKEN", "Server token must be a non-empty string", { got = server.token })
  end

  -- Optional headers validation
  if server.headers ~= nil then
    if type(server.headers) ~= "table" then
      return M.err("INVALID_HEADERS", "Server headers must be a table", { got = type(server.headers) })
    end
  end

  return M.ok(server)
end

--- Find server by name
---@param name string Server name
---@return UranusRemoteServer|nil Server configuration
function M._find_server(name)
  for _, server in ipairs(M.servers) do
    if server.name == name then
      return server
    end
  end
  return nil
end

--- Clean up kernels for removed server
---@param server_name string Server name
function M._cleanup_server_kernels(server_name)
  for kernel_id, kernel in pairs(M.kernels) do
    if kernel.server.name == server_name then
      M.disconnect(kernel_id)
    end
  end
end

--- Get remote kernel status
---@return table Remote kernel status
function M.status()
  return {
    servers = #M.servers,
    active_kernels = vim.tbl_count(M.kernels),
  }
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