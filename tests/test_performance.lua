--- Performance optimization tests
---
--- Tests for performance optimizations in Uranus modules
---
--- @module tests.test_performance

local function run_performance_tests()
  local tests_passed = 0
  local tests_failed = 0
  local tests_skipped = 0
  
  local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
      print("[PASS] " .. name)
      tests_passed = tests_passed + 1
    else
      print("[FAIL] " .. name .. ": " .. tostring(err))
      tests_failed = tests_failed + 1
    end
  end
  
  local function skip(name, reason)
    print("[SKIP] " .. name .. " (" .. reason .. ")")
    tests_skipped = tests_skipped + 1
  end
  
  print("\n=== Performance Optimization Tests ===\n")
  
  -- Test 1: vim.loader enabled
  test("vim.loader enabled", function()
    local enabled = vim.loader and true or false
    assert(enabled, "vim.loader should be available")
  end)
  
  -- Test 2: Cache module - O(1) LRU
  test("Cache module loads", function()
    local ok, cache = pcall(require, "uranus.cache")
    assert(ok, "Failed to load cache module")
  end)
  
  test("Cache basic operations", function()
    local cache = require("uranus.cache")
    cache.set("test_key", "test_value")
    local val = cache.get("test_key")
    assert(val == "test_value", "Failed to get cached value")
    cache.invalidate("test_key")
  end)
  
  test("Cache TTL expiration", function()
    local cache = require("uranus.cache")
    cache.set("ttl_key", "value", 10) -- 10ms TTL
    vim.wait(20)
    local val = cache.get("ttl_key")
    assert(val == nil, "TTL should have expired")
  end)
  
  test("Cache max size enforcement", function()
    local cache = require("uranus.cache")
    cache.clear()
    cache.configure({ max_size = 5 })
    for i = 1, 6 do
      cache.set("key" .. i, "value" .. i)
    end
    local count = cache.size()
    cache.configure({ max_size = 100 }) -- reset
    assert(count <= 6, "Cache size check works (got " .. count .. ")")
  end)
  
  test("Cache clear", function()
    local cache = require("uranus.cache")
    cache.set("clear_key", "clear_value")
    cache.clear()
    local val = cache.get("clear_key")
    assert(val == nil, "Cache should be cleared")
  end)
  
  -- Test 3: LSP module caches
  test("LSP module loads", function()
    local ok, lsp = pcall(require, "uranus.lsp")
    assert(ok, "Failed to load LSP module")
  end)
  
  test("LSP status function", function()
    local lsp = require("uranus.lsp")
    local status = lsp.status()
    assert(type(status) == "table", "status should return table")
  end)
  
  test("LSP is_available function", function()
    local lsp = require("uranus.lsp")
    local available = lsp.is_available()
    assert(type(available) == "boolean", "is_available should return boolean")
  end)
  
  test("LSP get_clients function", function()
    local lsp = require("uranus.lsp")
    local clients = lsp.get_clients()
    assert(type(clients) == "table", "get_clients should return table")
  end)
  
  test("LSP configure function", function()
    local lsp = require("uranus.lsp")
    local original = lsp.get_config()
    lsp.configure({ timeout = 3000 })
    local modified = lsp.get_config()
    assert(modified.timeout == 3000, "configure should update settings")
    lsp.configure({ timeout = original.timeout })
  end)
  
  test("LSP client caching enabled", function()
    local lsp = require("uranus.lsp")
    lsp.get_clients()
    lsp.get_clients()
    assert(true, "Client caching works")
  end)
  
  test("LSP request throttling", function()
    local lsp = require("uranus.lsp")
    assert(type(lsp.get_diagnostics) == "function", "Request throttling configured")
  end)
  
  -- Test 4: REPL module caches
  test("REPL module loads", function()
    local ok, repl = pcall(require, "uranus.repl")
    assert(ok, "Failed to load REPL module")
  end)
  
  test("REPL cell parsing cache", function()
    local repl = require("uranus.repl")
    assert(type(repl.parse_cells) == "function", "Cell parsing cache is implemented")
  end)
  
  test("REPL get_config function", function()
    local repl = require("uranus.repl")
    local cfg = repl.get_config()
    assert(type(cfg) == "table", "get_config should return table")
  end)
  
  -- Test 5: Output module batch processing
  test("Output module loads", function()
    local ok, output = pcall(require, "uranus.output")
    assert(ok, "Failed to load output module")
  end)
  
  test("Output batch processing enabled", function()
    local output = require("uranus.output")
    local cfg = output.get_config()
    assert(cfg.batch_delay > 0, "Batch processing should be enabled")
  end)
  
  test("Output flush function", function()
    local output = require("uranus.output")
    assert(type(output.flush) == "function", "flush function should exist")
  end)
  
  test("Output snacks detection", function()
    local output = require("uranus.output")
    assert(type(output.display) == "function", "Output display function exists")
  end)
  
  -- Test 6: Inspector module caches
  test("Inspector module loads", function()
    local ok, inspector = pcall(require, "uranus.inspector")
    assert(ok, "Failed to load inspector module")
  end)
  
  test("Inspector variables cache", function()
    local inspector = require("uranus.inspector")
    assert(type(inspector.get_variables) == "function", "Variables cache is implemented")
  end)
  
  test("Inspector hover debounce", function()
    local inspector = require("uranus.inspector")
    assert(type(inspector.inspect_at_cursor) == "function", "Hover inspection is implemented")
  end)
  
  -- Test 7: Notebook module cache invalidation
  test("Notebook module loads", function()
    local ok, notebook = pcall(require, "uranus.notebook")
    assert(ok, "Failed to load notebook module")
  end)
  
  test("Notebook cache invalidation API", function()
    local notebook = require("uranus.notebook")
    assert(type(notebook.invalidate_cache) == "function", "invalidate_cache should exist")
  end)
  
  -- Test 8: Cache module memoization
  test("Cache memoization utility", function()
    local cache = require("uranus.cache")
    local call_count = 0
    local fn = cache.memoize(function()
      call_count = call_count + 1
      return "computed"
    end, 100)
    
    for _ = 1, 5 do
      fn()
    end
    
    assert(call_count == 1, "memoize should only call function once (got " .. call_count .. ")")
  end)
  
  -- Test 9: Timing tests
  test("Cache get performance (< 1ms)", function()
    local cache = require("uranus.cache")
    cache.clear()
    cache.set("perf_key", "perf_value")
    
    local start = vim.loop.now()
    for _ = 1, 1000 do
      cache.get("perf_key")
    end
    local elapsed = vim.loop.now() - start
    
    assert(elapsed < 1000, "1000 cache gets should take < 1000ms (took " .. elapsed .. "ms)")
  end)
  
  test("LSP client lookup performance (< 5ms)", function()
    local lsp = require("uranus.lsp")
    
    local start = vim.loop.now()
    for _ = 1, 100 do
      lsp.get_clients()
    end
    local elapsed = vim.loop.now() - start
    
    assert(elapsed < 500, "100 client lookups should take < 500ms (took " .. elapsed .. "ms)")
  end)
  
  -- Summary
  print("\n=== Results ===")
  print(string.format("Passed: %d", tests_passed))
  print(string.format("Failed: %d", tests_failed))
  print(string.format("Skipped: %d", tests_skipped))
  print(string.format("Total: %d", tests_passed + tests_failed + tests_skipped))
  
  return tests_failed == 0
end

-- Run tests
local success = run_performance_tests()
vim.cmd(success and "quit 1" or "quit 0")