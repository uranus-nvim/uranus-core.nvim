--- Uranus.nvim - Jupyter kernel integration for Neovim
---
--- Uranus provides seamless local and remote Jupyter kernel integration
--- with VSCode-like REPL and Notebook modes.
---
--- @module uranus
--- @license MIT
--- @author Your Name

local M = {}

---@class UranusConfig
---@field debug? boolean Enable debug logging
---@field log_level? string Log level ("DEBUG", "INFO", "WARN", "ERROR")
---@field lsp? UranusLspConfig LSP integration settings
---@field ui? UranusUIConfig UI customization options
---@field kernels? UranusKernelConfig Kernel management settings
---@field remote_servers? UranusRemoteServer[] Remote server configurations
---@field cell? UranusCellConfig Cell parsing and execution settings
---@field output? UranusOutputConfig Output rendering configuration
---@field keymaps? UranusKeymapConfig Keymap settings

---@class UranusLspConfig
---@field enable boolean Enable LSP integration
---@field server string LSP server to use ("pyright", "pylsp", "jedi")
---@field auto_attach boolean Auto-attach to buffers
---@field diagnostics boolean Show LSP diagnostics

---@class UranusUIConfig
---@field mode "repl"|"notebook"|"both" UI mode
---@field repl UranusReplUIConfig REPL UI settings
---@field image UranusImageUIConfig Image display settings
---@field markdown_renderer "markview"|"render-markdown" Markdown renderer

---@class UranusReplUIConfig
---@field view "floating"|"virtualtext"|"terminal" Output display method
---@field max_height number Maximum output window height
---@field max_width number Maximum output window width

---@class UranusImageUIConfig
---@field backend "snacks"|"image.nvim" Image rendering backend
---@field max_width number Maximum image width
---@field max_height number Maximum image height

---@class UranusKernelConfig
---@field auto_start boolean Auto-start default kernel
---@field default string Default kernel name
---@field timeout number Connection timeout in milliseconds
---@field discovery_paths string[] Paths to search for kernel files

---@class UranusRemoteServer
---@field name string Server display name
---@field url string Server URL
---@field token string Authentication token
---@field headers? table Additional HTTP headers

---@class UranusCellConfig
---@field marker string Cell separator marker
---@field auto_execute boolean Auto-execute cells on save
---@field highlight boolean Highlight cell markers

---@class UranusOutputConfig
---@field max_lines number Maximum lines to display
---@field image_dir string Directory for temporary images
---@field cleanup_temp boolean Clean up temporary files
---@field cleanup_interval number Cleanup interval in milliseconds

---@class UranusKeymapConfig
---@field enable boolean Enable default keymaps
---@field prefix string Keymap prefix
---@field mappings table<string, string> Keymap mappings

--- Plugin version
M.version = "0.1.0"

--- Default configuration
---@type UranusConfig
M.default_config = {
  debug = false,
  log_level = "INFO",

  lsp = {
    enable = true,
    server = "pyright",
    auto_attach = true,
    diagnostics = true,
  },

  ui = {
    mode = "both",
    repl = {
      view = "floating",
      max_height = 20,
      max_width = 80,
    },
    image = {
      backend = "snacks",
      max_width = 800,
      max_height = 600,
    },
    markdown_renderer = "markview",
  },

  kernels = {
    auto_start = true,
    default = "python3",
    timeout = 10000,
    discovery_paths = {
      vim.fn.expand("~/.local/share/jupyter/runtime"),
      vim.fn.expand("~/.jupyter/runtime"),
      "/tmp/jupyter/runtime",
    },
  },

  remote_servers = {},

  cell = {
    marker = "# %%",
    auto_execute = false,
    highlight = true,
  },

  output = {
    max_lines = 1000,
    image_dir = vim.fn.stdpath("cache") .. "/uranus/images",
    cleanup_temp = true,
    cleanup_interval = 300000, -- 5 minutes
  },

  keymaps = {
    enable = true,
    prefix = "<leader>u",
    mappings = {
      run_cell = "c",
      run_all = "a",
      run_selection = "s",
      next_cell = "j",
      prev_cell = "k",
      kernel_select = "k",
      notebook_toggle = "n",
    },
  },
}

--- Current configuration
---@type UranusConfig
M.config = {}

--- Plugin state
---@class UranusState
---@field backend_running boolean Backend process status
---@field current_kernel UranusKernelInfo|nil Current kernel information
---@field buffers table<number, UranusBufferState> Buffer-specific state

---@type UranusState
M.state = {
  backend_running = false,
  current_kernel = nil,
  buffers = {},
}

--- Logger instance
M.logger = nil

--- Setup Uranus with user configuration
---@param opts? UranusConfig User configuration
---@return UranusResult Success result or error
function M.setup(opts)
  -- Version check
  if vim.version().minor < 11 or (vim.version().minor == 11 and vim.version().patch < 4) then
    return M.err("VERSION", "Uranus requires Neovim 0.11.4+")
  end

  -- Enable modern loader if available
  if vim.loader then
    vim.loader.enable()
  end

  -- Merge user config with defaults
  M.config = vim.tbl_deep_extend("force", M.default_config, opts or {})

  -- Validate configuration first
  local config_result = require("uranus.config").validate(M.config)
  if not config_result.success then
    -- Create a basic logger for error reporting
    local basic_logger = require("uranus.logger").new("ERROR", false)
    basic_logger.error("Configuration validation failed: " .. config_result.error.message)
    return config_result
  end

  -- Use validated config
  M.config = config_result.data

  -- Initialize logger with validated config
  M.logger = require("uranus.logger").new(M.config.log_level or "INFO", M.config.debug)

  M.logger.info("Uranus v" .. M.version .. " initialized")

  -- Initialize components
  local init_result = M._initialize_components()
  if not init_result.success then
    M.logger.error("Component initialization failed: " .. init_result.error.message)
    return init_result
  end

  -- Set up autocommands
  M._setup_autocommands()

  -- Set up keymaps if enabled
  if M.config.keymaps.enable then
    M._setup_keymaps()
  end

  M.logger.info("Uranus setup complete")
  return M.ok(true)
end

--- Initialize plugin components
---@return UranusResult
function M._initialize_components()
  local components = {
    "logger",
    "config",
    "backend",
    "kernel",
    "ui",
    "output",
    "repl",
    "notebook",
    "remote",
  }

  for _, component in ipairs(components) do
    local ok, module = pcall(require, "uranus." .. component)
    if not ok then
      M.logger.warn("Failed to load component '" .. component .. "': " .. module)
    else
      -- Call init function if it exists
      if type(module.init) == "function" then
        local result = module.init(M.config)
        if not result.success then
          return M.err("INIT", "Failed to initialize " .. component .. ": " .. result.error.message)
        end
      end
    end
  end

  return M.ok(true)
end

--- Set up autocommands
function M._setup_autocommands()
  local augroup = vim.api.nvim_create_augroup("Uranus", { clear = true })

  -- File type detection
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    group = augroup,
    pattern = "*.ipynb",
    callback = function()
      require("uranus.notebook").setup_buffer()
    end,
  })

  -- LSP integration
  if M.config.lsp.enable then
    vim.api.nvim_create_autocmd("LspAttach", {
      group = augroup,
      callback = function(args)
        require("uranus.lsp").on_attach(args.buf)
      end,
    })
  end

  -- Cleanup on exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      M.cleanup()
    end,
  })
end

--- Set up default keymaps
function M._setup_keymaps()
  local prefix = M.config.keymaps.prefix
  local mappings = M.config.keymaps.mappings

  -- REPL keymaps
  vim.keymap.set("n", prefix .. mappings.run_cell, function()
    require("uranus.repl").run_cell()
  end, { desc = "Run current cell" })

  vim.keymap.set("n", prefix .. mappings.run_all, function()
    require("uranus.repl").run_all()
  end, { desc = "Run all cells" })

  vim.keymap.set("v", prefix .. mappings.run_selection, function()
    require("uranus.repl").run_selection()
  end, { desc = "Run selection" })

  -- Navigation
  vim.keymap.set("n", prefix .. mappings.next_cell, function()
    require("uranus.repl").next_cell()
  end, { desc = "Next cell" })

  vim.keymap.set("n", prefix .. mappings.prev_cell, function()
    require("uranus.repl").prev_cell()
  end, { desc = "Previous cell" })

  -- Kernel management
  vim.keymap.set("n", prefix .. mappings.kernel_select, function()
    require("uranus.kernel").select_kernel()
  end, { desc = "Select kernel" })

  -- Notebook mode
  vim.keymap.set("n", prefix .. mappings.notebook_toggle, function()
    require("uranus.notebook").toggle()
  end, { desc = "Toggle notebook mode" })
end

--- Start the Rust backend
---@return UranusResult
function M.start_backend()
  if M.state.backend_running then
    return M.ok(true)
  end

  local backend = require("uranus.backend")
  local result = backend.start()

  if result.success then
    M.state.backend_running = true
    M.logger.info("Backend started successfully")
  else
    M.logger.error("Failed to start backend: " .. result.error)
  end

  return result
end

--- Stop the Rust backend
---@return UranusResult
function M.stop_backend()
  if not M.state.backend_running then
    return M.ok(true)
  end

  local backend = require("uranus.backend")
  local result = backend.stop()

  if result.success then
    M.state.backend_running = false
    M.logger.info("Backend stopped successfully")
  else
    M.logger.error("Failed to stop backend: " .. result.error)
  end

  return result
end

--- Connect to a kernel
---@param kernel_name string Kernel name
---@return UranusResult
function M.connect_kernel(kernel_name)
  local kernel = require("uranus.kernel")
  return kernel.connect(kernel_name)
end

--- Execute code
---@param code string Code to execute
---@param opts? table Execution options
---@return UranusResult
function M.execute(code, opts)
  if not M.state.backend_running then
    return M.err("BACKEND", "Backend is not running")
  end

  local kernel = require("uranus.kernel")
  return kernel.execute(code, opts)
end

--- Get plugin status
---@return UranusStatus
function M.status()
  return {
    version = M.version,
    backend_running = M.state.backend_running,
    current_kernel = M.state.current_kernel,
    config_valid = true, -- TODO: Add config validation check
  }
end

--- Cleanup resources
function M.cleanup()
  M.logger.info("Cleaning up Uranus resources")

  -- Stop backend
  M.stop_backend()

  -- Cleanup temporary files
  if M.config.output.cleanup_temp then
    require("uranus.output").cleanup_temp_files()
  end

  -- Clear state
  M.state = {
    backend_running = false,
    current_kernel = nil,
    buffers = {},
  }
end

--- Create success result
---@generic T
---@param data T Data
---@return UranusResult<T>
function M.ok(data)
  return { success = true, data = data }
end

--- Create error result
---@param code string Error code
---@param message string Error message
---@param context? table Additional context
---@return UranusResult
function M.err(code, message, context)
  return {
    success = false,
    error = {
      code = code,
      message = message,
      context = context,
    }
  }
end

return M