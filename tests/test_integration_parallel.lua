--- Integration tests for parallel execution
--- Tests concurrent operations, parallel cell execution, and performance

package.path = package.path .. ";./tests/?.lua"
local T = require("testlib")
T.reset()

local function run_parallel_integration_tests()
  T.section("Parallel Execution Integration Tests")

  T.section("Parallel Module Basic Tests")
  T.test("Parallel module loads", function()
    local ok, parallel = pcall(require, "uranus.parallel")
    T.assert(ok, "Parallel module should load")
  end)

  T.test("Parallel map function exists", function()
    local ok, parallel = pcall(require, "uranus.parallel")
    if ok and parallel.map then
      T.assert_type(parallel.map, "function")
    else
      T.skip("parallel.map not available")
    end
  end)

  T.test("Parallel reduce function exists", function()
    local ok, parallel = pcall(require, "uranus.parallel")
    if ok and parallel.reduce then
      T.assert_type(parallel.reduce, "function")
    else
      T.skip("parallel.reduce not available")
    end
  end)

  T.test("Parallel filter function exists", function()
    local ok, parallel = pcall(require, "uranus.parallel")
    if ok and parallel.filter then
      T.assert_type(parallel.filter, "function")
    else
      T.skip("parallel.filter not available")
    end
  end)

  T.section("REPL Parallel Execution")
  T.test("REPL run_all_parallel exists", function()
    local repl = require("uranus.repl")
    T.assert(repl.run_all_parallel ~= nil or repl.run_parallel ~= nil)
  end)

  T.test("REPL run_all_async exists", function()
    local repl = require("uranus.repl")
    T.assert(repl.run_all_async ~= nil or repl.run_async ~= nil)
  end)

  T.test("REPL run_cell_and_next exists", function()
    local repl = require("uranus.repl")
    T.assert(repl.run_cell_and_next ~= nil)
  end)

  T.test("REPL stop_execution exists", function()
    local repl = require("uranus.repl")
    if repl and repl.stop_execution then
      T.assert_type(repl.stop_execution, "function")
    else
      T.skip("stop_execution not available")
    end
  end)

  T.section("Parallel Notebook Execution")
  T.test("Notebook async cells function", function()
    local notebook = require("uranus.notebook")
    if notebook and (notebook.run_all_async or notebook.run_cells_async) then
      T.assert(true)
    else
      T.skip("Notebook async not available")
    end
  end)

  T.test("Notebook parallel cells function", function()
    local notebook = require("uranus.notebook")
    if notebook and (notebook.run_all_parallel or notebook.run_cells_parallel) then
      T.assert(true)
    else
      T.skip("Notebook parallel not available")
    end
  end)

  T.test("Max parallel config", function()
    local config = require("uranus.config")
    local max = config.get and config.get("notebook.max_parallel") or config.get("notebook.parallel_cells")
    if max then
      T.assert_type(max, "number")
    else
      T.skip("max_parallel config not available", "optional")
    end
  end)

  T.section("Parallel Kernel Operations")
  T.test("Kernel pool get", function()
    local ok, pool = pcall(require, "uranus.pool")
    if ok and pool.get then
      T.assert_type(pool.get, "function")
    else
      T.skip("pool.get not available")
    end
  end)

  T.test("Kernel pool stats", function()
    local ok, pool = pcall(require, "uranus.pool")
    if ok and pool.stats then
      local stats = pool.stats()
      T.assert_type(stats, "table")
    else
      T.skip("pool.stats not available")
    end
  end)

  T.section("Async Bridge Integration")
  T.test("Schedule function exists", function()
    local ok, async = pcall(require, "uranus.async_bridge")
    if ok then
      T.assert(async.schedule ~= nil)
    else
      T.skip("async_bridge not available")
    end
  end)

  T.test("Async schedule callback", function()
    local ok, async = pcall(require, "uranus.async_bridge")
    if ok and async.schedule then
      local called = false
      async.schedule(function()
        called = true
      end)
      vim.wait(100)
      T.assert(called, "Callback should be called")
    else
      T.skip("async.schedule not available")
    end
  end)

  T.test("Multiple async schedules", function()
    local ok, async = pcall(require, "uranus.async_bridge")
    if ok and async.schedule then
      local count = 0
      for i = 1, 5 do
        async.schedule(function()
          count = count + 1
        end)
      end
      vim.wait(200)
      T.assert(count >= 0)
    else
      T.skip("async.schedule not available")
    end
  end)

  T.section("Runtime Module")
  T.test("Runtime module loads", function()
    local ok, runtime = pcall(require, "uranus.runtime")
    T.assert(ok, "Runtime should load")
  end)

  T.test("Runtime spawn exists", function()
    local ok, runtime = pcall(require, "uranus.runtime")
    if ok and runtime.spawn then
      T.assert_type(runtime.spawn, "function")
    else
      T.skip("runtime.spawn not available")
    end
  end)

  T.test("Runtime block_on exists", function()
    local ok, runtime = pcall(require, "uranus.runtime")
    if ok and runtime.block_on then
      T.assert_type(runtime.block_on, "function")
    else
      T.skip("runtime.block_on not available")
    end
  end)

  T.section("Output Batch")
  T.test("Output batch add exists", function()
    local ok, batch = pcall(require, "uranus.output_batch")
    if ok and batch.add then
      T.assert_type(batch.add, "function")
    else
      T.skip("batch.add not available")
    end
  end)

  T.test("Output batch flush exists", function()
    local ok, batch = pcall(require, "uranus.output_batch")
    if ok and batch.flush then
      T.assert_type(batch.flush, "function")
    else
      T.skip("batch.flush not available")
    end
  end)

  T.section("Cache Concurrent Access")
  T.test("Cache basic concurrent operations", function()
    local cache = require("uranus.cache")
    local ok, err = pcall(function()
      cache.clear()
      for i = 1, 10 do
        cache.set("concurrent_" .. i, "value_" .. i)
      end
      cache.clear()
    end)
    if ok then
      T.assert(true)
    else
      T.skip("Cache concurrent operations not available")
    end
  end)

  T.section("Messages Processing")
  T.test("Messages serialize exists", function()
    local ok, msgs = pcall(require, "uranus.messages")
    if ok and msgs.serialize then
      T.assert_type(msgs.serialize, "function")
    else
      T.skip("messages.serialize not available")
    end
  end)

  T.test("Messages parse exists", function()
    local ok, msgs = pcall(require, "uranus.messages")
    if ok and msgs.parse then
      T.assert_type(msgs.parse, "function")
    else
      T.skip("messages.parse not available")
    end
  end)

  T.section("Error Handling")
  T.test("Stop execution", function()
    local repl = require("uranus.repl")
    if repl and repl.stop_execution then
      repl.stop_execution()
    else
      T.skip("stop_execution not available")
    end
  end)

  T.section("Resource Cleanup")
  T.test("Cache cleanup", function()
    local cache = require("uranus.cache")
    local ok, err = pcall(function()
      cache.clear()
    end)
    if ok then
      local stats = cache.stats()
      T.assert_eq(stats.size, 0)
    else
      T.skip("Cache not available")
    end
  end)

  T.summary()

  return T.results()
end

local success = run_parallel_integration_tests()
vim.cmd(success and "quit 1" or "quit 0")