--- Uranus core functionality tests
---
--- Comprehensive test suite for Uranus core modules using plenary.nvim
---
--- @module tests.uranus_spec

local uranus = require("uranus")

describe("Uranus Core", function()
  before_each(function()
    -- Clean up test environment
    _G.cleanup_test()

    -- Reset Uranus state
    uranus.state = {
      backend_running = false,
      current_kernel = nil,
      buffers = {},
    }
  end)

  describe("Configuration", function()
    it("should validate valid configuration", function()
      local config = {
        debug = true,
        log_level = "DEBUG",
        lsp = {
          enable = true,
          server = "pyright",
        },
        ui = {
          mode = "repl",
          repl = {
            view = "floating",
          },
        },
        kernels = {
          auto_start = false,
          default = "python3",
        },
      }

      local result = require("uranus.config").validate(config)
      assert.is_true(result.success)
      assert.is_table(result.data)
    end)

    it("should reject invalid configuration", function()
      local config = {
        ui = {
          mode = "invalid_mode",
        },
      }

      local result = require("uranus.config").validate(config)
      assert.is_false(result.success)
      assert.equals("INVALID_MODE", result.error.code)
    end)
  end)

  describe("Plugin Initialization", function()
    it("should initialize with default config", function()
      local result = uranus.setup()
      assert.is_true(result.success)
    end)

    it("should initialize with custom config", function()
      local config = {
        debug = true,
        ui = {
          mode = "notebook",
        },
      }

      local result = uranus.setup(config)
      assert.is_true(result.success)
      assert.equals("notebook", uranus.config.ui.mode)
    end)

    it("should reject invalid custom config", function()
      local config = {
        kernels = {
          timeout = "invalid", -- should be number
        },
      }

      local result = uranus.setup(config)
      assert.is_false(result.success)
    end)
  end)

  describe("Kernel Management", function()
    local kernel = require("uranus.kernel")

    before_each(function()
      kernel.discovered_kernels = {}
      kernel.current_kernel = nil
    end)

    it("should parse connection files", function()
      -- Mock connection file data
      local mock_data = {
        kernel_name = "python3",
        key = "abc123",
        signature_scheme = "hmac-sha256",
        transport = "tcp",
        ip = "127.0.0.1",
        hb_port = 9000,
        shell_port = 9001,
        stdin_port = 9002,
        control_port = 9003,
        iopub_port = 9004,
      }

      local result = kernel._parse_connection_file(vim.json.encode(mock_data))
      assert.is_true(result.success)
      assert.equals("python3", result.data.name)
      assert.equals("python", result.data.language)
    end)

    it("should detect programming languages", function()
      assert.equals("python", kernel._detect_language({ kernel_name = "python3" }))
      assert.equals("r", kernel._detect_language({ kernel_name = "ir" }))
      assert.equals("julia", kernel._detect_language({ kernel_name = "julia-1.8" }))
      assert.equals("javascript", kernel._detect_language({ kernel_name = "node" }))
      assert.equals("bash", kernel._detect_language({ kernel_name = "bash" }))
      assert.equals("unknown", kernel._detect_language({ kernel_name = "custom-kernel" }))
    end)
  end)

  describe("REPL Functionality", function()
    local repl = require("uranus.repl")

    before_each(function()
      repl.buffer_cells = {}
      repl.current_cell = {}
    end)

    it("should parse cells from buffer", function()
      -- Create test buffer with cells
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "print('cell 1')",
        "# %%",
        "print('cell 2')",
        "# %%",
        "print('cell 3')",
      })

      local result = repl.parse_cells(buf)
      assert.is_true(result.success)

      local cells = result.data
      assert.equals(3, #cells)
      assert.equals("print('cell 1')", cells[1].code)
      assert.equals("print('cell 2')", cells[2].code)
      assert.equals("print('cell 3')", cells[3].code)

      -- Clean up
      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("should find current cell at cursor", function()
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "print('before')",
        "# %%",
        "print('cell')",
        "# %%",
        "print('after')",
      })

      -- Set cursor in middle cell
      vim.api.nvim_win_set_cursor(0, { 3, 0 }) -- Line 3 (0-based: 2)

      local result = repl.get_current_cell(buf)
      assert.is_true(result.success)
      assert.equals("print('cell')", result.data.code)

      -- Clean up
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("UI Components", function()
    local ui = require("uranus.ui")

    before_each(function()
      ui.windows = {}
      ui.virtual_text = {}
    end)

    it("should create floating window", function()
      local result = ui.display("test content", {
        mode = "floating",
        width = 40,
        height = 10,
      })

      assert.is_true(result.success)
      assert.is_table(result.data)
      assert.equals("floating", result.data.type)

      -- Clean up
      ui.close(result.data)
    end)

    it("should create progress indicator", function()
      local progress = ui.create_progress("Testing...", {
        width = 30,
      })

      assert.is_table(progress)
      assert.equals("Testing...", progress.message)
      assert.is_table(progress.spinner)

      -- Clean up
      ui.close_progress(progress)
    end)
  end)

  describe("Output Rendering", function()
    local output = require("uranus.output")

    it("should format text output", function()
      local result = {
        stdout = "Hello World",
        stderr = "Warning message",
        display_data = {},
      }

      local formatted = output.format_result(result)
      assert.is_string(formatted)
      assert.matches("Hello World", formatted)
      assert.matches("Warning message", formatted)
    end)

    it("should handle rich display data", function()
      local display_data = {
        mime_type = "text/plain",
        data = "Simple text output",
      }

      local result = output.display_rich_output(display_data)
      assert.is_true(result.success)
    end)

    it("should format different MIME types", function()
      -- Test JSON formatting
      local json_data = {
        mime_type = "application/json",
        data = '{"key": "value"}',
      }

      local formatter = output.formatters["application/json"]
      local formatted = formatter(json_data)
      assert.is_string(formatted)
      assert.matches("JSON", formatted)
    end)
  end)

  describe("Backend Communication", function()
    local backend = require("uranus.backend")

    before_each(function()
      backend.state = {
        process = nil,
        connected = false,
        callbacks = {},
        pending_requests = {},
        request_id = 1,
      }
    end)

    it("should handle JSON messages", function()
      local test_message = vim.json.encode({
        event = "test_event",
        data = { key = "value" },
      })

      -- Mock message handling
      local handled = false
      backend.on("test_event", function(data)
        handled = true
        assert.equals("value", data.key)
      end)

      backend._handle_message(test_message)
      assert.is_true(handled)
    end)

    it("should manage pending requests", function()
      local request_id = "test_req_123"

      backend.state.pending_requests[request_id] = {
        id = request_id,
        command = "test_command",
        callback = function() end,
      }

      -- Simulate response
      local response = vim.json.encode({
        id = request_id,
        success = true,
        data = { result = "success" },
      })

      backend._handle_message(response)

      -- Request should be cleaned up
      assert.is_nil(backend.state.pending_requests[request_id])
    end)
  end)

  describe("Error Handling", function()
    it("should handle kernel connection errors", function()
      local kernel = require("uranus.kernel")

      -- Mock failed connection
      local result = kernel.connect("nonexistent_kernel")
      assert.is_false(result.success)
      assert.equals("KERNEL_NOT_FOUND", result.error.code)
    end)

    it("should handle invalid configuration", function()
      local config = {
        ui = {
          mode = "invalid_mode",
        },
      }

      local result = require("uranus.config").validate(config)
      assert.is_false(result.success)
      assert.is_table(result.error)
    end)
  end)

  describe("Integration Tests", function()
    it("should handle full setup workflow", function()
      -- Setup with minimal config
      local config = {
        debug = false,
        ui = {
          mode = "repl",
          repl = {
            view = "floating",
          },
        },
      }

      local result = uranus.setup(config)
      assert.is_true(result.success)

      -- Verify configuration was applied
      assert.equals("repl", uranus.config.ui.mode)
      assert.equals("floating", uranus.config.ui.repl.view)
    end)

    it("should handle buffer operations", function()
      -- Create test buffer
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "# %% Cell 1",
        "print('hello')",
        "# %% Cell 2",
        "print('world')",
      })

      -- Parse cells
      local repl = require("uranus.repl")
      local result = repl.parse_cells(buf)
      assert.is_true(result.success)
      assert.equals(2, #result.data)

      -- Clean up
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)
end)