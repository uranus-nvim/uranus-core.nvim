local M = {}

local config = nil

local function get_config()
  if not config then
    local cfg = require("uranus.config")
    local defaults = cfg.get("cache") or {}
    config = vim.deepcopy(defaults)
  end
  return config
end

local cache = {}
local order = {}

local function make_key(...)
    local n = select("#", ...)
    if n == 1 then
        local v = select(1, ...)
        if type(v) == "string" then return v end
    end
    local parts = {}
    for i = 1, n do
        local v = select(i, ...)
        if type(v) == "table" then
            table.insert(parts, vim.inspect(v))
        else
            table.insert(parts, tostring(v))
        end
    end
    return table.concat(parts, ":")
end

local function is_expired(entry)
    local cfg = get_config()
    if not cfg.enabled then
        return true
    end
    local now = vim.loop.now()
    return now - entry.timestamp > entry.ttl
end

function M.configure(opts)
    config = vim.tbl_deep_extend("force", get_config(), opts or {})
end

function M.get_config()
    return get_config()
end

function M.set(key, value, ttl)
    local cfg = get_config()
    ttl = ttl or cfg.ttl
    
    if not cfg.enabled then
        return
    end
    
    if #cache >= cfg.max_size and not cache[key] then
        local oldest = table.remove(order, 1)
        if oldest then cache[oldest] = nil end
    end
    
    cache[key] = {
        value = value,
        timestamp = vim.loop.now(),
        ttl = ttl,
    }
    
    if not vim.tbl_contains(order, key) then
        table.insert(order, key)
    end
end

function M.get(key)
    local entry = cache[key]
    if not entry then
        return nil
    end
    
    if is_expired(entry) then
        cache[key] = nil
        for i, k in ipairs(order) do
            if k == key then table.remove(order, i) break end
        end
        return nil
    end
    
    for i, k in ipairs(order) do
        if k == key then
            table.remove(order, i)
            table.insert(order, key)
            break
        end
    end
    
    return entry.value
end

function M.has(key)
    return M.get(key) ~= nil
end

function M.invalidate(key)
    if cache[key] then
        cache[key] = nil
        for i, k in ipairs(order) do
            if k == key then table.remove(order, i) break end
        end
    end
end

function M.clear()
    cache = {}
    order = {}
end

function M.size()
    return #order
end

function M.keys()
    return vim.deepcopy(order)
end

function M.stats()
    return {
        size = M.size(),
        max_size = config.max_size,
        ttl = config.ttl,
        enabled = config.enabled,
    }
end

function M.memoize(fn)
    return function(...)
        local key = make_key(...)
        local cached = M.get(key)
        if cached ~= nil then
            return cached
        end
        
        local result = fn(...)
        M.set(key, result)
        return result
    end
end

function M.async_memoize(fn, ttl)
    return function(...)
        local key = make_key(...)
        local cached = M.get(key)
        if cached ~= nil then
            return cached
        end
        
        local args = {...}
        local cb = table.remove(args, #args)
        fn(function(result)
            M.set(key, result, ttl)
            cb(result)
        end, unpack(args))
    end
end

return M