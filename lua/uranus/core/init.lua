--- Uranus.nvim - Jupyter kernel integration for Neovim
---
--- Seamless Jupyter kernel integration with real kernel communication via ZeroMQ.
--- Supports both local and remote kernels with rich output rendering.
---
--- @module uranus
--- @license MIT
--- @author Uranus.nvim Team
--- @copyright 2024-2025
---
--- @usage
---   -- With lazy.nvim:
---   {
---     "your-username/uranus-core.nvim",
---     config = function()
---       require("uranus").setup({
---         auto_install_jupyter = true,
---         auto_install_parsers = true,
---       })
---     end,
---   }
---
--- @usage
---   -- Manual setup:
---   require("uranus").setup({
---     auto_install_jupyter = true,
---     output = { use_virtual_text = true },
---   })

local M = {}

M._VERSION = "0.1.0"

local config_mod = nil
local state_mod = nil

local function get_config()
  if not config_mod then
    config_mod = require("uranus.config")
  end
  return config_mod
end

local function get_state()
  if not state_mod then
    state_mod = require("uranus.state")
  end
  return state_mod
end

--- Merge user config with defaults
---@param user_config table?
---@return table
local function merge_config(user_config)
  local cfg = get_config()
  return cfg.init(user_config)
end

--- Check Neovim version
---@return boolean
local function check_version()
  local version = vim.version()
  if version.major == 0 and version.minor < 11 then
    vim.notify(
      "Uranus requires Neovim 0.11+. Current version: "
        .. version.major
        .. "."
        .. version.minor
        .. "."
        .. version.patch,
      vim.log.levels.ERROR
    )
    return false
  end
  return true
end

--- Initialize the plugin
---@param user_config UranusConfig?
---@return { success: boolean, error: string? }
function M.setup(user_config)
  -- Validate Neovim version
  if not check_version() then
    return { success = false, error = "Neovim version too old" }
  end

  -- Prevent double initialization
  if get_state():is_initialized() then
    vim.notify("Uranus is already initialized", vim.log.levels.WARN)
    return { success = false, error = "Already initialized" }
  end

  -- Merge configuration
  local config = merge_config(user_config)

  -- Validate configuration
  local config_module = require("uranus.config")
  local validation = config_module.init(config)
  if not validation.success then
    return { success = false, error = validation.error }
  end

  -- Set global configuration
  M.config = config

  -- Enable modern loader
  if vim.loader then
    vim.loader.enable()
  end

  -- Initialize submodules
  local init_ok, err = pcall(function()
    -- Initialize parsers (Treesitter)
    if config.treesitter.enabled then
      local parsers = require("uranus.parsers")
      local result = parsers.init(config)
      if not result.success then
        vim.notify("Failed to initialize parsers: " .. result.message, vim.log.levels.WARN)
      end
    end

    -- Initialize cache
    if config.cache.enabled then
      local cache = require("uranus.cache")
      cache.configure(config.cache)
    end

    -- Initialize LSP if enabled
    if config.lsp.enabled then
      local lsp = require("uranus.lsp")
      lsp.configure(config.lsp)
    end

    -- Setup keymaps
    if config.keymaps.enabled then
      M.setup_keymaps()
    end

    -- Auto-start backend
    if not vim.g.uranus_backend_started then
      local result = M.start_backend()
      if result.success then
        vim.g.uranus_backend_started = true
        get_state():set_backend_running(true)
      else
        vim.notify("Failed to start backend: " .. result.error.message, vim.log.levels.ERROR)
      end
    end
  end)

  if not init_ok then
    return { success = false, error = "Initialization error: " .. tostring(err) }
  end

  get_state():set_initialized()
  state.config = config

  vim.notify("Uranus.nvim initialized successfully", vim.log.levels.INFO)
  return { success = true }
end

--- Setup keymaps
function M.setup_keymaps()
  local keymaps = require("uranus.keymaps")
  local config = M.config or get_config():get_config()

  -- REPL mode keymaps
  local repl_prefix = config.keymaps.prefix or "<leader>ur"
  keymaps.set_with_desc("n", repl_prefix .. "c", ":UranusRunCell<cr>", "Run current cell")
  keymaps.set_with_desc("n", repl_prefix .. "a", ":UranusRunAll<cr>", "Run all cells")
  keymaps.set_with_desc("n", repl_prefix .. "n", ":UranusNextCell<cr>", "Next cell")
  keymaps.set_with_desc("n", repl_prefix .. "p", ":UranusPrevCell<cr>", "Previous cell")
  keymaps.set_with_desc("n", repl_prefix .. "i", ":UranusInsertCell<cr>", "Insert cell")
  keymaps.set_with_desc("v", repl_prefix .. "e", ":<c-u>UranusRunSelection<cr>", "Run selection")

  -- UI keymaps
  keymaps.set_with_desc("n", repl_prefix .. "k", ":UranusPickKernel<cr>", "Pick kernel")
  keymaps.set_with_desc("n", repl_prefix .. "d", ":UranusDebug<cr>", "Debug view")

  -- Notebook keymaps
  local notebook_prefix = config.keymaps.notebook_prefix or "<leader>uj"
  keymaps.set_with_desc("n", notebook_prefix .. "n", ":UranusNotebookNew<cr>", "New notebook")
  keymaps.set_with_desc("n", notebook_prefix .. "o", ":UranusNotebookOpen<cr>", "Open notebook")
  keymaps.set_with_desc("n", notebook_prefix .. "s", ":UranusNotebookSave<cr>", "Save notebook")
  keymaps.set_with_desc("n", notebook_prefix .. "r", ":UranusNotebookRunCell<cr>", "Run cell")
  keymaps.set_with_desc("n", notebook_prefix .. "a", ":UranusNotebookRunAll<cr>", "Run all")
  keymaps.set_with_desc("n", notebook_prefix .. "d", ":UranusNotebookDeleteCell<cr>", "Delete cell")
  keymaps.set_with_desc("n", notebook_prefix .. "t", ":UranusNotebookToggleCell<cr>", "Toggle cell type")
  keymaps.set_with_desc("n", notebook_prefix .. "c", ":UranusNotebookClearOutput<cr>", "Clear output")
  keymaps.set_with_desc("n", notebook_prefix .. "i", ":UranusInspectorToggle<cr>", "Toggle inspector")

  -- Notebook UI keymaps
  local notebook_ui_prefix = config.keymaps.notebook_ui_prefix or "<leader>k"
  keymaps.set_with_desc("n", notebook_ui_prefix .. "n", "<cmd>UranusNotebookUIExecute<cr>", "Execute cell")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "N", "<cmd>UranusNotebookUIExecuteNext<cr>", "Execute and next")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "]", "<cmd>UranusNotebookUINNextCell<cr>", "Next cell")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "[", "<cmd>UranusNotebookUINPrevCell<cr>", "Previous cell")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "j", "<cmd>UranusNotebookUIGotoCell<cr>", "Go to cell")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "i", "<cmd>UranusNotebookUIInsertCell<cr>", "Insert cell")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "t", "<cmd>UranusNotebookUIToggleType<cr>", "Toggle type")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "l", "<cmd>UranusNotebookUIToggleFold<cr>", "Toggle fold")
  keymaps.set_with_desc("n", "K", "<cmd>UranusNotebookUIHover<cr>", "Show hover")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "h", "<cmd>UranusNotebookUIHideHover<cr>", "Hide hover")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "e", "<cmd>UranusNotebookUIFormatCell<cr>", "Format cell")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "E", "<cmd>UranusNotebookUIFormatAll<cr>", "Format all")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "s", "<cmd>UranusCheckHealth<cr>", "Health check")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "H", "<cmd>UranusNotebookUIToggleHover<cr>", "Toggle hover")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "D", "<cmd>UranusNotebookUIToggleDiagnostics<cr>", "Toggle diagnostics")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "L", "<cmd>UranusNotebookUIToggleCodeLens<cr>", "Toggle code lens")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "a", "<cmd>UranusNotebookUIRunAllAsync<cr>", "Run all async")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "A", "<cmd>UranusNotebookUIRunParallel<cr>", "Run parallel")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "u", "<cmd>UranusNotebookUIStop<cr>", "Stop execution")
  keymaps.set_with_desc("n", notebook_ui_prefix .. "m", "<cmd>UranusNotebookUIToggleMode<cr>", "Toggle mode")

  -- LSP keymaps
  local lsp_prefix = config.keymaps.lsp_prefix or "<leader>ul"
  keymaps.set_with_desc("n", lsp_prefix .. "s", "<cmd>UranusLSPStatus<cr>", "LSP status")
  keymaps.set_with_desc("n", lsp_prefix .. "u", "<cmd>UranusLSPHover<cr>", "LSP hover")
  keymaps.set_with_desc("n", lsp_prefix .. "g", "<cmd>UranusLSPDefinition<cr>", "Go to definition")
  keymaps.set_with_desc("n", lsp_prefix .. "r", "<cmd>UranusLSPReferences<cr>", "References")
  keymaps.set_with_desc("n", lsp_prefix .. "d", "<cmd>UranusLSPDiagnostics<cr>", "Diagnostics")
  keymaps.set_with_desc("n", lsp_prefix .. "w", "<cmd>UranusLSPWorkspaceSymbols<cr>", "Workspace symbols")
  keymaps.set_with_desc("n", lsp_prefix .. "n", "<cmd>UranusLSPRename<cr>", "Rename")
  keymaps.set_with_desc("n", lsp_prefix .. "a", "<cmd>UranusLSPCodeAction<cr>", "Code action")
  keymaps.set_with_desc("n", lsp_prefix .. "f", "<cmd>UranusLSPFormat<cr>", "Format")
  keymaps.set_with_desc("n", lsp_prefix .. "h", "<cmd>UranusLSPInlayHints<cr>", "Inlay hints")
  keymaps.set_with_desc("n", lsp_prefix .. "i", "<cmd>UranusLSPIncomingCalls<cr>", "Incoming calls")
  keymaps.set_with_desc("n", lsp_prefix .. "o", "<cmd>UranusLSPOutgoingCalls<cr>", "Outgoing calls")
end

--- Start the backend
---@return { success: boolean, error: table? }
function M.start_backend()
  local ok, result = pcall(function()
    local uranus = require("uranus") -- This loads the Rust backend
    return uranus.start_backend()
  end)

  if not ok or not result then
    return {
      success = false,
      error = { code = "BACKEND_START_FAILED", message = tostring(result) },
    }
  end

  -- Parse JSON result
  local ok, data = pcall(vim.json.decode, result)
  if not ok or not data.success then
    return {
      success = false,
      error = { code = "BACKEND_START_FAILED", message = "Failed to start backend" },
    }
  end

  state.backend_running = true
  get_state():set_backend_running(true)
  return { success = true }
end

--- Stop the backend
---@return { success: boolean, error: table? }
function M.stop_backend()
  local ok, result = pcall(function()
    local uranus = require("uranus")
    return uranus.stop_backend()
  end)

  if not ok then
    return {
      success = false,
      error = { code = "BACKEND_STOP_FAILED", message = tostring(result) },
    }
  end

  state.backend_running = false
  get_state():set_backend_running(false)
  return { success = true }
end

--- Get plugin status
---@return { backend_running: boolean, version: string, config: table }
function M.status()
  return {
    backend_running = get_state():is_backend_running(),
    version = M._VERSION,
    config = M.config,
  }
end

--- Check if plugin is initialized
---@return boolean
function M.is_initialized()
  return get_state():is_initialized()
end

--- Get configuration
---@return UranusConfig
function M.get_config()
  return M.config or get_config():get_config()
end

--- Expose Rust backend functions directly
setmetatable(M, {
  __index = function(_, key)
    -- Try to load from Rust backend
    local ok, uranus = pcall(require, "uranus")
    if ok and uranus[key] then
      return uranus[key]
    end

    -- Fallback to Lua modules
    local module_name = "uranus." .. key
    local ok, module = pcall(require, module_name)
    if ok then
      return module
    end

    return nil
  end,
})

return M
