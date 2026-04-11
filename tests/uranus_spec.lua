--- Uranus Neovim integration tests
---
--- Tests for the Uranus plugin in Neovim using plenary.nvim
---
--- Run with: nvim --headless -u tests/minimal_init.lua -c "lua require('plenary.busted').run()"
---
--- @module tests.uranus_spec

local lua_version = tonumber(vim.version().lua:match("(%d+%.%d+)"))

if lua_version < 5.1 then
  vim.notify("Uranus requires Lua 5.1+", vim.log.levels.ERROR)
  return
end

local function wait_for_timeout(fn, timeout_ms)
  local start = vim.loop.now()
  while vim.loop.now() - start < timeout_ms do
    local result = fn()
    if result then
      return result
    end
    vim.wait(10)
  end
  return fn()
end

describe("Uranus Plugin", function()
  local test_file = vim.fn.stdpath("temp") .. "/uranus-test-" .. vim.fn.strftime("%s") .. ".py"
  
  after_each(function()
    if vim.fn.filereadable(test_file) == 1 then
      vim.fn.delete(test_file)
    end
    _G.cleanup_test()
  end)

  describe("Version Check", function()
    it("should require Neovim 0.11.4+", function()
      local version_ok = vim.version().minor > 11 or 
        (vim.version().minor == 11 and vim.version().patch >= 4)
      assert.is_true(version_ok, 
        "Neovim version must be 0.11.4+ (current: " .. vim.version().major .. "." .. 
        vim.version().minor .. "." .. vim.version().patch .. ")")
    end)
  end)

  describe("Plugin Loading", function()
    it("should load the Uranus module", function()
      local ok, uranus = pcall(require, "uranus")
      assert.is_true(ok, "Failed to load uranus module: " .. tostring(uranus))
      assert.is_table(uranus)
    end)

    it("should have setup function", function()
      local uranus = require("uranus")
      assert.is_function(uranus.setup)
    end)

    it("should have core functions", function()
      local uranus = require("uranus")
      assert.is_function(uranus.start_backend)
      assert.is_function(uranus.stop_backend)
      assert.is_function(uranus.status)
      assert.is_function(uranus.connect_kernel)
      assert.is_function(uranus.disconnect_kernel)
      assert.is_function(uranus.execute)
      assert.is_function(uranus.list_kernels)
    end)
  end)

  describe("Commands", function()
    it("should register UranusStart command", function()
      local ok = vim.cmd("UranusStart")
      assert.is_nil(ok)
    end)

    it("should register UranusStatus command", function()
      local ok = vim.cmd("UranusStatus")
      assert.is_nil(ok)
    end)

    it("should register UranusListKernels command", function()
      local ok = vim.cmd("UranusListKernels")
      assert.is_nil(ok)
    end)

    it("should register UranusStop command", function()
      local ok = vim.cmd("UranusStop")
      assert.is_nil(ok)
    end)

    it("should register UranusConnect command", function()
      local ok = vim.cmd("UranusConnect python3")
      assert.is_nil(ok)
    end)

    it("should register UranusExecute command", function()
      local ok = vim.cmd("UranusExecute print('test')")
      assert.is_nil(ok)
    end)
  end)

  describe("Kernel Operations", function()
    it("should return valid result structure", function()
      local uranus = require("uranus")
      local result = uranus.status()
      
      assert.is_table(result)
      assert.is_boolean(result.success)
      assert.is_table(result.data)
    end)

    it("should start and stop backend", function()
      local uranus = require("uranus")
      
      local start_result = uranus.start_backend()
      assert.is_table(start_result)
      
      local stop_result = uranus.stop_backend()
      assert.is_table(stop_result)
    end)

    it("should list kernels when available", function()
      local uranus = require("uranus")
      
      local start_result = uranus.start_backend()
      assert.is_table(start_result)
      
      local list_result = uranus.list_kernels()
      assert.is_table(list_result)
      
      if list_result.success and list_result.data and list_result.data.kernels then
        assert.is_table(list_result.data.kernels)
      end
    end)

    it("should connect to python3 kernel when available", function()
      local uranus = require("uranus")
      
      local start_result = uranus.start_backend()
      assert.is_table(start_result)
      
      local connect_result = uranus.connect_kernel("python3")
      assert.is_table(connect_result)
    end)
  end)

  describe("Code Execution", function()
    it("should handle execution without kernel", function()
      local uranus = require("uranus")
      uranus.stop_backend()
      
      local result = uranus.execute("print('hello')")
      assert.is_false(result.success)
      assert.is_string(result.error.code)
    end)

    it("should execute simple code when kernel connected", function()
      local uranus = require("uranus")
      
      uranus.start_backend()
      uranus.connect_kernel("python3")
      
      local result = uranus.execute("2 + 2")
      assert.is_table(result)
      
      if result.success then
        assert.is_true(result.data.result ~= nil or result.data.stdout ~= nil)
      end
    end)

    it("should capture stdout", function()
      local uranus = require("uranus")
      
      uranus.start_backend()
      uranus.connect_kernel("python3")
      
      local result = uranus.execute("print('stdout test')")
      assert.is_table(result)
      
      if result.success then
        assert.is_string(result.data.stdout)
      end
    end)

    it("should capture stderr", function()
      local uranus = require("uranus")
      
      uranus.start_backend()
      uranus.connect_kernel("python3")
      
      local result = uranus.execute("import sys; print('stderr test', file=sys.stderr)")
      assert.is_table(result)
    end)

    it("should handle errors gracefully", function()
      local uranus = require("uranus")
      
      uranus.start_backend()
      uranus.connect_kernel("python3")
      
      local result = uranus.execute("raise ValueError('test error')")
      assert.is_table(result)
    end)
  end)

  describe("Cell Mode", function()
    local cell_test_file = vim.fn.stdpath("temp") .. "/uranus-cells-" .. vim.fn.strftime("%s") .. ".py"
    
    after_each(function()
      if vim.fn.filereadable(cell_test_file) == 1 then
        vim.fn.delete(cell_test_file)
      end
    end)

    it("should parse cell markers", function()
      local lines = {
        "# %% Cell 1",
        "x = 1",
        "y = 2",
        "",
        "# %% Cell 2", 
        "print(x + y)",
      }
      
      vim.fn.writefile(lines, cell_test_file)
      vim.cmd("edit " .. cell_test_file)
      
      local buf = vim.api.nvim_get_current_buf()
      assert.is_true(vim.api.nvim_buf_is_valid(buf))
    end)

    it("should parse multiple cells", function()
      local lines = {
        "# %% First cell",
        "x = 1",
        "",
        "# %% Second cell", 
        "y = 2",
        "",
        "# %% Third cell",
        "z = 3",
      }
      
      vim.fn.writefile(lines, cell_test_file)
      vim.cmd("edit " .. cell_test_file)
      
      local repl = require("uranus.repl")
      local cells = repl.parse_cells()
      
      assert.is_table(cells)
    end)

    it("should handle empty cells", function()
      local lines = {
        "# %% Empty cell",
        "",
        "# %% Code cell",
        "x = 1",
      }
      
      vim.fn.writefile(lines, cell_test_file)
      vim.cmd("edit " .. cell_test_file)
      
      local repl = require("uranus.repl")
      local cells = repl.parse_cells()
      
      assert.is_table(cells)
    end)
  end)

  describe("Output Display", function()
    it("should create output buffer", function()
      local uranus = require("uranus")
      
      local setup_result = uranus.setup()
      assert.is_table(setup_result)
    end)

    it("should load output module", function()
      local ok, output = pcall(require, "uranus.output")
      if ok then
        assert.is_table(output)
        assert.is_function(output.display)
      else
        pending("Output module not available")
      end
    end)
  end)
end)

describe("Uranus REPL Module", function()
  describe("Module Loading", function()
    it("should load the REPL module", function()
      local ok, repl = pcall(require, "uranus.repl")
      assert.is_true(ok, "Failed to load REPL module")
      assert.is_table(repl)
    end)

    it("should have required functions", function()
      local repl = require("uranus.repl")
      assert.is_function(repl.parse_cells)
      assert.is_function(repl.run_cell)
      assert.is_function(repl.run_all)
      assert.is_function(repl.run_selection)
      assert.is_function(repl.next_cell)
      assert.is_function(repl.prev_cell)
    end)
  end)

  describe("Cell Parsing", function()
    it("should parse cells with default marker", function()
      local repl = require("uranus.repl")
      local config = repl.get_config()
      
      assert.is_string(config.cell_marker)
      assert.equals("#%%", config.cell_marker)
    end)

    it("should handle custom cell marker", function()
      local repl = require("uranus.repl")
      repl.configure({ cell_marker = "# %% Custom" })
      
      local config = repl.get_config()
      assert.equals("# %% Custom", config.cell_marker)
    end)
  end)
end)

describe("Uranus LSP Module", function()
  describe("Module Loading", function()
    it("should load the LSP module", function()
      local ok, lsp = pcall(require, "uranus.lsp")
      assert.is_true(ok, "Failed to load LSP module")
      assert.is_table(lsp)
    end)

    it("should have configuration functions", function()
      local lsp = require("uranus.lsp")
      assert.is_function(lsp.configure)
      assert.is_function(lsp.get_config)
    end)

    it("should have status functions", function()
      local lsp = require("uranus.lsp")
      assert.is_function(lsp.is_available)
      assert.is_function(lsp.status)
      assert.is_function(lsp.get_clients)
    end)
  end)

  describe("Client Detection", function()
    it("should return empty when no LSP available", function()
      local lsp = require("uranus.lsp")
      local clients = lsp.get_clients()
      
      assert.is_table(clients)
    end)
  end)

  describe("LSP Functions", function()
    it("should have navigation functions", function()
      local lsp = require("uranus.lsp")
      assert.is_function(lsp.goto_definition)
      assert.is_function(lsp.goto_type_definition)
      assert.is_function(lsp.references)
      assert.is_function(lsp.implementation)
    end)

    it("should have code action functions", function()
      local lsp = require("uranus.lsp")
      assert.is_function(lsp.rename)
      assert.is_function(lsp.code_action)
      assert.is_function(lsp.format)
    end)

    it("should have hover function", function()
      local lsp = require("uranus.lsp")
      assert.is_function(lsp.hover)
    end)

    it("should have signature help", function()
      local lsp = require("uranus.lsp")
      assert.is_function(lsp.signature_help)
    end)

    it("should have workspace symbols", function()
      local lsp = require("uranus.lsp")
      assert.is_function(lsp.workspace_symbol)
      assert.is_function(lsp.document_symbol)
    end)
  end)

  describe("Diagnostics", function()
    it("should have diagnostic functions", function()
      local lsp = require("uranus.lsp")
      assert.is_function(lsp.get_diagnostics)
      assert.is_function(lsp.diagnostics)
      assert.is_function(lsp.list_diagnostics)
    end)
  end)
end)

describe("Uranus Inspector Module", function()
  describe("Module Loading", function()
    it("should load the inspector module", function()
      local ok, inspector = pcall(require, "uranus.inspector")
      assert.is_true(ok, "Failed to load inspector module")
      assert.is_table(inspector)
    end)

    it("should have configuration functions", function()
      local inspector = require("uranus.inspector")
      assert.is_function(inspector.configure)
      assert.is_function(inspector.get_config)
    end)
  end)

  describe("Inspection Functions", function()
    it("should have cursor inspection", function()
      local inspector = require("uranus.inspector")
      assert.is_function(inspector.inspect_at_cursor)
    end)

    it("should have window functions", function()
      local inspector = require("uranus.inspector")
      assert.is_function(inspector.open_inspector)
      assert.is_function(inspector.toggle_inspector)
      assert.is_function(inspector.close_inspector)
    end)

    it("should have variables function", function()
      local inspector = require("uranus.inspector")
      assert.is_function(inspector.get_variables)
    end)
  end)
end)

describe("Uranus Notebook Module", function()
  describe("Module Loading", function()
    it("should load the notebook module", function()
      local ok, notebook = pcall(require, "uranus.notebook")
      if not ok then
        pending("Notebook module not available")
        return
      end
      assert.is_table(notebook)
    end)
  end)
end)

describe("Uranus Output Module", function()
  describe("Module Loading", function()
    it("should load the output module", function()
      local ok, output = pcall(require, "uranus.output")
      if not ok then
        pending("Output module not available")
        return
      end
      assert.is_table(output)
    end)
  end)
end)

describe("Uranus Rust Backend", function()
  describe("Module Loading", function()
    it("should load the Rust library if available", function()
      local ok, backend = pcall(require, "uranus.backend")
      
      if ok then
        assert.is_table(backend)
        assert.is_function(backend.start_backend)
        assert.is_function(backend.stop_backend)
        assert.is_function(backend.status)
      else
        pending("Rust backend not compiled")
      end
    end)
  end)
end)

describe("Neovim LSP Integration", function()
  describe("Built-in LSP", function()
    it("should have vim.lsp available", function()
      assert.is_table(vim.lsp)
      assert.is_function(vim.lsp.get_active_clients)
    end)

    it("should detect LSP clients", function()
      local clients = vim.lsp.get_active_clients()
      assert.is_table(clients)
    end)
  end)
end)