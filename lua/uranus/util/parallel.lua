local M = {
  max_concurrent = 4,
  running = false,
  results = {},
}

function M.configure(opts)
  M.max_concurrent = opts.max_concurrent or 4
end

function M.run_cells(cells, callback)
  M.running = true
  M.results = {}
  
  local index = 1
  local running = 0
  
  local function run_next()
    if index > #cells then
      if running == 0 then
        M.running = false
        if callback then
          callback(M.results)
        end
      end
      return
    end
    
    local cell = cells[index]
    index = index + 1
    running = running + 1
    
    local cell_index = index - 1
    
    vim.schedule(function()
      local ok, result = pcall(cell)
      M.results[cell_index] = ok and result or { error = tostring(result) }
      
      running = running - 1
      run_next()
    end)
  end
  
  for i = 1, math.min(M.max_concurrent, #cells) do
    run_next()
  end
end

function M.run_parallel(cells, callback)
  local results = {}
  local count = #cells
  
  if count == 0 then
    if callback then callback({}) end
    return
  end
  
  local done = 0
  
  for i, cell in ipairs(cells) do
    vim.schedule(function()
      local ok, result = pcall(cell)
      results[i] = ok and result or { error = tostring(result) }
      
      done = done + 1
      if done == count and callback then
        callback(results)
      end
    end)
  end
end

function M.run_sequential(cells, callback)
  local results = {}
  
  local function run(index)
    if index > #cells then
      if callback then callback(results) end
      return
    end
    
    local ok, result = pcall(cells[index])
    results[index] = ok and result or { error = tostring(result) }
    
    vim.schedule(function()
      run(index + 1)
    end)
  end
  
  run(1)
end

function M.is_running()
  return M.running
end

function M.stop()
  M.running = false
end

return M