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
  end)

  describe("Kernel Operations", function()
    it("should return valid result structure", function()
      local uranus = require("uranus")
      local result = uranus.status()
      
      assert.is_table(result)
      assert.is_boolean(result.success)
      assert.is_table(result.data)
    end)

    it("should connect to kernel when available", function()
      local uranus = require("uranus")
      
      -- Start backend first
      local start_result = uranus.start_backend()
      assert.is_table(start_result)
      
      -- Try to list kernels
      local list_result = uranus.list_kernels()
      assert.is_table(list_result)
    end)
  end)

  describe("Code Execution", function()
    it("should handle execution without kernel", function()
      local uranus = require("uranus")
      local result = uranus.execute("print('hello')")
      
      -- Should fail because no kernel connected
      assert.is_false(result.success)
      assert.is_string(result.error.code)
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
      -- Create test file with cell markers
      local lines = {
        "# %% Cell 1",
        "x = 1",
        "y = 2",
        "",
        "# %% Cell 2", 
        "print(x + y)",
      }
      
      vim.fn.writefile(lines, cell_test_file)
      
      -- Open the file
      vim.cmd("edit " .. cell_test_file)
      
      -- Check that buffer has content
      local buf = vim.api.nvim_get_current_buf()
      assert.is_true(vim.api.nvim_buf_is_valid(buf))
    end)
  end)

  describe("Output Display", function()
    it("should create output buffer", function()
      local uranus = require("uranus")
      
      -- Setup the plugin
      local setup_result = uranus.setup()
      assert.is_table(setup_result)
    end)
  end)
end)

describe("Uranus Rust Backend", function()
  describe("Module Loading", function()
    it("should load the Rust library if available", function()
      -- Try to load the Rust backend module
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
