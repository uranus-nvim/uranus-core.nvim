--- Uranus logging system
---
--- Provides structured logging with different levels and output formats
--- for debugging and monitoring Uranus operations.
---
--- @module uranus.logger
--- @license MIT

local M = {}

---@alias LogLevel "DEBUG"|"INFO"|"WARN"|"ERROR"

---@class UranusLogger
---@field level LogLevel Current log level
---@field debug boolean Debug mode enabled
---@field name string Logger name
---@field outputs table Output destinations

--- Log levels with numeric values
local LEVELS = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}

--- ANSI color codes for terminal output
local COLORS = {
  DEBUG = "\27[36m", -- Cyan
  INFO = "\27[32m",  -- Green
  WARN = "\27[33m",  -- Yellow
  ERROR = "\27[31m", -- Red
  RESET = "\27[0m",  -- Reset
}

--- Create a new logger instance
---@param level? LogLevel Log level (default: "INFO")
---@param debug? boolean Enable debug mode (default: false)
---@param name? string Logger name (default: "Uranus")
---@return UranusLogger
function M.new(level, debug, name)
  level = level or "INFO"
  debug = debug or false
  name = name or "Uranus"

  local logger = {
    level = level,
    debug = debug,
    name = name,
    outputs = {},
  }

  -- Set up default output to vim.notify
  logger.outputs.notify = function(level, message, context)
    local vim_level = ({
      DEBUG = vim.log.levels.DEBUG,
      INFO = vim.log.levels.INFO,
      WARN = vim.log.levels.WARN,
      ERROR = vim.log.levels.ERROR,
    })[level] or vim.log.levels.INFO

    vim.notify(string.format("[%s] %s", name, message), vim_level)
  end

  -- Set up console output if debug mode
  if debug then
    logger.outputs.console = function(level, message, context)
      local color = COLORS[level] or COLORS.RESET
      local reset = COLORS.RESET
      local timestamp = os.date("%H:%M:%S")

      io.stderr:write(string.format("%s[%s] %s%s: %s%s\n",
        color, timestamp, name, reset, message, reset))
    end
  end

  return setmetatable(logger, { __index = M })
end

--- Log a debug message
---@param message string Log message
---@param context? table Additional context
function M:debug(message, context)
  self:_log("DEBUG", message, context)
end

--- Log an info message
---@param message string Log message
---@param context? table Additional context
function M:info(message, context)
  self:_log("INFO", message, context)
end

--- Log a warning message
---@param message string Log message
---@param context? table Additional context
function M:warn(message, context)
  self:_log("WARN", message, context)
end

--- Log an error message
---@param message string Log message
---@param context? table Additional context
function M:error(message, context)
  self:_log("ERROR", message, context)
end

--- Internal logging function
---@param level LogLevel Log level
---@param message string Log message
---@param context? table Additional context
function M:_log(level, message, context)
  -- Check if this level should be logged
  if LEVELS[level] < LEVELS[self.level] then
    return
  end

  -- Format message with context
  local formatted_message = message
  if context then
    formatted_message = string.format("%s %s", message, vim.inspect(context))
  end

  -- Send to all outputs
  for _, output in pairs(self.outputs) do
    local ok, err = pcall(output, level, formatted_message, context)
    if not ok then
      -- Fallback to basic print for output errors
      print(string.format("[LOGGER ERROR] %s", err))
    end
  end
end

--- Add a custom output destination
---@param name string Output name
---@param output_fn fun(level: LogLevel, message: string, context?: table) Output function
function M:add_output(name, output_fn)
  self.outputs[name] = output_fn
end

--- Remove an output destination
---@param name string Output name
function M:remove_output(name)
  self.outputs[name] = nil
end

--- Set log level
---@param level LogLevel New log level
function M:set_level(level)
  if LEVELS[level] then
    self.level = level
  else
    self:error("Invalid log level: " .. tostring(level))
  end
end

--- Enable or disable debug mode
---@param debug boolean Debug mode enabled
function M:set_debug(debug)
  self.debug = debug

  if debug and not self.outputs.console then
    -- Add console output when debug is enabled
    self:add_output("console", function(level, message, context)
      local color = COLORS[level] or COLORS.RESET
      local reset = COLORS.RESET
      local timestamp = os.date("%H:%M:%S")

      io.stderr:write(string.format("%s[%s] %s%s: %s%s\n",
        color, timestamp, self.name, reset, message, reset))
    end)
  elseif not debug and self.outputs.console then
    -- Remove console output when debug is disabled
    self:remove_output("console")
  end
end

--- Create a child logger
---@param child_name string Child logger name
---@return UranusLogger
function M:child(child_name)
  local child_logger = M.new(self.level, self.debug, string.format("%s.%s", self.name, child_name))

  -- Copy outputs from parent
  for name, output in pairs(self.outputs) do
    child_logger.outputs[name] = output
  end

  return child_logger
end

--- Get current logger statistics
---@return table Logger statistics
function M:stats()
  return {
    level = self.level,
    debug = self.debug,
    name = self.name,
    outputs = vim.tbl_keys(self.outputs),
  }
end

return M