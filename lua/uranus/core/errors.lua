local M = {}

function M.new(code, message)
  local err = {
    code = code,
    message = message,
    __tostring = function(self)
      return self.code .. ": " .. self.message
    end,
  }
  return setmetatable(err, { __index = M })
end

function M.kernel(msg)
  return M.new("KERNEL_ERROR", msg)
end

function M.connection(msg)
  return M.new("CONNECTION_ERROR", msg)
end

function M.execution(msg)
  return M.new("EXECUTION_ERROR", msg)
end

function M.protocol(msg)
  return M.new("PROTOCOL_ERROR", msg)
end

function M.config(msg)
  return M.new("CONFIG_ERROR", msg)
end

function M.not_found(msg)
  return M.new("NOT_FOUND", msg)
end

function M.wrap(err, context)
  if type(err) == "string" then
    return M.new("ERROR", context .. ": " .. err)
  end
  return M.new(err.code or "ERROR", context .. ": " .. (err.message or "Unknown"))
end

return M