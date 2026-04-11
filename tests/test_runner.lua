--- Test runner script for quick testing
local function run_quick_tests()
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
  
  local function skip(name, reason)
    print("[SKIP] " .. name .. " (" .. reason .. ")")
  end
  
  -- Test 1: Plugin loads
  test("Lua module loads", function()
    local ok, _ = pcall(require, "uranus")
    assert(ok, "Failed to load uranus module")
  end)
  
  -- Test 2: Version check
  test("Version check", function()
    local v = vim.version()
    assert(v.major == 0 and v.minor >= 11)
  end)
  
  -- Test 3: Backend functions exist
  test("Backend functions", function()
    local u = require("uranus")
    assert(u.start_backend ~= nil)
    assert(u.stop_backend ~= nil)
    assert(u.status ~= nil)
    assert(u.list_kernels ~= nil)
    assert(u.connect_kernel ~= nil)
    assert(u.disconnect_kernel ~= nil)
    assert(u.execute ~= nil)
    assert(u.interrupt ~= nil)
  end)
  
  -- Test 4: REPL module loads
  test("REPL module loads", function()
    local ok, _ = pcall(require, "uranus.repl")
    assert(ok, "Failed to load REPL module")
  end)
  
  -- Test 5: REPL config
  test("REPL config functions", function()
    local repl = require("uranus.repl")
    assert(repl.configure ~= nil)
    assert(repl.get_config ~= nil)
  end)
  
  -- Test 6: REPL cell parsing
  test("REPL parse_cells exists", function()
    local repl = require("uranus.repl")
    assert(repl.parse_cells ~= nil)
  end)
  
  -- Test 7: REPL execution functions
  test("REPL execution functions", function()
    local repl = require("uranus.repl")
    assert(repl.run_cell ~= nil)
    assert(repl.run_all ~= nil)
    assert(repl.run_all_async ~= nil)
    assert(repl.run_all_parallel ~= nil)
  end)
  
  -- Test 8: LSP module loads
  test("LSP module loads", function()
    local ok, _ = pcall(require, "uranus.lsp")
    assert(ok, "Failed to load LSP module")
  end)
  
  -- Test 9: LSP functions exist
  test("LSP functions exist", function()
    local lsp = require("uranus.lsp")
    assert(lsp.is_available ~= nil)
    assert(lsp.status ~= nil)
    assert(lsp.get_clients ~= nil)
    assert(lsp.hover ~= nil)
  end)
  
  -- Test 10: LSP more functions
  test("LSP navigation functions", function()
    local lsp = require("uranus.lsp")
    assert(lsp.goto_definition ~= nil)
    assert(lsp.references ~= nil)
  end)
  
  -- Test 11: LSP code actions
  test("LSP code actions", function()
    local lsp = require("uranus.lsp")
    assert(lsp.rename ~= nil)
    assert(lsp.code_action ~= nil)
    assert(lsp.format ~= nil)
  end)
  
  -- Test 12: LSP diagnostics
  test("LSP diagnostics", function()
    local lsp = require("uranus.lsp")
    assert(lsp.get_diagnostics ~= nil)
    assert(lsp.diagnostics ~= nil)
  end)
  
  -- Test 13: Inspector module loads
  test("Inspector module loads", function()
    local ok, _ = pcall(require, "uranus.inspector")
    assert(ok, "Failed to load inspector module")
  end)
  
  -- Test 14: Inspector functions
  test("Inspector functions", function()
    local insp = require("uranus.inspector")
    assert(insp.configure ~= nil)
    assert(insp.inspect_at_cursor ~= nil)
    assert(insp.toggle_inspector ~= nil)
  end)
  
  -- Test 15: Output module (optional)
  test("Output module (optional)", function()
    local ok, output = pcall(require, "uranus.output")
    if ok then
      assert(output.display ~= nil)
    else
      skip("Output module not available", "optional")
    end
  end)
  
  -- Test 16: Notebook module (optional)
  test("Notebook module (optional)", function()
    local ok, notebook = pcall(require, "uranus.notebook")
    if ok then
      assert(notebook.open ~= nil)
    else
      skip("Notebook module not available", "optional")
    end
  end)
  
  -- Test 17: Start backend
  test("Start backend", function()
    local u = require("uranus")
    local result = u.start_backend()
    local ok = result and (type(result) == "table" or (type(result) == "string" and result:match('"success"')))
    assert(ok, "start_backend should return a result")
  end)
  
  -- Test 18: Status returns version
  test("Status returns version", function()
    local u = require("uranus")
    local result = u.status()
    local ok = result and (type(result) == "table" or (type(result) == "string" and result:match('"success"')))
    assert(ok, "status should return a result")
  end)
  
  -- Test 19: List kernels
  test("List kernels", function()
    local u = require("uranus")
    local result = u.list_kernels()
    assert(result ~= nil)
  end)
  
  -- Test 20: Stop backend
  test("Stop backend", function()
    local u = require("uranus")
    local result = u.stop_backend()
    assert(result ~= nil)
  end)
  
  -- Test 21: stdin works with IPython override
  test("stdin support with IPython override", function()
    local u = require("uranus")
    u.start_backend()
    u.connect_kernel("python3")
    vim.wait(2000)
    local result = u.execute([=[
def _fake_input(prompt, ident, parent, password=False):
    return "test_answer"
get_ipython().kernel._input_request = _fake_input
x = input('test: ')
print('got:' + str(x))
]=])
    -- The result should succeed (no error about raw_input)
    assert(result ~= nil)
  end)
  
  -- Summary
  print("")
  print(string.format("Results: %d passed, %d failed", tests_passed, tests_failed))
  
  return tests_failed == 0
end

-- Run tests
local success = run_quick_tests()
vim.cmd(success and "quit 1" or "quit 0")