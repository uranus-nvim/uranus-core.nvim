--- Uranus configuration management
--- Handles all plugin configuration with validation and defaults
--- SINGLE SOURCE OF TRUTH for all configuration
---
--- @module uranus.config

local M = {}

--- Master default configuration - ALL defaults should be here
---@class UranusConfig
---@field auto_install_jupyter boolean Automatically install Jupyter if not found
---@field auto_install_parsers boolean Automatically install Treesitter parsers
---@field async_execution boolean Enable async cell execution
---@field parallel_cells boolean Enable parallel cell execution
---@field max_parallel number Maximum parallel cells to execute
---@field output UranusOutputConfig Output configuration
---@field lsp UranusLSPConfig LSP configuration
---@field notebook UranusNotebookConfig Notebook configuration
---@field treesitter UranusTreesitterConfig Treesitter configuration
---@field cache UranusCacheConfig Cache configuration
---@field keymaps UranusKeymapsConfig Keymaps configuration
---@field kernel_manager UranusKernelManagerConfig Kernel manager configuration
---@field notebook_ui UranusNotebookUIConfig Notebook UI configuration
---@field repl UranusReplConfig REPL configuration
local defaults = {
  -- Core settings
  auto_install_jupyter = true,
  auto_install_parsers = true,

  -- Execution settings
  async_execution = false,
  parallel_cells = false,
  max_parallel = 4,

  --- Output configuration
  output = {
    use_virtual_text = true,
    use_snacks = true,
    max_image_width = 800,
    max_height = 600,
    show_execution_count = true,
  },

  --- LSP configuration
  lsp = {
    enabled = true,
    prefer_static = true,
    merge_with_kernel = true,
    use_cache = true,
    cache_ttl = 5000,
  },

  --- Notebook configuration
  notebook = {
    auto_detect = true,
    show_outputs = true,
    auto_save = true,
    cell_marker = "#%%",
  },

  --- Notebook UI configuration
  notebook_ui = {
    auto_connect = true,
    show_outputs = true,
    show_status = true,
    show_cell_bar = true,
    cell_marker = "#%%",
    auto_kernel_prompt = true,
    auto_hover = {
      enabled = true,
      delay = 300,
      inspect = true,
    },
    lsp = {
      enabled = true,
      diagnostics = true,
      format_on_save = false,
    },
    code_lens = {
      enabled = true,
      show_execution_count = true,
    },
    images = {
      enabled = true,
      max_width = 800,
      max_height = 600,
      inline = true,
    },
    async = {
      enabled = true,
      parallel = false,
      max_parallel = 4,
      sequential_delay = 10,
    },
    treesitter = {
      enabled = false,
      auto_highlight = true,
      language = "python",
    },
  },

  --- REPL configuration
  repl = {
    cell_marker = "#%%",
    auto_run = false,
    show_outputs = true,
    output_method = "virtual_text",
    async_execution = false,
    parallel_cells = false,
    max_parallel = 4,
  },

  --- Treesitter configuration
  treesitter = {
    enabled = true,
    auto_highlight = true,
    language = "python",
    auto_install_parsers = true,
  },

  --- Cache configuration
  cache = {
    max_size = 100,
    ttl = 30000,
    enabled = true,
  },

  --- Keymaps configuration
  keymaps = {
    enabled = true,
    prefix = "<leader>ur",
    notebook_prefix = "<leader>uj",
    notebook_ui_prefix = "<leader>k",
    lsp_prefix = "<leader>ul",
    kernel_prefix = "<leader>uk",
    disable = {},
  },

  --- Kernel manager configuration
  kernel_manager = {
    auto_install = true,
    default_kernel_name = "python3",
  },
}

--- Current configuration
---@type UranusConfig
local config = nil

--- Get config with lazy initialization
---@return UranusConfig
local function get_config()
  if not config then
    config = vim.deepcopy(defaults)
  end
  return config
end

--- Configuration validation rules
local validators = {
  auto_install_jupyter = "boolean",
  auto_install_parsers = "boolean",
  async_execution = "boolean",
  parallel_cells = "boolean",
  max_parallel = "number",
  output = "table",
  lsp = "table",
  notebook = "table",
  notebook_ui = "table",
  repl = "table",
  treesitter = "table",
  cache = "table",
  keymaps = "table",
  kernel_manager = "table",
}

--- Config change observers (callbacks when specific config changes)
local observers = {}

--- Register a config change observer
---@param key string Config key to watch (e.g., "lsp.enabled")
---@param callback function Function to call when config changes
function M.on_change(key, callback)
  if not observers[key] then
    observers[key] = {}
  end
  table.insert(observers[key], callback)
end

--- Notify observers of a config change
local function notify_observers(key)
  if observers[key] then
    local value = M.get(key)
    for _, callback in ipairs(observers[key]) do
      callback(value)
    end
  end
  local parent = key:match("^([^%.]+)")
  if parent and observers[parent] then
    local value = M.get(parent)
    for _, callback in ipairs(observers[parent]) do
      callback(value)
    end
  end
end

--- Validate a single value
---@param value any
---@param expected_type string
---@return boolean
local function validate_type(value, expected_type)
  if expected_type == "table" then
    return type(value) == "table"
  end
  return type(value) == expected_type
end

--- Validate configuration
---@param user_config UranusConfig?
---@return { success: boolean, error: string? }
function M.validate(user_config)
  if not user_config then
    return { success = true }
  end

  for key, expected_type in pairs(validators) do
    local value = user_config[key]
    if value ~= nil then
      if not validate_type(value, expected_type) then
        return {
          success = false,
          error = string.format(
            "Invalid type for '%s': expected %s, got %s",
            key,
            expected_type,
            type(value)
          ),
        }
      end
    end
  end

  -- Validate nested tables
  if user_config.output and type(user_config.output) ~= "table" then
    return { success = false, error = "Invalid 'output' configuration: must be a table" }
  end

  if user_config.lsp and type(user_config.lsp) ~= "table" then
    return { success = false, error = "Invalid 'lsp' configuration: must be a table" }
  end

  if user_config.treesitter and type(user_config.treesitter) ~= "table" then
    return { success = false, error = "Invalid 'treesitter' configuration: must be a table" }
  end

  if user_config.keymaps and type(user_config.keymaps) ~= "table" then
    return { success = false, error = "Invalid 'keymaps' configuration: must be a table" }
  end

  return { success = true }
end

--- Get configuration
---@return UranusConfig
function M.get_config()
  return get_config()
end

--- Get a specific configuration value
---@param key string
---@return any
function M.get(key)
  local value = get_config()
  for k in key:gmatch("[^%.]+") do
    if type(value) == "table" then
      value = value[k]
    else
      return nil
    end
  end
  return value
end

--- Set configuration
---@param key string
---@param value any
function M.set(key, value)
  local current = config
  local keys = {}
  for k in key:gmatch("[^%.]+") do
    table.insert(keys, k)
  end

  for i = 1, #keys - 1 do
    local k = keys[i]
    if type(current[k]) ~= "table" then
      current[k] = {}
    end
    current = current[k]
  end

  current[keys[#keys]] = value

  notify_observers(key)
end

--- Reset configuration to defaults
function M.reset()
  config = vim.deepcopy(defaults)
end

--- Get default configuration
---@return UranusConfig
function M.defaults()
  return vim.deepcopy(defaults)
end

--- Initialize configuration
---@param user_config UranusConfig?
---@return { success: boolean, error: string? }
function M.init(user_config)
  -- Validate user configuration
  local validation = M.validate(user_config)
  if not validation.success then
    return validation
  end

  -- Merge with defaults
  if user_config then
    config = vim.tbl_deep_extend("force", defaults, user_config)
  end

  return { success = true }
end

return M
