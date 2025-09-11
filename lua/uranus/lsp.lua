--- Uranus LSP integration
---
--- Provides LSP server management and integration with Jupyter kernels
--- for enhanced code intelligence and diagnostics.
---
--- @module uranus.lsp
--- @license MIT

local M = {}

---@class UranusLspConfig
---@field enable boolean Enable LSP integration
---@field server string LSP server to use
---@field auto_attach boolean Auto-attach to buffers
---@field diagnostics boolean Show LSP diagnostics

--- Module state
---@type UranusLspConfig|nil
M.config = nil

---@type table<number, boolean>
M.attached_buffers = {}

--- Initialize LSP integration
---@param config UranusLspConfig LSP configuration
---@return UranusResult
function M.init(config)
  M.config = config

  if not config.enable then
    return M.ok(true)
  end

  -- Set up LSP server
  M._setup_lsp_server()

  return M.ok(true)
end

--- Set up LSP server configuration
function M._setup_lsp_server()
  if not M.config then return end

  local server_name = M.config.server

  -- Check if LSP server is available
  local has_server = pcall(require, "lspconfig." .. server_name)
  if not has_server then
    vim.notify("LSP server '" .. server_name .. "' not found. Install with :LspInstall " .. server_name,
      vim.log.levels.WARN)
    return
  end

  -- Configure LSP server
  local lspconfig = require("lspconfig")
  local server_config = lspconfig[server_name]

  if server_config then
    server_config.setup({
      on_attach = M.on_attach,
      capabilities = M._get_capabilities(),
      settings = M._get_server_settings(server_name),
    })
  end
end

--- Get LSP capabilities
---@return table LSP capabilities
function M._get_capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()

  -- Add additional capabilities for better Jupyter integration
  capabilities.textDocument.completion.completionItem.snippetSupport = true
  capabilities.textDocument.completion.completionItem.resolveSupport = {
    properties = { "documentation", "detail", "additionalTextEdits" }
  }

  return capabilities
end

--- Get server-specific settings
---@param server_name string LSP server name
---@return table Server settings
function M._get_server_settings(server_name)
  local settings = {}

  if server_name == "pyright" then
    settings.python = {
      analysis = {
        typeCheckingMode = "basic",
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
      },
    }
  elseif server_name == "pylsp" then
    settings.pylsp = {
      plugins = {
        jedi_completion = { enabled = true },
        jedi_hover = { enabled = true },
        jedi_references = { enabled = true },
        jedi_signature_help = { enabled = true },
        jedi_symbols = { enabled = true },
        mccabe = { enabled = false },
        preload = { enabled = false },
        pycodestyle = { enabled = false },
        pydocstyle = { enabled = false },
        pyflakes = { enabled = false },
        pylint = { enabled = false },
        rope_completion = { enabled = false },
        yapf = { enabled = false },
      },
    }
  elseif server_name == "ruff" then
    settings.ruff = {
      enable = true,
      organizeImports = true,
      fixAll = true,
    }
  end

  return settings
end

--- Called when LSP attaches to a buffer
---@param client table LSP client
---@param bufnr number Buffer number
function M.on_attach(client, bufnr)
  if not M.config or not M.config.auto_attach then
    return
  end

  M.attached_buffers[bufnr] = true

  -- Set up buffer-local keymaps
  M._setup_buffer_keymaps(bufnr)

  -- Configure diagnostics if enabled
  if M.config.diagnostics then
    M._setup_diagnostics(bufnr)
  end

  vim.notify("Uranus LSP attached to buffer " .. bufnr, vim.log.levels.INFO)
end

--- Set up buffer-local keymaps for LSP
---@param bufnr number Buffer number
function M._setup_buffer_keymaps(bufnr)
  local opts = { noremap = true, silent = true, buffer = bufnr }

  -- LSP keymaps
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
  vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
  vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
  vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
  vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
  vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
  vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
end

--- Set up diagnostics for buffer
---@param bufnr number Buffer number
function M._setup_diagnostics(bufnr)
  -- Configure diagnostic display
  vim.diagnostic.config({
    virtual_text = {
      prefix = "●",
      source = "if_many",
    },
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = {
      border = "rounded",
      source = "always",
    },
  }, bufnr)

  -- Set up diagnostic signs
  local signs = {
    Error = "",
    Warn = "",
    Hint = "",
    Info = "",
  }

  for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
  end
end

--- Check if LSP is attached to buffer
---@param bufnr? number Buffer number (default: current)
---@return boolean LSP attached status
function M.is_attached(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return M.attached_buffers[bufnr] or false
end

--- Detach LSP from buffer
---@param bufnr? number Buffer number (default: current)
---@return UranusResult
function M.detach(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not M.attached_buffers[bufnr] then
    return M.ok(true)
  end

  -- Stop LSP client for this buffer
  local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
  for _, client in ipairs(clients) do
    vim.lsp.stop_client(client.id)
  end

  M.attached_buffers[bufnr] = nil

  vim.notify("Uranus LSP detached from buffer " .. bufnr, vim.log.levels.INFO)

  return M.ok(true)
end

--- Get LSP status
---@return table LSP status information
function M.status()
  return {
    enabled = M.config and M.config.enable or false,
    server = M.config and M.config.server or nil,
    attached_buffers = vim.tbl_count(M.attached_buffers),
    diagnostics_enabled = M.config and M.config.diagnostics or false,
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