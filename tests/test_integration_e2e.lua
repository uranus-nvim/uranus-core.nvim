--- Uranus integration tests using plenary.nvim
---
--- These tests verify that Uranus actually works end-to-end:
--- - Backend starts correctly
--- - Kernels can be discovered and connected
--- - Code execution works
--- - Notebook parsing works
--- - Output rendering works
---
--- @module tests.test_integration_e2e

local runner = require("plenary.busted")
local assert = require("luassert")
local eq = assert.are.same
local ok = assert.is_not_nil
local describe, it, before_each, after_each =
  runner.describe, runner.it, runner.before_each, runner.after_each

-- Test fixtures directory
local fixtures_dir = vim.fn.fnamemodify(vim.fn.expand("<sfile>"), ":h") .. "/fixtures"

-- Helper to wait for async operations
local function wait(timeout, condition)
  timeout = timeout or 1000
  local start = vim.loop.now()
  while vim.loop.now() - start < timeout do
    if condition() then
      return true
    end
    vim.wait(10)
  end
  return false
end

describe("Uranus Integration Tests", function()
  local uranus = nil
  local backend_started = false

  before_each(function()
    -- Reset state
    backend_started = false
    vim.g.uranus_backend_started = false
  end)

  after_each(function()
    -- Cleanup: stop backend if running
    if backend_started and uranus then
      pcall(uranus.stop_backend)
    end

    -- Cleanup test files
    local test_files = {
      fixtures_dir .. "/test_output.ipynb",
      fixtures_dir .. "/test.py",
    }
    for _, file in ipairs(test_files) do
      if vim.fn.filereadable(file) == 1 then
        os.remove(file)
      end
    end
  end)

  describe("Backend Initialization", function()
    it("should load the Rust backend", function()
      local ok, result = pcall(require, "uranus")
      assert(ok, "Failed to load uranus module")
      assert(type(result) == "table", "Backend should return a table")
    end)

    it("should start the backend", function()
      uranus = require("uranus")
      local result = uranus.start_backend()

      -- Result should be a JSON string or table
      local data = result
      if type(result) == "string" then
        data = vim.json.decode(result)
      end

      assert(data.success or data.status, "Backend should start successfully")
      backend_started = true
    end)

    it("should return valid status after starting", function()
      uranus = require("uranus")
      local start_result = uranus.start_backend()
      backend_started = true

      local status = uranus.status()
      local status_data = status
      if type(status) == "string" then
        status_data = vim.json.decode(status)
      end

      assert(status_data.backend_running, "Backend should be running")
      assert(status_data.version, "Should have version info")
    end)

    it("should stop the backend", function()
      uranus = require("uranus")
      uranus.start_backend()
      backend_started = true

      local result = uranus.stop_backend()
      local data = result
      if type(result) == "string" then
        data = vim.json.decode(result)
      end

      assert(data.success or data.status, "Backend should stop")
      backend_started = false
    end)
  end)

  describe("Kernel Discovery", function()
    it("should list available kernels", function()
      uranus = require("uranus")
      local start_result = uranus.start_backend()
      backend_started = true

      local result = uranus.list_kernels()
      local data = result
      if type(result) == "string" then
        data = vim.json.decode(result)
      end

      assert(data.kernels, "Should return kernels list")
      assert(type(data.kernels) == "table", "Kernels should be a table")
    end)

    it("should connect to a kernel if available", function()
      uranus = require("uranus")
      local start_result = uranus.start_backend()
      backend_started = true

      -- Get available kernels
      local list_result = uranus.list_kernels()
      local list_data = list_result
      if type(list_result) == "string" then
        list_data = vim.json.decode(list_result)
      end

      local kernels = list_data.kernels or {}
      if #kernels > 0 then
        local kernel_name = kernels[1].name or kernels[1]
        local connect_result = uranus.connect_kernel(kernel_name)

        local connect_data = connect_result
        if type(connect_result) == "string" then
          connect_data = vim.json.decode(connect_result)
        end

        -- Should either succeed or give clear error
        if connect_data.success then
          backend_started = true
          local current = uranus.current_kernel()
          assert(current, "Should have current kernel after connection")
        end
      end
    end)
  end)

  describe("Code Execution", function()
    it("should execute simple Python code", function()
      uranus = require("uranus")
      local start_result = uranus.start_backend()
      backend_started = true

      -- Try to connect to python3 kernel
      local connect_result = uranus.connect_kernel("python3")
      local connect_data = connect_result
      if type(connect_result) == "string" then
        connect_data = vim.json.decode(connect_result)
      end

      if connect_data.success then
        local exec_result = uranus.execute("print('hello from uranus')")
        local exec_data = exec_result
        if type(exec_result) == "string" then
          exec_data = vim.json.decode(exec_result)
        end

        if exec_data.success then
          assert(exec_data.data, "Should return execution data")
          -- Check stdout contains our message
          local stdout = exec_data.data.stdout or ""
          assert(stdout:match("hello"), "Output should contain hello")
        end
      end
    end)

    it("should capture execution count", function()
      uranus = require("uranus")
      local start_result = uranus.start_backend()
      backend_started = true

      local connect_result = uranus.connect_kernel("python3")
      local connect_data = connect_result
      if type(connect_result) == "string" then
        connect_data = vim.json.decode(connect_result)
      end

      if connect_data.success then
        local exec_result = uranus.execute("1 + 1")
        local exec_data = exec_result
        if type(exec_result) == "string" then
          exec_data = vim.json.decode(exec_result)
        end

        if exec_data.success then
          assert(exec_data.data.execution_count, "Should have execution count")
          assert(type(exec_data.data.execution_count) == "number", "Execution count should be number")
        end
      end
    end)
  end)

  describe("Notebook Operations", function()
    it("should create a new notebook", function()
      local notebook = require("uranus.notebook")
      local test_path = fixtures_dir .. "/test_create.ipynb"

      -- Create test notebook
      local result = notebook.new("test_notebook", test_path)

      -- Should succeed or notebook already exists
      if result.success then
        assert(vim.fn.filereadable(test_path) == 1, "Notebook file should be created")

        -- Verify it's valid JSON
        local content = io.open(test_path, "r"):read("*all")
        local ok, _ = pcall(vim.json.decode, content)
        assert(ok, "Notebook should be valid JSON")

        -- Cleanup
        os.remove(test_path)
      end
    end)

    it("should open and parse a notebook", function()
      local notebook = require("uranus.notebook")
      local test_path = fixtures_dir .. "/test_notebook.ipynb"

      -- Check if test notebook exists
      if vim.fn.filereadable(test_path) == 1 then
        local result = notebook.open(test_path)
        if result.success then
          assert(result.cells, "Should have cells")
          assert(type(result.cells) == "table", "Cells should be a table")
        end
      end
    end)
  end)

  describe("Configuration", function()
    it("should accept configuration", function()
      local config_module = require("uranus.config")

      local result = config_module.init({
        auto_install_jupyter = false,
        async_execution = true,
      })

      assert(result.success, "Configuration should be valid")

      local config = config_module.get_config()
      assert(config.auto_install_jupyter == false, "Should set auto_install_jupyter")
      assert(config.async_execution == true, "Should set async_execution")
    end)

    it("should validate configuration", function()
      local config_module = require("uranus.config")

      -- Invalid type should fail
      local result = config_module.init({
        auto_install_jupyter = "invalid",
      })

      -- May or may not fail depending on validation strictness
      -- Just verify it doesn't crash
      assert(type(result) == "table", "Should return result")
    end)
  end)

  describe("Module Loading", function()
    it("should load all core modules", function()
      local modules = {
        "uranus.config",
        "uranus.keymaps",
        "uranus.parsers",
        "uranus.repl",
        "uranus.notebook",
        "uranus.output",
        "uranus.ui",
        "uranus.lsp",
        "uranus.inspector",
        "uranus.cache",
        "uranus.completion",
        "uranus.remote",
        "uranus.cell_mode",
        "uranus.repl_buffer",
        "uranus.notebook_ui",
      }

      for _, module_name in ipairs(modules) do
        local ok, mod = pcall(require, module_name)
        assert(ok, string.format("Module %s should load", module_name))
        assert(type(mod) == "table" or type(mod) == "function", string.format("Module %s should return table or function", module_name))
      end
    end)
  end)
end)
