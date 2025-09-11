--- Uranus configuration validation and management
---
--- Provides comprehensive configuration validation with helpful error messages
--- and type checking for all Uranus settings.
---
--- @module uranus.config
--- @license MIT

local M = {}

---@class UranusResult<T>
---@field success boolean
---@field data? T
---@field error? UranusError

---@class UranusError
---@field code string
---@field message string
---@field context? table

--- Validate complete Uranus configuration
---@param config UranusConfig Configuration to validate
---@return UranusResult<UranusConfig> Validated configuration or error
function M.validate(config)
  if type(config) ~= "table" then
    return M.err("INVALID_TYPE", "Configuration must be a table", { got = type(config) })
  end

  local result = {}

  -- Validate each section
  local sections = {
    { key = "lsp", validator = M._validate_lsp },
    { key = "ui", validator = M._validate_ui },
    { key = "kernels", validator = M._validate_kernels },
    { key = "remote_servers", validator = M._validate_remote_servers },
    { key = "cell", validator = M._validate_cell },
    { key = "output", validator = M._validate_output },
    { key = "keymaps", validator = M._validate_keymaps },
  }

  for _, section in ipairs(sections) do
    local section_config = config[section.key]
    if section_config ~= nil then
      local section_result = section.validator(section_config)
      if not section_result.success then
        return M.err("CONFIG_" .. section.key:upper(),
          "Invalid " .. section.key .. " configuration: " .. section_result.error,
          section_result.context)
      end
      result[section.key] = section_result.data
    end
  end

  -- Validate scalar options
  if config.debug ~= nil then
    if type(config.debug) ~= "boolean" then
      return M.err("INVALID_DEBUG", "debug must be boolean", { got = type(config.debug) })
    end
    result.debug = config.debug
  end

  if config.log_level ~= nil then
    local valid_levels = { "DEBUG", "INFO", "WARN", "ERROR" }
    if not vim.tbl_contains(valid_levels, config.log_level) then
      return M.err("INVALID_LOG_LEVEL", "log_level must be one of: " .. table.concat(valid_levels, ", "),
        { got = config.log_level, valid = valid_levels })
    end
    result.log_level = config.log_level
  end

  return M.ok(result)
end

--- Validate LSP configuration
---@param config UranusLspConfig LSP configuration
---@return UranusResult<UranusLspConfig>
function M._validate_lsp(config)
  if type(config) ~= "table" then
    return M.err("INVALID_TYPE", "lsp config must be a table", { got = type(config) })
  end

  local result = {}

  -- enable
  if config.enable ~= nil then
    if type(config.enable) ~= "boolean" then
      return M.err("INVALID_ENABLE", "lsp.enable must be boolean", { got = type(config.enable) })
    end
    result.enable = config.enable
  end

  -- server
  if config.server ~= nil then
    local valid_servers = { "pyright", "pylsp", "jedi", "ruff" }
    if not vim.tbl_contains(valid_servers, config.server) then
      return M.err("INVALID_SERVER", "lsp.server must be one of: " .. table.concat(valid_servers, ", "),
        { got = config.server, valid = valid_servers })
    end
    result.server = config.server
  end

  -- auto_attach
  if config.auto_attach ~= nil then
    if type(config.auto_attach) ~= "boolean" then
      return M.err("INVALID_AUTO_ATTACH", "lsp.auto_attach must be boolean", { got = type(config.auto_attach) })
    end
    result.auto_attach = config.auto_attach
  end

  -- diagnostics
  if config.diagnostics ~= nil then
    if type(config.diagnostics) ~= "boolean" then
      return M.err("INVALID_DIAGNOSTICS", "lsp.diagnostics must be boolean", { got = type(config.diagnostics) })
    end
    result.diagnostics = config.diagnostics
  end

  return M.ok(result)
end

--- Validate UI configuration
---@param config UranusUIConfig UI configuration
---@return UranusResult<UranusUIConfig>
function M._validate_ui(config)
  if type(config) ~= "table" then
    return M.err("INVALID_TYPE", "ui config must be a table", { got = type(config) })
  end

  local result = {}

  -- mode
  if config.mode ~= nil then
    local valid_modes = { "repl", "notebook", "both" }
    if not vim.tbl_contains(valid_modes, config.mode) then
      return M.err("INVALID_MODE", "ui.mode must be one of: " .. table.concat(valid_modes, ", "),
        { got = config.mode, valid = valid_modes })
    end
    result.mode = config.mode
  end

  -- repl
  if config.repl ~= nil then
    local repl_result = M._validate_repl_ui(config.repl)
    if not repl_result.success then
      return repl_result
    end
    result.repl = repl_result.data
  end

  -- image
  if config.image ~= nil then
    local image_result = M._validate_image_ui(config.image)
    if not image_result.success then
      return image_result
    end
    result.image = image_result.data
  end

  -- markdown_renderer
  if config.markdown_renderer ~= nil then
    local valid_renderers = { "markview", "render-markdown" }
    if not vim.tbl_contains(valid_renderers, config.markdown_renderer) then
      return M.err("INVALID_RENDERER", "ui.markdown_renderer must be one of: " .. table.concat(valid_renderers, ", "),
        { got = config.markdown_renderer, valid = valid_renderers })
    end
    result.markdown_renderer = config.markdown_renderer
  end

  return M.ok(result)
end

--- Validate REPL UI configuration
---@param config UranusReplUIConfig REPL UI configuration
---@return UranusResult<UranusReplUIConfig>
function M._validate_repl_ui(config)
  if type(config) ~= "table" then
    return M.err("INVALID_TYPE", "ui.repl config must be a table", { got = type(config) })
  end

  local result = {}

  -- view
  if config.view ~= nil then
    local valid_views = { "floating", "virtualtext", "terminal" }
    if not vim.tbl_contains(valid_views, config.view) then
      return M.err("INVALID_VIEW", "ui.repl.view must be one of: " .. table.concat(valid_views, ", "),
        { got = config.view, valid = valid_views })
    end
    result.view = config.view
  end

  -- max_height
  if config.max_height ~= nil then
    if type(config.max_height) ~= "number" or config.max_height <= 0 then
      return M.err("INVALID_MAX_HEIGHT", "ui.repl.max_height must be a positive number",
        { got = config.max_height })
    end
    result.max_height = config.max_height
  end

  -- max_width
  if config.max_width ~= nil then
    if type(config.max_width) ~= "number" or config.max_width <= 0 then
      return M.err("INVALID_MAX_WIDTH", "ui.repl.max_width must be a positive number",
        { got = config.max_width })
    end
    result.max_width = config.max_width
  end

  return M.ok(result)
end

--- Validate image UI configuration
---@param config UranusImageUIConfig Image UI configuration
---@return UranusResult<UranusImageUIConfig>
function M._validate_image_ui(config)
  if type(config) ~= "table" then
    return M.err("INVALID_TYPE", "ui.image config must be a table", { got = type(config) })
  end

  local result = {}

  -- backend
  if config.backend ~= nil then
    local valid_backends = { "snacks", "image.nvim" }
    if not vim.tbl_contains(valid_backends, config.backend) then
      return M.err("INVALID_BACKEND", "ui.image.backend must be one of: " .. table.concat(valid_backends, ", "),
        { got = config.backend, valid = valid_backends })
    end
    result.backend = config.backend
  end

  -- max_width
  if config.max_width ~= nil then
    if type(config.max_width) ~= "number" or config.max_width <= 0 then
      return M.err("INVALID_MAX_WIDTH", "ui.image.max_width must be a positive number",
        { got = config.max_width })
    end
    result.max_width = config.max_width
  end

  -- max_height
  if config.max_height ~= nil then
    if type(config.max_height) ~= "number" or config.max_height <= 0 then
      return M.err("INVALID_MAX_HEIGHT", "ui.image.max_height must be a positive number",
        { got = config.max_height })
    end
    result.max_height = config.max_height
  end

  return M.ok(result)
end

--- Validate kernel configuration
---@param config UranusKernelConfig Kernel configuration
---@return UranusResult<UranusKernelConfig>
function M._validate_kernels(config)
  if type(config) ~= "table" then
    return M.err("INVALID_TYPE", "kernels config must be a table", { got = type(config) })
  end

  local result = {}

  -- auto_start
  if config.auto_start ~= nil then
    if type(config.auto_start) ~= "boolean" then
      return M.err("INVALID_AUTO_START", "kernels.auto_start must be boolean", { got = type(config.auto_start) })
    end
    result.auto_start = config.auto_start
  end

  -- default
  if config.default ~= nil then
    if type(config.default) ~= "string" or config.default == "" then
      return M.err("INVALID_DEFAULT", "kernels.default must be a non-empty string", { got = config.default })
    end
    result.default = config.default
  end

  -- timeout
  if config.timeout ~= nil then
    if type(config.timeout) ~= "number" or config.timeout <= 0 then
      return M.err("INVALID_TIMEOUT", "kernels.timeout must be a positive number", { got = config.timeout })
    end
    result.timeout = config.timeout
  end

  -- discovery_paths
  if config.discovery_paths ~= nil then
    if type(config.discovery_paths) ~= "table" then
      return M.err("INVALID_DISCOVERY_PATHS", "kernels.discovery_paths must be a table",
        { got = type(config.discovery_paths) })
    end

    for i, path in ipairs(config.discovery_paths) do
      if type(path) ~= "string" then
        return M.err("INVALID_DISCOVERY_PATH", "kernels.discovery_paths[" .. i .. "] must be a string",
          { got = type(path), index = i })
      end
    end

    result.discovery_paths = config.discovery_paths
  end

  return M.ok(result)
end

--- Validate remote servers configuration
---@param servers UranusRemoteServer[] Remote servers configuration
---@return UranusResult<UranusRemoteServer[]>
function M._validate_remote_servers(servers)
  if type(servers) ~= "table" then
    return M.err("INVALID_TYPE", "remote_servers must be a table", { got = type(servers) })
  end

  local result = {}

  for i, server in ipairs(servers) do
    local server_result = M._validate_remote_server(server, i)
    if not server_result.success then
      return server_result
    end
    table.insert(result, server_result.data)
  end

  return M.ok(result)
end

--- Validate single remote server configuration
---@param server UranusRemoteServer Remote server configuration
---@param index number Server index for error reporting
---@return UranusResult<UranusRemoteServer>
function M._validate_remote_server(server, index)
  if type(server) ~= "table" then
    return M.err("INVALID_SERVER_TYPE", "remote_servers[" .. index .. "] must be a table",
      { got = type(server), index = index })
  end

  local result = {}

  -- name
  if type(server.name) ~= "string" or server.name == "" then
    return M.err("INVALID_SERVER_NAME", "remote_servers[" .. index .. "].name must be a non-empty string",
      { got = server.name, index = index })
  end
  result.name = server.name

  -- url
  if type(server.url) ~= "string" or server.url == "" then
    return M.err("INVALID_SERVER_URL", "remote_servers[" .. index .. "].url must be a non-empty string",
      { got = server.url, index = index })
  end

  -- Basic URL validation
  if not server.url:match("^https?://") then
    return M.err("INVALID_SERVER_URL", "remote_servers[" .. index .. "].url must start with http:// or https://",
      { got = server.url, index = index })
  end

  result.url = server.url

  -- token
  if type(server.token) ~= "string" or server.token == "" then
    return M.err("INVALID_SERVER_TOKEN", "remote_servers[" .. index .. "].token must be a non-empty string",
      { got = server.token, index = index })
  end
  result.token = server.token

  -- headers (optional)
  if server.headers ~= nil then
    if type(server.headers) ~= "table" then
      return M.err("INVALID_SERVER_HEADERS", "remote_servers[" .. index .. "].headers must be a table",
        { got = type(server.headers), index = index })
    end
    result.headers = server.headers
  end

  return M.ok(result)
end

--- Validate cell configuration
---@param config UranusCellConfig Cell configuration
---@return UranusResult<UranusCellConfig>
function M._validate_cell(config)
  if type(config) ~= "table" then
    return M.err("INVALID_TYPE", "cell config must be a table", { got = type(config) })
  end

  local result = {}

  -- marker
  if config.marker ~= nil then
    if type(config.marker) ~= "string" or config.marker == "" then
      return M.err("INVALID_MARKER", "cell.marker must be a non-empty string", { got = config.marker })
    end
    result.marker = config.marker
  end

  -- auto_execute
  if config.auto_execute ~= nil then
    if type(config.auto_execute) ~= "boolean" then
      return M.err("INVALID_AUTO_EXECUTE", "cell.auto_execute must be boolean", { got = type(config.auto_execute) })
    end
    result.auto_execute = config.auto_execute
  end

  -- highlight
  if config.highlight ~= nil then
    if type(config.highlight) ~= "boolean" then
      return M.err("INVALID_HIGHLIGHT", "cell.highlight must be boolean", { got = type(config.highlight) })
    end
    result.highlight = config.highlight
  end

  return M.ok(result)
end

--- Validate output configuration
---@param config UranusOutputConfig Output configuration
---@return UranusResult<UranusOutputConfig>
function M._validate_output(config)
  if type(config) ~= "table" then
    return M.err("INVALID_TYPE", "output config must be a table", { got = type(config) })
  end

  local result = {}

  -- max_lines
  if config.max_lines ~= nil then
    if type(config.max_lines) ~= "number" or config.max_lines <= 0 then
      return M.err("INVALID_MAX_LINES", "output.max_lines must be a positive number", { got = config.max_lines })
    end
    result.max_lines = config.max_lines
  end

  -- image_dir
  if config.image_dir ~= nil then
    if type(config.image_dir) ~= "string" or config.image_dir == "" then
      return M.err("INVALID_IMAGE_DIR", "output.image_dir must be a non-empty string", { got = config.image_dir })
    end
    result.image_dir = config.image_dir
  end

  -- cleanup_temp
  if config.cleanup_temp ~= nil then
    if type(config.cleanup_temp) ~= "boolean" then
      return M.err("INVALID_CLEANUP_TEMP", "output.cleanup_temp must be boolean", { got = type(config.cleanup_temp) })
    end
    result.cleanup_temp = config.cleanup_temp
  end

  -- cleanup_interval
  if config.cleanup_interval ~= nil then
    if type(config.cleanup_interval) ~= "number" or config.cleanup_interval <= 0 then
      return M.err("INVALID_CLEANUP_INTERVAL", "output.cleanup_interval must be a positive number",
        { got = config.cleanup_interval })
    end
    result.cleanup_interval = config.cleanup_interval
  end

  return M.ok(result)
end

--- Validate keymap configuration
---@param config UranusKeymapConfig Keymap configuration
---@return UranusResult<UranusKeymapConfig>
function M._validate_keymaps(config)
  if type(config) ~= "table" then
    return M.err("INVALID_TYPE", "keymaps config must be a table", { got = type(config) })
  end

  local result = {}

  -- enable
  if config.enable ~= nil then
    if type(config.enable) ~= "boolean" then
      return M.err("INVALID_ENABLE", "keymaps.enable must be boolean", { got = type(config.enable) })
    end
    result.enable = config.enable
  end

  -- prefix
  if config.prefix ~= nil then
    if type(config.prefix) ~= "string" then
      return M.err("INVALID_PREFIX", "keymaps.prefix must be a string", { got = config.prefix })
    end
    result.prefix = config.prefix
  end

  -- mappings
  if config.mappings ~= nil then
    if type(config.mappings) ~= "table" then
      return M.err("INVALID_MAPPINGS", "keymaps.mappings must be a table", { got = type(config.mappings) })
    end

    local valid_mappings = {
      "run_cell", "run_all", "run_selection",
      "next_cell", "prev_cell", "kernel_select", "notebook_toggle"
    }

    for key, value in pairs(config.mappings) do
      if not vim.tbl_contains(valid_mappings, key) then
        return M.err("INVALID_MAPPING_KEY", "keymaps.mappings contains invalid key: " .. key,
          { got = key, valid = valid_mappings })
      end

      if type(value) ~= "string" then
        return M.err("INVALID_MAPPING_VALUE", "keymaps.mappings." .. key .. " must be a string",
          { got = type(value), key = key })
      end
    end

    result.mappings = config.mappings
  end

  return M.ok(result)
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