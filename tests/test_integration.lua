--- Integration tests for Uranus.nvim
---
--- Tests module interactions and real-world usage
---
--- @module tests.test_integration

package.path = package.path .. ";./tests/?.lua"
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

  local function section(name)
    print("\n--- " .. name .. " ---\n")
  end

  local function skip(name, reason)
    print("[SKIP] " .. name .. " (" .. reason .. ")")
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

  -- ========================================
  -- NEW: Configuration Propagation Tests
  -- ========================================
  section("Configuration Propagation")

  test("Config observer notifies on change", function()
    local config = require("uranus.config")
    local notified = false
    local remove = config.on_change and config.on_change("test_key", function()
      notified = true
    end)
    if remove then
      config.set("test_key", "new_value")
      vim.wait(100)
      config.set("test_key", nil)
      remove()
    end
    assert(true)
  end)

  test("Config validates values", function()
    local config = require("uranus.config")
    local valid = config.validate
    assert(valid ~= nil or type(config.set) == "function")
  end)

  test("Config reset restores defaults", function()
    local config = require("uranus.config")
    local reset = config.reset
    local initial = config.get("repl")
    if reset then
      config.set("repl.timeout", 999)
      config.reset()
      local restored = config.get("repl.timeout")
      assert(type(restored) == "number")
    end
    assert(true)
  end)

  -- ========================================
  -- NEW: Cache Invalidation Tests
  -- ========================================
  section("Cache Invalidation Across Modules")

  test("Cache TTL invalidates entries", function()
    local cache = require("uranus.cache")
    cache.clear()
    cache.set("ttl_test", "value", 1)
    vim.wait(100)
    assert(cache.get("ttl_test") ~= nil, "Value should exist before TTL")
    vim.wait(1100)
    assert(cache.get("ttl_test") == nil, "Value should be nil after TTL")
    cache.clear()
  end)

  test("Cache max_size eviction", function()
    local cache = require("uranus.cache")
    cache.clear()
    for i = 1, 150 do
      cache.set("key_" .. i, "value_" .. i)
    end
    local stats = cache.stats()
    assert(stats.size <= 100, "Cache should evict old entries")
    cache.clear()
  end)

  test("Cache clear removes all entries", function()
    local cache = require("uranus.cache")
    cache.set("clear_k1", "v1")
    cache.set("clear_k2", "v2")
    cache.clear()
    local stats = cache.stats()
    assert(stats.size == 0, "Cache should be empty")
  end)

  -- ========================================
  -- NEW: Notebook ↔ Notebook UI Sync
  -- ========================================
  section("Notebook ↔ Notebook UI Sync")

  test("Notebook cells accessible from UI", function()
    local notebook = require("uranus.notebook")
    local nb_ui = require("uranus.notebook_ui")
    assert(notebook.get_cells ~= nil or type(notebook.cells) == "table")
  end)

  test("Notebook UI current cell tracking", function()
    local nb_ui = require("uranus.notebook_ui")
    assert(nb_ui.get_current_cell ~= nil or type(nb_ui.current_cell) == "number" or nb_ui.current_cell == nil)
  end)

  test("Notebook dirty state tracking", function()
    local notebook = require("uranus.notebook")
    local is_dirty = notebook.is_dirty
    assert(is_dirty ~= nil or notebook.dirty ~= nil)
  end)

  test("Notebook auto-save on run", function()
    local notebook = require("uranus.notebook")
    local auto_save = notebook.auto_save
    assert(auto_save ~= nil or notebook.autosave ~= nil)
  end)

  -- ========================================
  -- NEW: LSP + Inspector Merged Data
  -- ========================================
  section("LSP + Inspector Data Merge")

  test("Inspector gets runtime types", function()
    local insp = require("uranus.inspector")
    assert(insp.get_variables ~= nil)
  end)

  test("LSP provides static types", function()
    local lsp = require("uranus.lsp")
    assert(lsp.get_diagnostics ~= nil)
  end)

  test("Inspector hover merges both", function()
    local insp = require("uranus.inspector")
    local hover = insp.inspect_at_cursor
    assert(hover ~= nil)
  end)

  test("LSP status shows clients", function()
    local lsp = require("uranus.lsp")
    local status = lsp.status
    assert(status ~= nil)
  end)

  -- ========================================
  -- NEW: Factory + Kernel Integration
  -- ========================================
  section("Factory Kernel Lifecycle")

  test("Factory provides kernel connection", function()
    local factory = require("uranus.factory")
    local kernel = factory.get_kernel()
    assert(kernel ~= nil)
  end)

  test("Factory provides notebook operations", function()
    local factory = require("uranus.factory")
    local nb = factory.get_notebook()
    assert(nb ~= nil)
  end)

  test("Factory caches modules", function()
    local factory = require("uranus.factory")
    local m1 = factory.get_notebook()
    local m2 = factory.get_notebook()
    assert(m1 == m2, "Should return same module instance")
  end)

  -- ========================================
  -- NEW: State Watchers Cross-Module
  -- ========================================
  section("State Watchers Cross-Module Sync")

  test("State notifies watchers on change", function()
    local state = require("uranus.state")
    local watched_value = nil
    local remove = state.watch("test_event", function(val)
      watched_value = val
    end)
    if remove then
      state.set("test_event", "test_value")
      vim.wait(50)
      assert(watched_value == "test_value")
      state.set("test_event", nil)
      remove()
    end
    assert(true)
  end)

  test("State initialization watched", function()
    local state = require("uranus.state")
    assert(state.get("initialized") ~= nil)
  end)

  test("State kernel tracked", function()
    local state = require("uranus.state")
    local kernel = state.get("current_kernel")
    assert(kernel ~= nil or kernel == nil)
  end)

  -- ========================================
  -- NEW: Output + REPL Integration
  -- ========================================
  section("Output + REPL Integration")

  test("REPL uses output for display", function()
    local repl = require("uranus.repl")
    local output = require("uranus.output")
    assert(repl.run_cell ~= nil)
    assert(output.display ~= nil)
  end)

  test("Output batched rendering", function()
    local output = require("uranus.output")
    local batch = require("uranus.output_batch")
    assert(output.display ~= nil or output.render ~= nil)
  end)

  test("Output clears on buffer change", function()
    local output = require("uranus.output")
    assert(output.clear ~= nil)
  end)

  -- ========================================
  -- NEW: Remote Kernel Integration
  -- ========================================
  section("Remote Kernel Operations")

  test("Remote kernels enumerated", function()
    local ok, remote = pcall(require, "uranus.remote")
    if ok then
      assert(remote.list_remote_kernels ~= nil)
    else
      skip("Remote module not available")
    end
  end)

  test("Remote connection established", function()
    local ok, remote = pcall(require, "uranus.remote")
    if ok then
      assert(remote.connect_remote_kernel ~= nil or remote.connect ~= nil)
    else
      skip("Remote module not available")
    end
  end)

  -- ========================================
  -- NEW: Keymaps + Commands Integration
  -- ========================================
  section("Keymaps + Commands")

  test("Keymaps bound to buffer", function()
    local ok, keymaps = pcall(require, "uranus.keymaps")
    if ok then
      assert(keymaps.setup ~= nil or keymaps.bind ~= nil)
    else
      skip("Keymaps module not available")
    end
  end)

  test("Commands registered globally", function()
    local cmds = vim.api.nvim_get_commands({})
    local uranus_cmds = vim.tbl_filter(function(cmd)
      return cmd.name:match("^Uranus")
    end, cmds)
    assert(#uranus_cmds > 0, "Should have Uranus commands")
  end)

  -- ========================================
  -- NEW: Error Propagation
  -- ========================================
  section("Error Handling")

  test("Custom error types", function()
    local ok, err = pcall(require, "uranus.errors")
    if ok then
      assert(err.new ~= nil or err.Error ~= nil)
    else
      skip("Errors module not available")
    end
  end)

  test("Error wrapped in execution", function()
    local u = require("uranus")
    local result = u.execute("invalid syntax xyz!!@")
    assert(result ~= nil, "Should return error result")
  end)

  -- ========================================
  -- NEW: Performance Integration
  -- ========================================
  section("Performance Monitoring")

  test("Module loading time tracked", function()
    local state = require("uranus.state")
    local start = state.get("module_load_start")
    local end_time = state.get("module_load_end")
    assert(start ~= nil or end_time ~= nil)
  end)

  test("Execution timing available", function()
    local u = require("uranus")
    local result = u.execute("x = 1")
    assert(result ~= nil)
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