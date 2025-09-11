--- Uranus plugin initialization
---
--- This file handles the plugin initialization and lazy loading
--- for Uranus.nvim. It ensures proper setup and version checking.
---
--- @module plugin.uranus
--- @license MIT

-- Early version check to prevent loading on incompatible Neovim versions
if vim.version().minor < 11 or (vim.version().minor == 11 and vim.version().patch < 4) then
  vim.notify_once(
    "Uranus requires Neovim 0.11.4+. Current version: " .. vim.version().major .. "." ..
    vim.version().minor .. "." .. vim.version().patch,
    vim.log.levels.ERROR
  )
  return
end

-- Enable modern loader for better performance (Neovim 0.11+)
if vim.loader then
  vim.loader.enable()
end

-- Plugin metadata
local M = {
  name = "uranus.nvim",
  version = "0.1.0",
  description = "Jupyter kernel integration for Neovim",
}

--- Lazy initialization function
--- Called when the plugin should be fully loaded
function M._lazy_init()
  -- Check if already initialized
  if _G.uranus_initialized then
    return
  end

  -- Load the main module
  local ok, uranus = pcall(require, "uranus")
  if not ok then
    vim.notify("Failed to load Uranus: " .. uranus, vim.log.levels.ERROR)
    return
  end

  -- Check if user has configured the plugin
  if not _G.uranus_configured then
    -- Auto-setup with defaults if not configured
    local result = uranus.setup()
    if not result.success then
      vim.notify("Uranus auto-setup failed: " .. result.error.message, vim.log.levels.ERROR)
      return
    end
    vim.notify("Uranus loaded with default configuration", vim.log.levels.INFO)
  end

  _G.uranus_initialized = true
end

--- Setup function for manual configuration
--- This is called when user configures Uranus in their init.lua
---@param opts? UranusConfig User configuration
---@return UranusResult
function M.setup(opts)
  -- Mark as configured to prevent auto-setup
  _G.uranus_configured = true

  -- Load and setup the main module
  local ok, uranus = pcall(require, "uranus")
  if not ok then
    return {
      success = false,
      error = {
        code = "LOAD_FAILED",
        message = "Failed to load Uranus: " .. uranus,
      }
    }
  end

  return uranus.setup(opts)
end

-- Export setup function for lazy.nvim and manual setup
_G.Uranus = M

-- Set up lazy loading with VeryLazy event
-- This ensures the plugin loads after most other plugins
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    M._lazy_init()
  end,
  once = true,
})

-- Create user commands
vim.api.nvim_create_user_command("UranusStart", function()
  M._lazy_init()
  local uranus = require("uranus")
  local result = uranus.start_backend()
  if result.success then
    vim.notify("Uranus backend started", vim.log.levels.INFO)
  else
    vim.notify("Failed to start Uranus backend: " .. result.error.message, vim.log.levels.ERROR)
  end
end, {
  desc = "Start the Uranus backend",
})

vim.api.nvim_create_user_command("UranusStop", function()
  local uranus = require("uranus")
  local result = uranus.stop_backend()
  if result.success then
    vim.notify("Uranus backend stopped", vim.log.levels.INFO)
  else
    vim.notify("Failed to stop Uranus backend: " .. result.error.message, vim.log.levels.ERROR)
  end
end, {
  desc = "Stop the Uranus backend",
})

vim.api.nvim_create_user_command("UranusStatus", function()
  local uranus = require("uranus")
  local status = uranus.status()

  local lines = {
    "Uranus Status:",
    "  Version: " .. status.version,
    "  Backend: " .. (status.backend_running and "Running" or "Stopped"),
    "  Kernel: " .. (status.current_kernel and status.current_kernel.name or "None"),
    "  Config: " .. (status.config_valid and "Valid" or "Invalid"),
  }

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, {
  desc = "Show Uranus status",
})

vim.api.nvim_create_user_command("UranusConnect", function(opts)
  M._lazy_init()
  local uranus = require("uranus")
  local kernel_name = opts.args ~= "" and opts.args or nil

  if not kernel_name then
    vim.notify("Usage: UranusConnect <kernel_name>", vim.log.levels.ERROR)
    return
  end

  local result = uranus.connect_kernel(kernel_name)
  if result.success then
    vim.notify("Connected to kernel: " .. kernel_name, vim.log.levels.INFO)
  else
    vim.notify("Failed to connect to kernel: " .. result.error.message, vim.log.levels.ERROR)
  end
end, {
  desc = "Connect to a Jupyter kernel",
  nargs = 1,
  complete = function()
    -- TODO: Add kernel name completion
    return {}
  end,
})

vim.api.nvim_create_user_command("UranusExecute", function(opts)
  M._lazy_init()
  local uranus = require("uranus")
  local code = opts.args

  if code == "" then
    vim.notify("Usage: UranusExecute <code>", vim.log.levels.ERROR)
    return
  end

  local result = uranus.execute(code)
  if not result.success then
    vim.notify("Execution failed: " .. result.error.message, vim.log.levels.ERROR)
  end
end, {
  desc = "Execute code in the current kernel",
  nargs = "+",
})

-- Export the module
return M