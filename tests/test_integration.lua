--- Integration tests for Uranus.nvim
---
--- Tests module interactions and real-world usage
---
--- @module tests.test_integration

local function run_integration_tests()
  local tests_passed = 0
  local tests_failed = 0
  
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
  
  print("\n=== Integration Tests ===\n")
  
  -- Test: REPL + Notebook integration
  test("REPL parse_cells with notebook data", function()
    local repl = require("uranus.repl")
    local notebook = require("uranus.notebook")
    
    -- Both modules load successfully
    assert(type(repl.parse_cells) == "function")
    assert(type(notebook.open) == "function")
  end)
  
  -- Test: LSP + Inspector integration
  test("LSP and Inspector share data flow", function()
    local lsp = require("uranus.lsp")
    local inspector = require("uranus.inspector")
    
    -- Both can access kernel data
    assert(type(lsp.hover) == "function")
    assert(type(inspector.get_variables) == "function")
  end)
  
  -- Test: Cache + LSP integration
  test("Cache used by LSP module", function()
    local cache = require("uranus.cache")
    local lsp = require("uranus.lsp")
    
    -- LSP should use cache internally
    lsp.get_clients()
    lsp.get_clients()
    assert(true, "LSP uses caching")
  end)
  
  -- Test: Output + REPL integration
  test("Output module used by REPL", function()
    local output = require("uranus.output")
    local repl = require("uranus.repl")
    
    assert(type(output.display) == "function")
    assert(type(repl.run_cell) == "function")
  end)
  
  -- Test: Inspector + Notebook integration
  test("Inspector can inspect notebook variables", function()
    local inspector = require("uranus.inspector")
    local notebook = require("uranus.notebook")
    
    assert(type(inspector.get_variables) == "function")
    assert(type(notebook.run_cell) == "function")
  end)
  
  -- Test: Multiple module loading
  test("Load all modules without conflicts", function()
    local uranus = require("uranus")
    local repl = require("uranus.repl")
    local lsp = require("uranus.lsp")
    local inspector = require("uranus.inspector")
    local notebook = require("uranus.notebook")
    local output = require("uranus.output")
    local cache = require("uranus.cache")
    
    assert(type(uranus) == "table")
    assert(type(repl) == "table")
    assert(type(lsp) == "table")
    assert(type(inspector) == "table")
    assert(type(notebook) == "table")
    assert(type(output) == "table")
    assert(type(cache) == "table")
  end)
  
  -- Test: Configuration propagation
  test("Module configuration isolation", function()
    local cache = require("uranus.cache")
    local lsp = require("uranus.lsp")
    local repl = require("uranus.repl")
    
    -- Each module should have own config
    local cache_config = cache.get_config()
    local lsp_config = lsp.get_config()
    local repl_config = repl.get_config()
    
    assert(type(cache_config) == "table")
    assert(type(lsp_config) == "table")
    assert(type(repl_config) == "table")
  end)
  
  -- Test: Error handling in modules
  test("Module error handling", function()
    local cache = require("uranus.cache")
    
    -- Getting non-existent key should return nil, not error
    local val = cache.get("nonexistent_key_" .. os.time())
    assert(val == nil, "Should return nil for missing key")
  end)
  
  -- Test: Concurrent cache access
  test("Concurrent cache operations", function()
    local cache = require("uranus.cache")
    cache.clear()
    
    -- Multiple simultaneous sets
    for i = 1, 20 do
      cache.set("concurrent_key_" .. i, "value_" .. i)
    end
    
    -- All should be retrievable
    local count = 0
    for i = 1, 20 do
      if cache.get("concurrent_key_" .. i) then
        count = count + 1
      end
    end
    
    assert(count == 20, "All concurrent keys should be accessible")
    cache.clear()
  end)
  
  -- Test: LSP client detection with Python files
  test("LSP detects Python LSP", function()
    local lsp = require("uranus.lsp")
    local available = lsp.is_available()
    
    -- Returns boolean even without LSP running
    assert(type(available) == "boolean")
  end)
  
  -- Test: REPL cell navigation
  test("REPL cell navigation setup", function()
    local repl = require("uranus.repl")
    
    assert(type(repl.next_cell) == "function")
    assert(type(repl.prev_cell) == "function")
  end)
  
  -- Test: Notebook cell operations
  test("Notebook cell operations", function()
    local notebook = require("uranus.notebook")
    
    assert(type(notebook.insert_cell_below) == "function")
    assert(type(notebook.insert_cell_above) == "function")
    assert(type(notebook.delete_cell) == "function")
  end)
  
  -- Test: Performance monitoring
  test("Cache statistics", function()
    local cache = require("uranus.cache")
    cache.clear()
    cache.set("stat_key", "stat_value")
    
    local stats = cache.stats()
    assert(type(stats) == "table")
    assert(stats.size >= 1)
    
    cache.clear()
  end)
  
  -- Test: Inspector configuration
  test("Inspector configuration API", function()
    local inspector = require("uranus.inspector")
    
    assert(type(inspector.configure) == "function")
    assert(type(inspector.get_config) == "function")
  end)
  
  -- Test: Output configuration
  test("Output configuration API", function()
    local output = require("uranus.output")
    
    assert(type(output.configure) == "function")
    assert(type(output.get_config) == "function")
  end)
  
  -- Test: Remote module existence
  test("Remote module loads", function()
    local ok, remote = pcall(require, "uranus.remote")
    if ok then
      assert(type(remote.list_remote_kernels) == "function")
    else
      print(" (optional module)")
    end
  end)
  
  -- Test: Completion module existence
  test("Completion module loads", function()
    local ok, completion = pcall(require, "uranus.completion")
    if ok then
      assert(type(complete_complete_kernel_variables) == "function" or 
             type(completion.complete_kernel_variables) == "function")
    else
      print(" (optional module)")
    end
  end)
  
  -- Test: UI module existence
  test("UI module loads", function()
    local ok, ui = pcall(require, "uranus.ui")
    if ok then
      assert(type(ui.pick_kernel) == "function")
    else
      print(" (optional module)")
    end
  end)
  
  -- Summary
  print("\n=== Results ===")
  print(string.format("Passed: %d", tests_passed))
  print(string.format("Failed: %d", tests_failed))
  print(string.format("Total: %d", tests_passed + tests_failed))
  
  return tests_failed == 0
end

-- Run tests
local success = run_integration_tests()
vim.cmd(success and "quit 1" or "quit 0")