--- Uranus backend communication
---
--- Handles JSON protocol communication with the Rust backend process.
--- Manages process lifecycle, message sending/receiving, and event handling.
---
--- @module uranus.backend
--- @license MIT

local M = {}

---@class UranusBackendProcess
---@field process vim.SystemObj|nil System process object
---@field connected boolean Connection status
---@field callbacks table<string, fun(data: table)[]> Event callbacks
---@field pending_requests table<string, UranusPendingRequest> Pending requests
---@field request_id number Next request ID

---@class UranusPendingRequest
---@field id string Request ID
---@field command string Command name
---@field callback fun(result: UranusResult)|nil Response callback
---@field timeout_timer number|nil Timeout timer ID

--- Module state
---@type UranusBackendProcess
M.state = {
  process = nil,
  connected = false,
  callbacks = {},
  pending_requests = {},
  request_id = 1,
}

--- Initialize backend communication
---@param config UranusConfig Uranus configuration
---@return UranusResult
function M.init(config)
  M.config = config

  -- Set up event callbacks
  M._setup_event_handlers()

  return M.ok(true)
end

--- Start the Rust backend process
---@return UranusResult
function M.start()
  if M.state.connected then
    return M.ok(true)
  end

  -- Find the backend binary
  local binary_path = M._find_binary()
  if not binary_path then
    return M.err("BINARY_NOT_FOUND", "Uranus backend binary not found")
  end

  -- Start the process
  local ok, process = pcall(vim.system, { binary_path }, {
    stdin = true,
    stdout = true,
    stderr = true,
    text = true,
  }, M._handle_output)

  if not ok then
    return M.err("PROCESS_START_FAILED", "Failed to start backend process: " .. process)
  end

  M.state.process = process
  M.state.connected = true

  vim.notify("Uranus backend started", vim.log.levels.INFO)

  return M.ok(true)
end

--- Stop the Rust backend process
---@return UranusResult
function M.stop()
  if not M.state.connected or not M.state.process then
    return M.ok(true)
  end

  -- Send shutdown command
  M.send_command("shutdown")

  -- Wait a bit for graceful shutdown
  vim.defer_fn(function()
    if M.state.process then
      M.state.process:kill()
      M.state.process = nil
      M.state.connected = false
    end
  end, 1000)

  vim.notify("Uranus backend stopped", vim.log.levels.INFO)

  return M.ok(true)
end

--- Send command to backend
---@param command string Command name
---@param data? table Command data
---@param callback? fun(result: UranusResult) Response callback
---@return UranusResult
function M.send_command(command, data, callback)
  if not M.state.connected or not M.state.process then
    return M.err("NOT_CONNECTED", "Backend not connected")
  end

  local request_id = "req_" .. M.state.request_id
  M.state.request_id = M.state.request_id + 1

  local message = {
    id = request_id,
    cmd = command,
    data = data or {},
  }

  local json_message = vim.json.encode(message)

  -- Store pending request
  if callback then
    M.state.pending_requests[request_id] = {
      id = request_id,
      command = command,
      callback = callback,
      timeout_timer = M._setup_timeout(request_id, callback),
    }
  end

  -- Send message
  local ok, err = pcall(function()
    M.state.process:write(json_message .. "\n")
  end)

  if not ok then
    -- Clean up pending request
    if M.state.pending_requests[request_id] then
      M.state.pending_requests[request_id] = nil
    end
    return M.err("SEND_FAILED", "Failed to send command: " .. err)
  end

  return M.ok(request_id)
end

--- Handle process output
---@param obj vim.SystemCompleted System completion object
function M._handle_output(obj)
  if obj.code ~= 0 then
    vim.notify("Uranus backend error: " .. (obj.stderr or "Unknown error"), vim.log.levels.ERROR)
    M.state.connected = false
    return
  end

  -- Process stdout line by line
  if obj.stdout then
    for line in vim.gsplit(obj.stdout, "\n") do
      if line ~= "" then
        M._handle_message(line)
      end
    end
  end
end

--- Handle incoming message from backend
---@param line string JSON message line
function M._handle_message(line)
  local ok, message = pcall(vim.json.decode, line)
  if not ok then
    vim.notify("Failed to parse backend message: " .. line, vim.log.levels.WARN)
    return
  end

  -- Handle different message types
  if message.event then
    -- Event message
    M._handle_event(message)
  elseif message.id then
    -- Response message
    M._handle_response(message)
  else
    vim.notify("Unknown message type from backend", vim.log.levels.WARN)
  end
end

--- Handle event messages from backend
---@param message table Event message
function M._handle_event(message)
  local event = message.event
  local data = message.data or {}

  -- Call registered callbacks
  local callbacks = M.state.callbacks[event]
  if callbacks then
    for _, callback in ipairs(callbacks) do
      local ok, err = pcall(callback, data)
      if not ok then
        vim.notify("Event callback error for '" .. event .. "': " .. err, vim.log.levels.ERROR)
      end
    end
  end

  -- Handle Jupyter protocol events
  if event == "status" then
    M._handle_status(data)
  elseif event == "execute_reply" then
    M._handle_execute_reply(data)
  elseif event == "execute_result" then
    M._handle_execute_result(data)
  elseif event == "display_data" then
    M._handle_display_data(data)
  elseif event == "stream" then
    M._handle_stream(data)
  elseif event == "error" then
    M._handle_error(data)
  elseif event == "kernel_info_reply" then
    M._handle_kernel_info_reply(data)
  end
end

--- Handle response messages from backend
---@param message table Response message
function M._handle_response(message)
  local request_id = message.id
  local pending = M.state.pending_requests[request_id]

  if not pending then
    vim.notify("Received response for unknown request: " .. request_id, vim.log.levels.WARN)
    return
  end

  -- Clear timeout
  if pending.timeout_timer then
    vim.fn.timer_stop(pending.timeout_timer)
  end

  -- Call callback
  if pending.callback then
    local result
    if message.success then
      result = M.ok(message.data)
    else
      result = M.err(message.error.code or "BACKEND_ERROR", message.error.message or "Backend error")
    end

    local ok, err = pcall(pending.callback, result)
    if not ok then
      vim.notify("Response callback error: " .. err, vim.log.levels.ERROR)
    end
  end

  -- Clean up
  M.state.pending_requests[request_id] = nil
end

--- Set up timeout for pending request
---@param request_id string Request ID
---@param callback fun(result: UranusResult) Callback function
---@return number Timer ID
function M._setup_timeout(request_id, callback)
  return vim.fn.timer_start(M.config.kernels.timeout or 10000, function()
    -- Clean up pending request
    M.state.pending_requests[request_id] = nil

    -- Call callback with timeout error
    local result = M.err("TIMEOUT", "Request timed out")
    pcall(callback, result)
  end)
end

--- Register event callback
---@param event string Event name
---@param callback fun(data: table) Callback function
function M.on(event, callback)
  if not M.state.callbacks[event] then
    M.state.callbacks[event] = {}
  end

  table.insert(M.state.callbacks[event], callback)
end

--- Unregister event callback
---@param event string Event name
---@param callback fun(data: table) Callback function
function M.off(event, callback)
  local callbacks = M.state.callbacks[event]
  if not callbacks then
    return
  end

  for i, cb in ipairs(callbacks) do
    if cb == callback then
      table.remove(callbacks, i)
      break
    end
  end
end

--- Set up built-in event handlers for Jupyter protocol
function M._setup_event_handlers()
  -- Kernel status events
  M.on("status", function(data)
    local kernel = require("uranus.kernel")
    if kernel.current_kernel then
      kernel.current_kernel.status = data.execution_state
      vim.notify("Kernel status: " .. data.execution_state, vim.log.levels.INFO)
    end
  end)

  -- Execution events
  M.on("execute_reply", function(data)
    -- Handle execution completion
    if data.status == "ok" then
      vim.notify("Execution completed", vim.log.levels.INFO)
    else
      vim.notify("Execution failed: " .. (data.ename or "Unknown error"), vim.log.levels.ERROR)
    end
  end)

  M.on("execute_result", function(data)
    local output = require("uranus.output")
    output.handle_result({
      success = true,
      execution_count = data.execution_count,
      display_data = {data.data},
    })
  end)

  M.on("display_data", function(data)
    local output = require("uranus.output")
    output.display_rich_output(data.data)
  end)

  M.on("stream", function(data)
    local output = require("uranus.output")
    if data.name == "stdout" then
      output.display_text(data.text, "stdout")
    elseif data.name == "stderr" then
      output.display_text(data.text, "stderr")
    end
  end)

  -- Error events
  M.on("error", function(data)
    vim.notify("Jupyter error: " .. (data.ename or "Unknown error"), vim.log.levels.ERROR)
  end)

  M.on("kernel_info_reply", function(data)
    vim.notify("Connected to " .. (data.language_info.name or "unknown") .. " kernel", vim.log.levels.INFO)
  end)
end

--- Handle kernel status event
---@param data table Event data
function M._handle_status(data)
  local kernel = require("uranus.kernel")
  if kernel.current_kernel then
    kernel.current_kernel.status = data.execution_state
  end
end

--- Handle execute reply event
---@param data table Event data
function M._handle_execute_reply(data)
  -- Execution completion is handled by the event callback above
end

--- Handle execute result event
---@param data table Event data
function M._handle_execute_result(data)
  local output = require("uranus.output")
  output.handle_result({
    success = true,
    execution_count = data.execution_count,
    display_data = {data.data},
  })
end

--- Handle display data event
---@param data table Event data
function M._handle_display_data(data)
  local output = require("uranus.output")
  output.display_rich_output(data.data)
end

--- Handle stream event
---@param data table Event data
function M._handle_stream(data)
  local output = require("uranus.output")
  if data.name == "stdout" then
    output.display_text(data.text, "stdout")
  elseif data.name == "stderr" then
    output.display_text(data.text, "stderr")
  end
end

--- Handle error event
---@param data table Event data
function M._handle_error(data)
  vim.notify("Jupyter protocol error: " .. (data.ename or "Unknown error"), vim.log.levels.ERROR)
end

--- Handle kernel info reply event
---@param data table Event data
function M._handle_kernel_info_reply(data)
  local kernel = require("uranus.kernel")
  if kernel.current_kernel then
    kernel.current_kernel.language = data.language_info.name
  end
end

--- Find backend binary path
---@return string|nil Binary path or nil if not found
function M._find_binary()
  -- Check common locations
  local candidates = {
    -- Local development
    vim.fn.getcwd() .. "/target/release/uranus-rs",
    vim.fn.getcwd() .. "/target/debug/uranus-rs",

    -- User installation
    vim.fn.expand("~/.cargo/bin/uranus-rs"),

    -- System installation
    "/usr/local/bin/uranus-rs",
    "/usr/bin/uranus-rs",

    -- Check PATH
    vim.fn.exepath("uranus-rs"),
  }

  for _, path in ipairs(candidates) do
    if vim.fn.executable(path) == 1 then
      return path
    end
  end

  return nil
end

--- Get backend status
---@return table Backend status information
function M.status()
  return {
    connected = M.state.connected,
    process_running = M.state.process ~= nil,
    pending_requests = vim.tbl_count(M.state.pending_requests),
    registered_callbacks = vim.tbl_count(M.state.callbacks),
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