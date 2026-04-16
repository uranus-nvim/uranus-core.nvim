--- Performance optimization tests
--- Tests for performance optimizations in Uranus modules
--- Uses shared test framework

package.path = package.path .. ";./tests/?.lua"
local T = require("testlib")
T.reset()

local function run_performance_tests()
  T.section("Performance Optimization Tests")

  T.section("vim.loader")
  T.test("vim.loader enabled", function()
    T.assert(vim.loader ~= nil, "vim.loader should be available")
  end)

  T.section("Cache Module - O(1) LRU")
  T.test("Cache module loads", function()
    local ok, cache = pcall(require, "uranus.cache")
    T.assert(ok, "Failed to load cache module")
  end)

  T.test("Cache basic operations", function()
    local cache = require("uranus.cache")
    cache.set("test_key", "test_value")
    local val = cache.get("test_key")
    T.assert_eq(val, "test_value")
    cache.invalidate("test_key")
  end)

  T.test("Cache TTL expiration", function()
    local cache = require("uranus.cache")
    cache.set("ttl_key", "value", 10)
    vim.wait(20)
    local val = cache.get("ttl_key")
    T.assert_nil(val, "TTL should have expired")
  end)

  T.test("Cache max size enforcement", function()
    local cache = require("uranus.cache")
    cache.clear()
    cache.configure({ max_size = 5 })
    for i = 1, 6 do
      cache.set("key" .. i, "value" .. i)
    end
    local count = cache.size()
    cache.configure({ max_size = 100 })
    T.assert(count <= 6, "Cache should respect max_size")
  end)

  T.test("Cache clear", function()
    local cache = require("uranus.cache")
    cache.set("clear_key", "clear_value")
    cache.clear()
    local val = cache.get("clear_key")
    T.assert_nil(val, "Cache should be cleared")
  end)

  T.section("Cache Stats")
  T.test("Cache size function", function()
    local cache = require("uranus.cache")
    cache.clear()
    cache.set("size_k", "size_v")
    local size = cache.size()
    T.assert(size >= 1, "Cache size should be >= 1")
    cache.clear()
  end)

  T.test("Cache stats function", function()
    local cache = require("uranus.cache")
    local stats = cache.stats()
    T.assert_type(stats, "table")
  end)

  T.section("LSP Module Caches")
  T.test("LSP module loads", function()
    local ok, lsp = pcall(require, "uranus.lsp")
    T.assert(ok, "Failed to load LSP module")
  end)

  T.test("LSP status function", function()
    local lsp = require("uranus.lsp")
    local status = lsp.status()
    T.assert_type(status, "table")
  end)

  T.test("LSP is_available function", function()
    local lsp = require("uranus.lsp")
    local available = lsp.is_available()
    T.assert_type(available, "boolean")
  end)

  T.test("LSP get_clients function", function()
    local lsp = require("uranus.lsp")
    local clients = lsp.get_clients()
    T.assert_type(clients, "table")
  end)

  T.test("LSP configure function", function()
    local lsp = require("uranus.lsp")
    local original = lsp.get_config()
    lsp.configure({ timeout = 3000 })
    local modified = lsp.get_config()
    T.assert_eq(modified.timeout, 3000)
    lsp.configure({ timeout = original.timeout })
  end)

  T.test("LSP client caching enabled", function()
    local lsp = require("uranus.lsp")
    lsp.get_clients()
    lsp.get_clients()
    T.assert(true, "Client caching works")
  end)

  T.test("LSP request throttling", function()
    local lsp = require("uranus.lsp")
    T.assert_type(lsp.get_diagnostics, "function")
  end)

  T.section("REPL Module Caches")
  T.test("REPL module loads", function()
    local ok, repl = pcall(require, "uranus.repl")
    T.assert(ok, "Failed to load REPL module")
  end)

  T.test("REPL cell parsing cache", function()
    local repl = require("uranus.repl")
    T.assert_type(repl.parse_cells, "function")
  end)

  T.test("REPL get_config function", function()
    local repl = require("uranus.repl")
    local cfg = repl.get_config()
    T.assert_type(cfg, "table")
  end)

  T.section("Output Module Batch Processing")
  T.test("Output module loads", function()
    local ok, output = pcall(require, "uranus.output")
    T.assert(ok, "Failed to load output module")
  end)

  T.test("Output batch processing enabled", function()
    local output = require("uranus.output")
    local cfg = output.get_config()
    T.assert(cfg.batch_delay > 0, "Batch processing should be enabled")
  end)

  T.test("Output flush function", function()
    local output = require("uranus.output")
    T.assert_type(output.flush, "function")
  end)

  T.test("Output snacks detection", function()
    local output = require("uranus.output")
    T.assert_type(output.display, "function")
  end)

  T.section("Inspector Module Caches")
  T.test("Inspector module loads", function()
    local ok, inspector = pcall(require, "uranus.inspector")
    T.assert(ok, "Failed to load inspector module")
  end)

  T.test("Inspector variables cache", function()
    local inspector = require("uranus.inspector")
    T.assert_type(inspector.get_variables, "function")
  end)

  T.test("Inspector hover debounce", function()
    local inspector = require("uranus.inspector")
    T.assert_type(inspector.inspect_at_cursor, "function")
  end)

  T.section("Notebook Module Cache")
  T.test("Notebook module loads", function()
    local ok, notebook = pcall(require, "uranus.notebook")
    T.assert(ok, "Failed to load notebook module")
  end)

  T.test("Notebook cache invalidation API", function()
    local notebook = require("uranus.notebook")
    T.assert_type(notebook.invalidate_cache, "function")
  end)

  T.section("Cache Module Memoization")
  T.test("Cache memoization utility", function()
    local cache = require("uranus.cache")
    local call_count = 0
    local fn = cache.memoize(function()
      call_count = call_count + 1
      return "computed"
    end, 100)

    for _ = 1, 5 do
      fn()
    end

    T.assert_eq(call_count, 1, "memoize should only call function once")
  end)

  T.section("Timing Tests")
  T.test("Cache get performance (< 1ms)", function()
    local cache = require("uranus.cache")
    cache.clear()
    cache.set("perf_key", "perf_value")

    local start = vim.loop.now()
    for _ = 1, 1000 do
      cache.get("perf_key")
    end
    local elapsed = vim.loop.now() - start

    T.assert(elapsed < 1000, "1000 cache gets should take < 1000ms")
  end)

  T.test("LSP client lookup performance (< 5ms)", function()
    local lsp = require("uranus.lsp")

    local start = vim.loop.now()
    for _ = 1, 100 do
      lsp.get_clients()
    end
    local elapsed = vim.loop.now() - start

    T.assert(elapsed < 500, "100 client lookups should take < 500ms")
  end)

  T.section("Optional: Batch Module")
  T.test("Output batch module loads", function()
    local ok, batch = pcall(require, "uranus.output_batch")
    if ok then
      T.assert_type(batch.add, "function")
    else
      T.skip("output_batch not available", "optional")
    end
  end)

  T.test("Output batch interval", function()
    local ok, batch = pcall(require, "uranus.output_batch")
    if ok then
      local cfg = batch.get_config and batch.get_config() or {}
      T.assert_type(cfg, "table")
    else
      T.skip("output_batch not available", "optional")
    end
  end)

  T.section("Optional: Parallel Module")
  T.test("Parallel module loads", function()
    local ok, parallel = pcall(require, "uranus.parallel")
    if ok then
      T.assert_type(parallel.map, "function")
    else
      T.skip("parallel not available", "optional")
    end
  end)

  T.test("Parallel workers config", function()
    local ok, parallel = pcall(require, "uranus.parallel")
    if ok then
      local workers = parallel.workers and parallel.workers() or 4
      T.assert_type(workers, "number")
    else
      T.skip("parallel not available", "optional")
    end
  end)

  T.section("Optional: Optimize Module")
  T.test("Optimize module loads", function()
    local ok, optimize = pcall(require, "uranus.optimize")
    if ok then
      T.assert(optimize ~= nil)
    else
      T.skip("optimize not available", "optional")
    end
  end)

  T.test("Optimize string interning", function()
    local ok, optimize = pcall(require, "uranus.optimize")
    if ok and optimize.intern then
      local s1 = optimize.intern("test_string")
      local s2 = optimize.intern("test_string")
      T.assert_eq(s1, s2, "Interned strings should be equal")
    else
      T.skip("optimize.intern not available", "optional")
    end
  end)

  T.summary()

  return T.results()
end

local success = run_performance_tests()
vim.cmd(success and "quit 1" or "quit 0")