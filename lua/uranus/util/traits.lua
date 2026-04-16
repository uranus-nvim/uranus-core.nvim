local M = {}

M.KernelExecutor = {
  execute = function(self, code)
    error("Not implemented")
  end,
  execute_async = function(self, code, callback)
    error("Not implemented")
  end,
}

M.KernelInspector = {
  inspect = function(self, code, cursor_pos)
    error("Not implemented")
  end,
  get_variables = function(self)
    error("Not implemented")
  end,
}

M.KernelLifecycle = {
  start = function(self)
    error("Not implemented")
  end,
  stop = function(self)
    error("Not implemented")
  end,
  restart = function(self)
    error("Not implemented")
  end,
}

M.Kernel = {
  start = M.KernelLifecycle.start,
  stop = M.KernelLifecycle.stop,
  restart = M.KernelLifecycle.restart,
  execute = M.KernelExecutor.execute,
  inspect = M.KernelInspector.inspect,
  get_variables = M.KernelInspector.get_variables,
}

function M.create_kernel(impl)
  return vim.tbl_extend("keep", impl, M.Kernel)
end

return M