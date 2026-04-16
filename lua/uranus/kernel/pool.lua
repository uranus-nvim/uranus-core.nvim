local M = {
  pools = {},
  max_idle_time = 300000,
  max_idle_per_kernel = 3,
}

function M.configure(opts)
  M.max_idle_time = opts.max_idle_time or 300000
  M.max_idle_per_kernel = opts.max_idle_per_kernel or 3
end

function M.get_pool(kernel_name)
  if not M.pools[kernel_name] then
    M.pools[kernel_name] = {
      available = {},
      in_use = {},
      counter = 0,
    }
  end
  return M.pools[kernel_name]
end

function M.acquire(kernel_name)
  local pool = M.get_pool(kernel_name)
  
  if #pool.available > 0 then
    local conn = table.remove(pool.available)
    pool.in_use[conn] = true
    return conn
  end
  
  pool.counter = pool.counter + 1
  local conn = "kernel_" .. pool.counter
  pool.in_use[conn] = true
  return conn
end

function M.release(kernel_name, conn)
  if not conn then return end
  
  local pool = M.get_pool(kernel_name)
  
  if pool.in_use[conn] then
    pool.in_use[conn] = nil
    
    if #pool.available < M.max_idle_per_kernel then
      table.insert(pool.available, conn)
    end
  end
end

function M.clear()
  M.pools = {}
end

function M.stats()
  local total = 0
  local in_use = 0
  
  for _, pool in pairs(M.pools) do
    total = total + #pool.available
    for _ in pairs(pool.in_use) do
      in_use = in_use + 1
    end
  end
  
  return {
    total_kernels = total,
    in_use = in_use,
    idle = total - in_use,
  }
end

return M