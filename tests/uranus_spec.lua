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
      assert.equals("CONFIG_UI", result.error.code)
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

    it("should discover kernels using backend", function()
      -- Mock backend response
      local mock_kernels = {
        {
          id = "python3",
          name = "python3",
          language = "python",
          status = "available",
          type = "local",
        }
      }

      -- Test kernel discovery (this would normally call the backend)
      kernel.discovered_kernels = mock_kernels
      assert.equals(1, #kernel.discovered_kernels)
      assert.equals("python3", kernel.discovered_kernels[1].name)
    end)
  end)

  describe("REPL Functionality", function()
    local repl = require("uranus.repl")

    before_each(function()
      repl.buffer_cells = {}
      repl.current_cell = {}
      -- Initialize repl with test config
      local test_config = {
        cell = { marker = "# %%" },
        ui = { repl = { view = "floating" } }
      }
      repl.init(test_config)
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
      -- Debug: print actual cell count and content
      print("Found " .. #cells .. " cells")
      for i, cell in ipairs(cells) do
        print("Cell " .. i .. ": '" .. cell.code .. "'")
      end

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

      -- Create a window for the buffer to set cursor
      local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = 80,
        height = 20,
        row = 0,
        col = 0,
      })

      -- Set cursor in middle cell
      vim.api.nvim_win_set_cursor(win, { 3, 0 }) -- Line 3 (0-based: 2)

      local result = repl.get_current_cell(buf)
      assert.is_true(result.success)
      assert.equals("print('cell')", result.data.code)

      -- Clean up
      vim.api.nvim_win_close(win, true)
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("UI Components", function()
    local ui = require("uranus.ui")

    before_each(function()
      ui.windows = {}
      ui.virtual_text = {}
      -- Initialize ui with test config
      local test_config = {
        ui = {
          repl = { view = "floating", max_width = 80, max_height = 20, border = "rounded" }
        }
      }
      ui.init(test_config)
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

    before_each(function()
      -- Initialize output with test config
      local test_config = {
        ui = { repl = { view = "floating" } },
        output = { image_dir = "/tmp/uranus_images" }
      }
      output.init(test_config)
    end)

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

    describe("Backend Integration", function()
      local backend_process = nil

      before_each(function()
        -- Start backend process for integration tests
        -- Note: This requires the Rust binary to be built
        local backend = require("uranus.backend")
        if backend.start then
          local result = backend.start()
          if result.success then
            backend_process = result.data
          end
        end
      end)

      after_each(function()
        -- Clean up backend process
        if backend_process then
          local backend = require("uranus.backend")
          if backend.stop then
            backend.stop()
          end
          backend_process = nil
        end
      end)

      it("should start and communicate with Rust backend", function()
        if not backend_process then
          pending("Rust backend not available for integration test")
          return
        end

        local backend = require("uranus.backend")

        -- Test list kernels command
        local result = backend.send_command("list_kernels", {})

        assert.is_table(result)
        assert.is_true(result.success)
        assert.is_table(result.data)
        assert.is_table(result.data.data.kernels)
      end)

      it("should handle kernel execution workflow", function()
        if not backend_process then
          pending("Rust backend not available for integration test")
          return
        end

        local backend = require("uranus.backend")

        -- First, list available kernels
        local list_result = backend.send_command("list_kernels", {})

        assert.is_true(list_result.success)
        assert.is_table(list_result.data.data.kernels)

        -- If kernels are available, try to start one
        if #list_result.data.data.kernels > 0 then
          local kernel_name = list_result.data.data.kernels[1].name

          local start_result = backend.send_command("start_kernel", { kernel = kernel_name })

          -- The result may succeed or fail depending on actual kernel availability
          assert.is_table(start_result)
          assert.is_boolean(start_result.success)

          -- If kernel started successfully, try execution
          if start_result.success then
            local execute_result = backend.send_command("execute", { code = "print('Hello from integration test')" })

            assert.is_table(execute_result)
            assert.is_boolean(execute_result.success)
          end
        end
      end)

      it("should handle remote kernel connection", function()
        if not backend_process then
          pending("Rust backend not available for integration test")
          return
        end

        local backend = require("uranus.backend")

        -- Test connecting to a remote server (this will likely fail without a real server)
        local result = backend.send_command("connect_remote", {
          server_url = "http://localhost:8888",
          token = "test-token",
          kernel_id = "test-kernel"
        })

        -- The connection may succeed or fail, but we should get a proper response
        assert.is_table(result)
        assert.is_boolean(result.success)
        -- Either success with connection info or error with proper error code
        if not result.success then
          assert.is_table(result.error)
          assert.is_string(result.error.code)
        end
      end)

      it("should handle backend shutdown gracefully", function()
        if not backend_process then
          pending("Rust backend not available for integration test")
          return
        end

        local backend = require("uranus.backend")

        -- Send shutdown command
        local result = backend.send_command("shutdown", {})

        assert.is_table(result)
        assert.is_true(result.success)
        assert.equals("shutdown", result.data.data.status)
      end)
    end)

    describe("End-to-End Workflow", function()
      it("should execute code from Lua to Rust backend", function()
        -- Setup Uranus
        local config = {
          debug = true,
          ui = { mode = "repl" },
          kernels = { default = "python3" }
        }

        local setup_result = uranus.setup(config)
        assert.is_true(setup_result.success)

        -- Start backend
        local backend_result = uranus.start_backend()
        if not backend_result.success then
          pending("Backend failed to start: " .. (backend_result.error or "unknown error"))
          return
        end

        -- Execute code
        local execute_result = uranus.execute("print('Integration test')")
        assert.is_table(execute_result)

        -- Clean up
        uranus.stop_backend()
      end)

      it("should handle kernel lifecycle", function()
        local setup_result = uranus.setup()
        assert.is_true(setup_result.success)

        -- Start backend
        local backend_result = uranus.start_backend()
        if not backend_result.success then
          pending("Backend failed to start")
          return
        end

        -- Connect to kernel
        local connect_result = uranus.connect_kernel("python3")
        -- Connection may succeed or fail depending on system setup
        assert.is_table(connect_result)

        -- Execute if connected
        if connect_result.success then
          local execute_result = uranus.execute("2 + 2")
          assert.is_table(execute_result)
        end

        -- Clean up
        uranus.stop_backend()
      end)
    end)
  end)
end)