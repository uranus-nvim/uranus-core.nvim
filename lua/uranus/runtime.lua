local M = {
  _initialized = false,
  worker_threads = 4,
}

function M.init()
  if M._initialized then
    return
  end
  M._initialized = true
end

function M.status()
  return {
    initialized = M._initialized,
    worker_threads = M.worker_threads,
  }
end

function M.with_runtime(fn)
  if not M._initialized then
    M.init()
  end
  return fn()
end

function M.spawn(future)
  vim.defer_fn(function()
    future()
  end, 0)
end

function M.spawn_blocking(fn)
  vim.schedule(fn)
end

M.init()
return M