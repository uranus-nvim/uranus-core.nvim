local M = {
  updates = {},
  flush_interval = 16,
  max_batch_size = 100,
  timer = nil,
}

function M.configure(opts)
  M.flush_interval = opts.flush_interval or 16
  M.max_batch_size = opts.max_batch_size or 100
end

function M.get_config()
  return {
    flush_interval = M.flush_interval,
    max_batch_size = M.max_batch_size,
  }
end

function M.push(buffer, line, text, is_error)
  table.insert(M.updates, {
    buffer = buffer,
    line = line,
    text = text,
    is_error = is_error,
    timestamp = vim.loop.now(),
  })
  
  if #M.updates >= M.max_batch_size then
    M.flush()
  end
end

function M.flush()
  local updates = M.updates
  M.updates = {}
  
  if M.timer then
    vim.timer.stop(M.timer)
    M.timer = nil
  end
  
  return updates
end

function M.schedule_flush()
  if M.timer then
    return
  end
  
  M.timer = vim.defer_fn(function()
    M.timer = nil
    M.flush()
  end, M.flush_interval)
end

function M.clear()
  M.updates = {}
  if M.timer then
    vim.timer.stop(M.timer)
    M.timer = nil
  end
end

function M.size()
  return #M.updates
end

return M