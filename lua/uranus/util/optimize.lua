local M = {}

M.SmallVec = {}

function M.SmallVec.new(capacity)
  local self = setmetatable({}, { __index = M.SmallVec })
  self.capacity = capacity or 16
  self.data = {}
  self.size = 0
  return self
end

function M.SmallVec:push(item)
  if self.size < self.capacity then
    self.data[self.size + 1] = item
  else
    table.insert(self.data, item)
  end
  self.size = self.size + 1
end

function M.SmallVec:get(i)
  return self.data[i]
end

function M.SmallVec:len()
  return self.size
end

function M.SmallVec:clear()
  self.data = {}
  self.size = 0
end

function M.small_string(str, max_len)
  if #str <= max_len then
    return str
  end
  return string.sub(str, 1, max_len - 3) .. "..."
end

function M.intern(str)
  local cache = M._string_cache or {}
  if cache[str] then
    return cache[str]
  end
  cache[str] = str
  M._string_cache = cache
  return str
end

function M.clear_cache()
  M._string_cache = nil
end

return M