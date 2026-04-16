--- Uranus output rendering module
--- Handles display of execution results including text, errors, and rich content
---
--- @module uranus.output

local M = {}

local config = nil

local function get_config()
  if not config then
    local cfg = require("uranus.config")
    local defaults = cfg.get("output") or {}
    config = vim.deepcopy(defaults)
    config.enable_virtual_text = true
    config.enable_snacks = true
    config.max_output_lines = 1000
    config.virtual_text_prefix = " => "
    config.error_prefix = " => Error: "
    config.batch_delay = 10
  end
  return config
end

local ns_virtual_text = vim.api.nvim_create_namespace("uranus_output_virtual")
local ns_highlight = vim.api.nvim_create_namespace("uranus_output_highlight")

local snacks_ok = false
local pending_batch = nil
local batch_timer = nil

local function setup()
  local ok, _ = pcall(require, "snacks")
  snacks_ok = ok
end

function M.configure(opts)
  local cfg = require("uranus.config")
  local current = cfg.get("output") or {}
  config = vim.tbl_deep_extend("force", current, opts or {})
end

function M.get_config()
  return get_config()
end

local function flush_batch()
  if not pending_batch then return end
  local items = pending_batch
  pending_batch = nil
  for _, item in ipairs(items) do
    local bufnr = item.bufnr or vim.api.nvim_get_current_buf()
    local prefix = item.is_error and config.error_prefix or config.virtual_text_prefix
    local highlight = item.is_error and "UranusError" or "UranusOutput"
    vim.api.nvim_buf_clear_namespace(bufnr, ns_virtual_text, item.line, item.line + 1)
    local virt_text = {{ prefix .. item.output, highlight }}
    vim.api.nvim_buf_set_virtual_text(bufnr, ns_virtual_text, item.line, virt_text, {})
  end
end

function M.display_virtual_text(bufnr, line, output, is_error)
  if not config.enable_virtual_text then
    return
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local output_str = type(output) == "table" and table.concat(output, "\n") or output

  if config.batch_delay > 0 then
    pending_batch = pending_batch or {}
    table.insert(pending_batch, { bufnr = bufnr, line = line, output = output_str, is_error = is_error })
    if not batch_timer then
      batch_timer = vim.defer_fn(function()
        flush_batch()
        batch_timer = nil
      end, config.batch_delay)
    end
    return
  end

  local prefix = is_error and config.error_prefix or config.virtual_text_prefix
  local highlight = is_error and "UranusError" or "UranusOutput"

  vim.api.nvim_buf_clear_namespace(bufnr, ns_virtual_text, line, line + 1)

  local virt_text = {
    { prefix .. output_str, highlight }
  }

  vim.api.nvim_buf_set_virtual_text(bufnr, ns_virtual_text, line, virt_text, {})
end

function M.clear_virtual_text(bufnr, line)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns_virtual_text, line, line + 1)
end

function M.clear_all_virtual_text(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns_virtual_text, 0, -1)
end

function M.flush()
  if batch_timer then
    batch_timer:close()
    batch_timer = nil
  end
  flush_batch()
end

function M.display_snacks(output)
  if not snacks_ok then
    return
  end

  local lines = {}
  local title = string.format("Uranus [%d]", output.execution_count or 0)

  if output.stdout then
    vim.list_extend(lines, vim.split(output.stdout, "\n", { trimempty = true }))
  end

  if output.stderr then
    vim.list_extend(lines, vim.split(output.stderr, "\n", { trimempty = true }))
  end

  if output.error then
    vim.list_extend(lines, { "Error: " .. output.error })
  end

  if output.data and next(output.data) then
    for mime_type, content in pairs(output.data) do
      if mime_type == "text/plain" then
        vim.list_extend(lines, vim.split(content, "\n", { trimempty = true }))
      else
        vim.list_extend(lines, { string.format("[%s: %d bytes]", mime_type, #content) })
      end
    end
  end

  if #lines == 0 then
    lines = { "(no output)" }
  end

  local icon = output.error and "" or "󰞀"
  local ok, snacks = pcall(require, "snacks")
  if ok then
    snacks.notify({
      title = title,
      { icon = icon, line = lines[1] },
      timeout = 3,
    })
  end
end

function M.display_rich_window(data, title)
  title = title or "Uranus Output"

  if data["image/png"] then
    M.display_image(data["image/png"], title)
  elseif data["image/svg+xml"] then
    M.display_svg(data["image/svg+xml"], title)
  elseif data["text/html"] then
    M.display_html(data["text/html"], title)
  end
end

local function make_temp_file(prefix, ext, content)
  local temp_file = prefix .. os.date("%s") .. "." .. ext
  local file = io.open(temp_file, ext == "png" and "wb" or "w")
  if file then
    file:write(content)
    file:close()
    vim.defer_fn(function()
      os.remove(temp_file)
    end, 60000)
    return temp_file
  end
  return nil
end

function M.display_image(base64_data, title)
  title = title or "Uranus Image"
  local image_data = vim.base64_decode(base64_data)
  local temp_file = make_temp_file(vim.fn.stdpath("temp") .. "/uranus_image_", "png", image_data)
  if temp_file then
    local ok, snacks = pcall(require, "snacks")
    if ok then
      snacks.image(temp_file, { title = title })
    else
      vim.notify("Image: " .. temp_file, vim.log.levels.INFO)
    end
  end
end

function M.display_svg(svg_data, title)
  title = title or "Uranus SVG"
  local temp_file = make_temp_file(vim.fn.stdpath("temp") .. "/uranus_image_", "svg", svg_data)
  if temp_file then
    local ok, snacks = pcall(require, "snacks")
    if ok then
      snacks.image(temp_file, { title = title })
    else
      vim.notify("SVG: " .. temp_file, vim.log.levels.INFO)
    end
  end
end

function M.display_html(html_data, title)
  title = title or "Uranus HTML"
  local temp_file = make_temp_file(vim.fn.stdpath("temp") .. "/uranus_html_", "html", html_data)
  if temp_file then
    vim.notify("HTML: " .. temp_file, vim.log.levels.INFO)
  end
end

function M.display(output, opts)
  opts = opts or {}

  local use_virtual_text = opts.virtual_text ~= false and config.enable_virtual_text
  local use_snacks = opts.snacks ~= false and snacks_ok
  local use_rich_window = opts.rich_window ~= false

  if output.error then
    if use_virtual_text then
      M.display_virtual_text(nil, vim.fn.line(".") - 1, output.error, true)
    end
    if use_snacks then
      M.display_snacks(output)
    end
    return
  end

  local output_text = {}

  if output.stdout then
    table.insert(output_text, output.stdout)
  end

  if output.stderr then
    table.insert(output_text, output.stderr)
  end

  if output.data and output.data["text/plain"] then
    table.insert(output_text, output.data["text/plain"])
  end

  if #output_text > 0 then
    if use_virtual_text then
      M.display_virtual_text(nil, vim.fn.line(".") - 1, output_text, false)
    end
  end

  if use_snacks then
    M.display_snacks(output)
  end

  if use_rich_window and output.data then
    local has_rich = false
    for mime, _ in pairs(output.data) do
      if mime ~= "text/plain" then
        has_rich = true
        break
      end
    end

    if has_rich then
      M.display_rich_window(output.data, string.format("Output [%d]", output.execution_count))
    end
  end
end

setup()

return M
