local M = {
  scheduler = nil,
}

function M.init()
  if M.scheduler then
    return
  end
  M.scheduler = {}
end

function M.schedule(fn)
  vim.defer_fn(fn, 0)
end

function M.schedule_blocking(fn)
  vim.schedule(fn)
end

function M.schedule_delayed(fn, delay_ms)
  vim.defer_fn(fn, delay_ms)
end

function M.is_async()
  return vim.fn.has('nvim-0.11') == 1
end

return M