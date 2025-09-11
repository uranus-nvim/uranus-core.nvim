--- Uranus logging system
---
--- Simple logging for Uranus operations.
---
--- @module uranus.logger
--- @license MIT

local M = {}

---@alias LogLevel "DEBUG"|"INFO"|"WARN"|"ERROR"

--- Log levels with numeric values
local LEVELS = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}

--- Create a new logger instance
---@param level? LogLevel Log level (default: "INFO")
---@param debug? boolean Enable debug mode (default: false)
---@param name? string Logger name (default: "Uranus")
---@return table Logger instance
function M.new(level, debug, name)
  level = level or "INFO"
  debug = debug or false
  name = name or "Uranus"

  local logger = {
    level = level,
    debug = debug,
    name = name,
  }

  -- Add logging functions
  logger.debug = function(message, context)
    M._log(logger, "DEBUG", message, context)
  end

  logger.info = function(message, context)
    M._log(logger, "INFO", message, context)
  end

  logger.warn = function(message, context)
    M._log(logger, "WARN", message, context)
  end

  logger.error = function(message, context)
    M._log(logger, "ERROR", message, context)
  end

  return logger
end

--- Internal logging function
---@param logger table Logger instance
---@param level LogLevel Log level
---@param message string Log message
---@param context? table Additional context
function M._log(logger, level, message, context)
  -- Ensure logger.level is valid
  if not logger.level or not LEVELS[logger.level] then
    logger.level = "INFO"
  end

  -- Check if this level should be logged
  if LEVELS[level] < LEVELS[logger.level] then
    return
  end

  -- Format message
  local formatted_message = message
  if context then
    formatted_message = string.format("%s %s", message, vim.inspect(context))
  end

  -- Output to vim.notify
  local vim_level = ({
    DEBUG = vim.log.levels.DEBUG,
    INFO = vim.log.levels.INFO,
    WARN = vim.log.levels.WARN,
    ERROR = vim.log.levels.ERROR,
  })[level] or vim.log.levels.INFO

  vim.notify(string.format("[%s] %s", logger.name, formatted_message), vim_level)
end

return M