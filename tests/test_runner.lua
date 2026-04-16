--- Test runner script - basic module and backend tests
--- Uses shared test framework

package.path = package.path .. ";./tests/?.lua"
local T = require("testlib")
T.reset()

local function run_basic_tests()
  T.section("Basic Module Tests")

  T.section("Module Loading")
  T.test("Lua module loads", function()
    local ok, _ = pcall(require, "uranus")
    T.assert(ok, "Failed to load uranus module")
  end)

  T.test("Version check", function()
    local v = vim.version()
    T.assert(v.major == 0 and v.minor >= 11, "Neovim 0.11+ required")
  end)

  T.section("Backend Functions")
  T.test("Backend functions exist", function()
    local u = require("uranus")
    T.assert_not_nil(u.start_backend)
    T.assert_not_nil(u.stop_backend)
    T.assert_not_nil(u.status)
  end)

  T.test("Kernel manager loads", function()
    local ok, km = pcall(require, "uranus.kernel_manager")
    T.assert(ok)
  end)

  T.test("Kernel manager functions", function()
    local km = require("uranus.kernel_manager")
    T.assert_type(km.list_kernels, "function")
  end)

  T.section("REPL Module")
  T.test("REPL module loads", function()
    local ok, _ = pcall(require, "uranus.repl")
    T.assert(ok, "Failed to load REPL module")
  end)

  T.test("REPL config functions", function()
    local repl = require("uranus.repl")
    T.assert_type(repl.configure, "function")
    T.assert_type(repl.get_config, "function")
  end)

  T.test("REPL parse_cells exists", function()
    local repl = require("uranus.repl")
    T.assert_type(repl.parse_cells, "function")
  end)

  T.test("REPL execution functions", function()
    local repl = require("uranus.repl")
    T.assert_type(repl.run_cell, "function")
    T.assert_type(repl.run_all, "function")
    T.assert_type(repl.run_all_async, "function")
    T.assert_type(repl.run_all_parallel, "function")
  end)

  T.section("LSP Module")
  T.test("LSP module loads", function()
    local ok, _ = pcall(require, "uranus.lsp")
    T.assert(ok, "Failed to load LSP module")
  end)

  T.test("LSP core functions", function()
    local lsp = require("uranus.lsp")
    T.assert_type(lsp.is_available, "function")
    T.assert_type(lsp.status, "function")
    T.assert_type(lsp.get_clients, "function")
    T.assert_type(lsp.hover, "function")
  end)

  T.test("LSP navigation functions", function()
    local lsp = require("uranus.lsp")
    T.assert_type(lsp.goto_definition, "function")
    T.assert_type(lsp.references, "function")
  end)

  T.test("LSP code actions", function()
    local lsp = require("uranus.lsp")
    T.assert_type(lsp.rename, "function")
    T.assert_type(lsp.code_action, "function")
    T.assert_type(lsp.format, "function")
  end)

  T.test("LSP diagnostics", function()
    local lsp = require("uranus.lsp")
    T.assert_type(lsp.get_diagnostics, "function")
    T.assert_type(lsp.diagnostics, "function")
  end)

  T.section("Inspector Module")
  T.test("Inspector module loads", function()
    local ok, _ = pcall(require, "uranus.inspector")
    T.assert(ok, "Failed to load inspector module")
  end)

  T.test("Inspector functions", function()
    local insp = require("uranus.inspector")
    T.assert_type(insp.configure, "function")
    T.assert_type(insp.inspect_at_cursor, "function")
    T.assert_type(insp.toggle_inspector, "function")
  end)

  T.section("Output Module (Optional)")
  T.test("Output module loads", function()
    local ok, output = pcall(require, "uranus.output")
    if ok then
      T.assert_type(output.display, "function")
    else
      T.skip("Output module not available", "optional")
    end
  end)

  T.section("Notebook Module (Optional)")
  T.test("Notebook module loads", function()
    local ok, notebook = pcall(require, "uranus.notebook")
    if ok then
      T.assert_type(notebook.open, "function")
    else
      T.skip("Notebook module not available", "optional")
    end
  end)

  T.section("Backend Operations")
  T.test("Start backend", function()
    local u = require("uranus")
    local result = u.start_backend()
    T.assert(result ~= nil)
  end)

  T.test("Status returns version", function()
    local u = require("uranus")
    local result = u.status()
    T.assert(result ~= nil)
  end)

  T.test("List kernels via kernel manager", function()
    local km = require("uranus.kernel_manager")
    local result = km.list_kernels()
    T.assert_not_nil(result)
  end)

  T.test("Stop backend", function()
    local u = require("uranus")
    local result = u.stop_backend()
    T.assert(result ~= nil)
  end)

  T.summary()

  return T.results()
end

local success = run_basic_tests()
vim.cmd(success and "quit 1" or "quit 0")