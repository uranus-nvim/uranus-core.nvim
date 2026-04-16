--- Uranus Treesitter parser management
--- Handles automatic parser installation and validation
---
--- @module uranus.parsers

local M = {}

--- Required parsers for Uranus functionality
local REQUIRED_PARSERS = {
  python = true,
  json = true, -- for .ipynb parsing
  markdown = true, -- for markdown cells
}

--- Parser installation status
local installed_parsers = {}
local installation_in_progress = false

--- Check if Treesitter is available
---@return boolean
function M.has_treesitter()
  local ok, _ = pcall(require, "nvim-treesitter")
  return ok
end

--- Check if a parser is installed
---@param lang string
---@return boolean
function M.is_parser_installed(lang)
  if not M.has_treesitter() then
    return false
  end

  local ok, parsers = pcall(require, "nvim-treesitter.parsers")
  if not ok then
    return false
  end

  local parser = parsers.get_parser(0, lang)
  return parser ~= nil
end

--- Get list of installed parsers
---@return string[]
function M.get_installed_parsers()
  if not M.has_treesitter() then
    return {}
  end

  local ok, parsers = pcall(require, "nvim-treesitter.parsers")
  if not ok then
    return {}
  end

  local installed = {}
  local success, parser_list = pcall(parsers.get_installed_langs)
  if success and parser_list then
    installed = parser_list
  end

  return installed
end

--- Get list of missing required parsers
---@return string[]
function M.get_missing_parsers()
  local missing = {}
  local installed = M.get_installed_parsers()

  for parser, _ in pairs(REQUIRED_PARSERS) do
    local found = false
    for _, installed_parser in ipairs(installed) do
      if installed_parser == parser then
        found = true
        break
      end
    end

    if not found then
      table.insert(missing, parser)
    end
  end

  return missing
end

--- Install a single parser
---@param lang string
---@return { success: boolean, error: string? }
local function install_parser(lang)
  if not M.has_treesitter() then
    return { success = false, error = "Treesitter not available" }
  end

  -- Check if already installed
  if M.is_parser_installed(lang) then
    return { success = true }
  end

  vim.notify(string.format("Installing Treesitter parser: %s", lang), vim.log.levels.INFO)

  local ok, install = pcall(require, "nvim-treesitter.install")
  if not ok then
    return { success = false, error = "Failed to load treesitter install module" }
  end

  -- Install the parser
  local success, result = pcall(function()
    install.update({ lang })
  end)

  if not success then
    return { success = false, error = "Installation failed: " .. tostring(result) }
  end

  -- Verify installation
  vim.schedule(function()
    if M.is_parser_installed(lang) then
      vim.notify(string.format("Successfully installed parser: %s", lang), vim.log.levels.INFO)
      installed_parsers[lang] = true
    else
      vim.notify(
        string.format("Failed to install parser: %s. Please install manually with :TSInstall %s", lang, lang),
        vim.log.levels.ERROR
      )
    end
  end)

  return { success = true }
end

--- Install missing parsers
---@return { success: boolean, installed: string[], missing: string[] }
function M.install_missing()
  if not M.has_treesitter() then
    return { success = false, installed = {}, missing = {} }
  end

  if installation_in_progress then
    return { success = false, installed = {}, missing = {}, error = "Installation already in progress" }
  end

  installation_in_progress = true
  local missing = M.get_missing_parsers()
  local installed = {}

  if #missing == 0 then
    installation_in_progress = false
    return { success = true, installed = {}, missing = {} }
  end

  vim.notify(string.format("Installing %d missing parser(s): %s", #missing, table.concat(missing, ", ")), vim.log.levels.INFO)

  -- Install parsers sequentially
  for _, lang in ipairs(missing) do
    local result = install_parser(lang)
    if result.success then
      table.insert(installed, lang)
    end
  end

  installation_in_progress = false

  return {
    success = true,
    installed = installed,
    missing = vim.list_slice(missing, #installed + 1, #missing),
  }
end

--- Ensure all required parsers are installed
---@param force boolean? Force reinstallation
---@return { success: boolean, message: string }
function M.ensure_parsers(force)
  force = force or false

  if not M.has_treesitter() then
    return {
      success = false,
      message = "Treesitter not available. Please install nvim-treesitter first.",
    }
  end

  local missing = M.get_missing_parsers()

  if #missing == 0 then
    return { success = true, message = "All required parsers are installed" }
  end

  if force then
    -- Force install all required parsers
    for parser, _ in pairs(REQUIRED_PARSERS) do
      install_parser(parser)
    end
    return { success = true, message = "Installing all required parsers" }
  else
    -- Install missing parsers
    local result = M.install_missing()
    if result.success then
      return {
        success = true,
        message = string.format(
          "Installed %d parser(s): %s",
          #result.installed,
          table.concat(result.installed, ", ")
        ),
      }
    else
      return {
        success = false,
        message = "Failed to install some parsers: " .. table.concat(result.missing, ", "),
      }
    end
  end
end

--- Validate notebook parsing
---@param path string
---@return { success: boolean, error: string? }
function M.validate_notebook_parsing(path)
  -- Check if file exists
  local file = io.open(path, "r")
  if not file then
    return { success = false, error = "File not found: " .. path }
  end
  file:close()

  -- Check if JSON parser is available (required for .ipynb)
  if not M.is_parser_installed("json") then
    return { success = false, error = "JSON parser not available for notebook parsing" }
  end

  -- Try to parse as JSON
  local content = io.open(path, "r"):read("*all")
  if not content then
    return { success = false, error = "Failed to read file" }
  end

  -- Basic JSON validation
  local ok, _ = pcall(vim.json.decode, content)
  if not ok then
    return { success = false, error = "Invalid JSON format in notebook" }
  end

  return { success = true }
end

--- Setup filetype detection for notebooks
function M.setup_filetype_detection()
  -- Add .ipynb filetype detection
  vim.filetype = vim.filetype or {}
  vim.filetype.add = vim.filetype.add or function() end

  vim.filetype.add({
    extension = {
      ipynb = "json",
    },
    pattern = {
      ["%.ipynb$"] = "json",
    },
  })

  -- Create autocmd for notebook files
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = "*.ipynb",
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local config = require("uranus.config")

      if config.get("notebook.auto_detect") then
        vim.schedule(function()
          local notebook = require("uranus.notebook")
          local path = vim.api.nvim_buf_get_name(bufnr)
          if path and path:match("%.ipynb$") then
            notebook.open(path)
          end
        end)
      end
    end,
  })
end

--- Initialize parsers module
---@param config UranusConfig?
---@return { success: boolean, message: string }
function M.init(config)
  config = config or {}

  -- Setup filetype detection
  M.setup_filetype_detection()

  -- Auto-install parsers if enabled
  if config.auto_install_parsers ~= false then
    local result = M.ensure_parsers()
    return result
  end

  return { success = true, message = "Parsers module initialized" }
end

return M
