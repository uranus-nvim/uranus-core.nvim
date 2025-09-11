--- Uranus output rendering and formatting
---
--- Handles rich output display including text, images, HTML, Markdown,
--- tables, and other MIME types from Jupyter kernels.
---
--- @module uranus.output
--- @license MIT

local M = {}

---@class UranusDisplayData
---@field mime_type string MIME type (e.g., "text/plain", "image/png")
---@field data string|table Display data content
---@field metadata? table Additional metadata

---@class UranusExecutionResult
---@field success boolean Execution success
---@field stdout? string Standard output
---@field stderr? string Standard error
---@field display_data? UranusDisplayData[] Rich display data
---@field execution_count number Execution count

--- Module state
---@type table<string, fun(data: UranusDisplayData): string>
M.formatters = {}

---@type table<string, fun(data: UranusDisplayData): UranusResult>
M.renderers = {}

--- Initialize output handling
---@param config UranusConfig Uranus configuration
---@return UranusResult
function M.init(config)
  M.config = config

  -- Register built-in formatters
  M._register_formatters()

  -- Register built-in renderers
  M._register_renderers()

  -- Set up output directory
  M._setup_output_directory()

  return M.ok(true)
end

--- Handle execution result from backend
---@param result UranusExecutionResult Execution result
---@return UranusResult
function M.handle_result(result)
  -- Display stdout
  if result.stdout and result.stdout ~= "" then
    M.display_text(result.stdout, "stdout")
  end

  -- Display stderr
  if result.stderr and result.stderr ~= "" then
    M.display_text(result.stderr, "stderr")
  end

  -- Display rich output
  if result.display_data then
    for _, display_data in ipairs(result.display_data) do
      M.display_rich_output(display_data)
    end
  end

  return M.ok(true)
end

--- Display plain text output
---@param text string Text to display
---@param type? string Output type ("stdout", "stderr", "result")
---@return UranusResult
function M.display_text(text, type)
  type = type or "result"

  -- Format text based on type
  local formatted_text = M._format_text(text, type)

  -- Display using configured UI
  local ui = require("uranus.ui")
  return ui.display(formatted_text, {
    mode = M.config.ui.repl.view,
    title = type:sub(1,1):upper() .. type:sub(2) .. " Output",
  })
end

--- Display rich output data
---@param display_data UranusDisplayData Rich display data
---@return UranusResult
function M.display_rich_output(display_data)
  local mime_type = display_data.mime_type

  -- Try renderer first (for interactive content)
  local renderer = M.renderers[mime_type]
  if renderer then
    local result = renderer(display_data)
    if result.success then
      return result
    end
  end

  -- Fall back to formatter (for text-based display)
  local formatter = M.formatters[mime_type]
  if formatter then
    local formatted = formatter(display_data)
    return M.display_text(formatted, "rich")
  end

  -- Generic fallback
  return M.display_text(vim.inspect(display_data), "unknown")
end

--- Format execution result for display
---@param result UranusExecutionResult Execution result
---@return string|nil Formatted content or nil if no output
function M.format_result(result)
  local parts = {}

  -- Add stdout
  if result.stdout and result.stdout ~= "" then
    table.insert(parts, "📤 Output:\n" .. result.stdout)
  end

  -- Add stderr
  if result.stderr and result.stderr ~= "" then
    table.insert(parts, "⚠️  Error:\n" .. result.stderr)
  end

  -- Add rich output
  if result.display_data then
    for _, display_data in ipairs(result.display_data) do
      local formatted = M._format_display_data(display_data)
      if formatted then
        table.insert(parts, formatted)
      end
    end
  end

  if #parts > 0 then
    return table.concat(parts, "\n\n")
  end

  return nil
end

--- Format display data for text display
---@param display_data UranusDisplayData Display data
---@return string|nil Formatted content or nil
function M._format_display_data(display_data)
  local mime_type = display_data.mime_type
  local formatter = M.formatters[mime_type]

  if formatter then
    return formatter(display_data)
  end

  return nil
end

--- Format text with type-specific styling
---@param text string Text content
---@param type string Output type
---@return string Formatted text
function M._format_text(text, type)
  local prefix = ""

  if type == "stdout" then
    prefix = "📤 "
  elseif type == "stderr" then
    prefix = "⚠️  "
  elseif type == "error" then
    prefix = "❌ "
  elseif type == "success" then
    prefix = "✅ "
  end

  return prefix .. text
end

--- Register built-in formatters
function M._register_formatters()
  -- Text formatters
  M.formatters["text/plain"] = function(data)
    return tostring(data.data)
  end

  M.formatters["text/html"] = function(data)
    return "🌐 HTML Output:\n" .. tostring(data.data)
  end

  M.formatters["text/markdown"] = function(data)
    return "📝 Markdown Output:\n" .. tostring(data.data)
  end

  M.formatters["text/latex"] = function(data)
    return "📊 LaTeX Output:\n" .. tostring(data.data)
  end

  -- Image formatters
  M.formatters["image/png"] = function(data)
    return "🖼️  PNG Image (" .. M._get_data_size(data.data) .. " bytes)"
  end

  M.formatters["image/jpeg"] = function(data)
    return "🖼️  JPEG Image (" .. M._get_data_size(data.data) .. " bytes)"
  end

  M.formatters["image/svg+xml"] = function(data)
    return "🖼️  SVG Image (" .. M._get_data_size(data.data) .. " bytes)"
  end

  -- Data formatters
  M.formatters["application/json"] = function(data)
    local ok, parsed = pcall(vim.json.decode, data.data)
    if ok then
      return "📋 JSON:\n" .. vim.inspect(parsed)
    else
      return "📋 JSON (invalid):\n" .. tostring(data.data)
    end
  end

  M.formatters["application/javascript"] = function(data)
    return "📜 JavaScript:\n" .. tostring(data.data)
  end

  -- Table formatter
  M.formatters["application/vnd.dataresource+json"] = function(data)
    return M._format_table(data.data)
  end
end

--- Register built-in renderers
function M._register_renderers()
  -- Image renderers
  M.renderers["image/png"] = function(data)
    return M._render_image(data, "png")
  end

  M.renderers["image/jpeg"] = function(data)
    return M._render_image(data, "jpeg")
  end

  M.renderers["image/svg+xml"] = function(data)
    return M._render_image(data, "svg")
  end

  -- HTML renderer
  M.renderers["text/html"] = function(data)
    return M._render_html(data)
  end

  -- Markdown renderer
  M.renderers["text/markdown"] = function(data)
    return M._render_markdown(data)
  end
end

--- Render image using configured backend
---@param display_data UranusDisplayData Image display data
---@param format string Image format
---@return UranusResult
function M._render_image(display_data, format)
  local image_backend = M.config.ui.image.backend

  if image_backend == "snacks" then
    return M._render_image_snacks(display_data, format)
  elseif image_backend == "image.nvim" then
    return M._render_image_image_nvim(display_data, format)
  else
    -- Fallback to text description
    local formatter = M.formatters["image/" .. format]
    if formatter then
      local description = formatter(display_data)
      local ui = require("uranus.ui")
      return ui.display(description, {
        mode = "floating",
        title = "Image Output",
      })
    end
  end

  return M.err("UNSUPPORTED_BACKEND", "Unsupported image backend: " .. image_backend)
end

--- Render image using snacks.nvim
---@param display_data UranusDisplayData Image display data
---@param format string Image format
---@return UranusResult
function M._render_image_snacks(display_data, format)
  local ok, snacks = pcall(require, "snacks")
  if not ok then
    return M.err("BACKEND_NOT_FOUND", "snacks.nvim not found")
  end

  -- Save image to temporary file
  local temp_file = M._save_image_temp(display_data.data, format)
  if not temp_file then
    return M.err("TEMP_FILE_FAILED", "Failed to create temporary image file")
  end

  -- Display image
  local result = snacks.image.open(temp_file, {
    on_close = function()
      -- Clean up temp file
      if M.config.output.cleanup_temp then
        os.remove(temp_file)
      end
    end,
  })

  return M.ok(result)
end

--- Render image using image.nvim
---@param display_data UranusDisplayData Image display data
---@param format string Image format
---@return UranusResult
function M._render_image_image_nvim(display_data, format)
  local ok, image = pcall(require, "image")
  if not ok then
    return M.err("BACKEND_NOT_FOUND", "image.nvim not found")
  end

  -- Save image to temporary file
  local temp_file = M._save_image_temp(display_data.data, format)
  if not temp_file then
    return M.err("TEMP_FILE_FAILED", "Failed to create temporary image file")
  end

  -- Display image
  local img = image.from_file(temp_file, {
    width = M.config.ui.image.max_width,
    height = M.config.ui.image.max_height,
  })

  if img then
    img:render()
    return M.ok(img)
  else
    return M.err("RENDER_FAILED", "Failed to render image")
  end
end

--- Render HTML content
---@param display_data UranusDisplayData HTML display data
---@return UranusResult
function M._render_html(display_data)
  local html_content = tostring(display_data.data)

  -- For now, display as formatted text
  -- TODO: Integrate with browser or HTML renderer
  local ui = require("uranus.ui")
  return ui.display("🌐 HTML Content:\n" .. html_content, {
    mode = "floating",
    title = "HTML Output",
  })
end

--- Render Markdown content
---@param display_data UranusDisplayData Markdown display data
---@return UranusResult
function M._render_markdown(display_data)
  local markdown_content = tostring(display_data.data)

  -- Use configured markdown renderer
  local renderer = M.config.ui.markdown_renderer

  if renderer == "markview" then
    return M._render_markdown_markview(markdown_content)
  elseif renderer == "render-markdown" then
    return M._render_markdown_render_markdown(markdown_content)
  else
    -- Fallback to plain text
    local ui = require("uranus.ui")
    return ui.display("📝 Markdown:\n" .. markdown_content, {
      mode = "floating",
      title = "Markdown Output",
    })
  end
end

--- Render markdown using markview
---@param content string Markdown content
---@return UranusResult
function M._render_markdown_markview(content)
  local ok, markview = pcall(require, "markview")
  if not ok then
    return M.err("BACKEND_NOT_FOUND", "markview not found")
  end

  -- Create temporary buffer with markdown content
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))

  -- Render with markview
  markview.render(buf)

  -- Display in floating window
  local ui = require("uranus.ui")
  return ui.display("", {
    mode = "floating",
    title = "Markdown Output",
    buf = buf,
  })
end

--- Render markdown using render-markdown
---@param content string Markdown content
---@return UranusResult
function M._render_markdown_render_markdown(content)
  local ok, render_md = pcall(require, "render-markdown")
  if not ok then
    return M.err("BACKEND_NOT_FOUND", "render-markdown not found")
  end

  -- Create temporary buffer with markdown content
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))

  -- Render with render-markdown
  render_md.render(buf)

  -- Display in floating window
  local ui = require("uranus.ui")
  return ui.display("", {
    mode = "floating",
    title = "Markdown Output",
    buf = buf,
  })
end

--- Format table data
---@param data table Table data
---@return string Formatted table
function M._format_table(data)
  if type(data) ~= "table" then
    return "📋 Invalid table data"
  end

  -- Simple table formatting
  -- TODO: Implement proper table rendering
  return "📋 Table:\n" .. vim.inspect(data)
end

--- Save image data to temporary file
---@param data string Base64 encoded image data
---@param format string Image format
---@return string|nil Temporary file path or nil on failure
function M._save_image_temp(data, format)
  -- Decode base64 data
  local ok, decoded = pcall(vim.base64.decode, data)
  if not ok then
    return nil
  end

  -- Create temporary file
  local temp_file = vim.fn.tempname() .. "." .. format
  local file = io.open(temp_file, "wb")
  if not file then
    return nil
  end

  file:write(decoded)
  file:close()

  return temp_file
end

--- Get data size in human readable format
---@param data string Data to measure
---@return string Human readable size
function M._get_data_size(data)
  local size = #data
  if size < 1024 then
    return size .. " B"
  elseif size < 1024 * 1024 then
    return string.format("%.1f KB", size / 1024)
  else
    return string.format("%.1f MB", size / (1024 * 1024))
  end
end

--- Set up output directory
function M._setup_output_directory()
  local output_dir = M.config.output.image_dir

  -- Create directory if it doesn't exist
  if vim.fn.isdirectory(output_dir) == 0 then
    vim.fn.mkdir(output_dir, "p")
  end
end

--- Clean up temporary files
---@return UranusResult
function M.cleanup_temp_files()
  -- Clean up image directory
  local output_dir = M.config.output.image_dir
  local cleanup_age = M.config.output.cleanup_interval

  if vim.fn.isdirectory(output_dir) == 1 then
    -- Get all files in directory
    local files = vim.fn.glob(output_dir .. "/*", false, true)

    for _, file in ipairs(files) do
      -- Check file age
      local stat = vim.loop.fs_stat(file)
      if stat then
        local age = os.time() - stat.mtime.sec
        if age > cleanup_age / 1000 then
          os.remove(file)
        end
      end
    end
  end

  return M.ok(true)
end

--- Get output statistics
---@return table Output statistics
function M.stats()
  return {
    registered_formatters = vim.tbl_count(M.formatters),
    registered_renderers = vim.tbl_count(M.renderers),
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