--- Uranus UI module
--- Provides snacks.nvim-based UI components for kernel management and output display
---
--- @module uranus.ui

local M = {}

local config = nil

local function get_config()
  if not config then
    local cfg = require("uranus.config")
    local defaults = cfg.get("output") or {}
    config = vim.deepcopy(defaults)
    config.enable_picker = true
    config.enable_dashboard = true
    config.enable_status = true
    config.theme = "dark"
  end
  return config
end

local ns_ui = vim.api.nvim_create_namespace("uranus_ui")

local function get_snacks()
  local ok, snacks = pcall(require, "snacks")
  if not ok then
    return nil
  end
  return snacks
end

function M.configure(opts)
  local cfg = require("uranus.config")
  local current = cfg.get("output") or {}
  config = vim.tbl_deep_extend("force", current, opts or {})
  config.enable_picker = true
  config.enable_dashboard = true
  config.enable_status = true
end

function M.get_config()
  return get_config()
end

--- Show kernel picker using snacks picker
--- @param kernels table Array of kernel specs
--- @param on_select function Callback when kernel selected
function M.pick_kernel(kernels, on_select)
  local snacks = get_snacks()
  if not snacks or not snacks.picker then
    vim.ui.select(kernels, {
      prompt = "Select Kernel:",
      format_item = function(item)
        return string.format("%s (%s)", item.name, item.language)
      end,
    }, function(choice)
      if choice and on_select then
        on_select(choice)
      end
    end)
    return
  end

  snacks.picker({
    title = "Uranus Kernel Picker",
    items = vim.tbl_map(function(k)
      return {
        id = k.name,
        text = k.name,
        subtext = k.language,
        icon = "󰌔",
      }
    end, kernels),
    ["on-select"] = function(item)
      if item and on_select then
        on_select({ name = item.id, language = item.subtext })
      end
    end,
  })
end

--- Show notification with snacks
--- @param msg string Message
--- @param level string Log level (info, warn, error)
--- @param opts table Additional options
function M.notify(msg, level, opts)
  local snacks = get_snacks()
  level = level or "info"

  if snacks and snacks.notify then
    snacks.notify(msg, {
      title = "Uranus",
      level = level,
    })
  else
    local lvl = vim.log.levels
    local vim_level = level == "error" and lvl.ERROR or level == "warn" and lvl.WARN or lvl.INFO
    vim.notify(msg, vim_level)
  end
end

--- Show progress indicator
--- @param task string Task description
--- @param opts table Options: { completed = number, total = number }
function M.progress(task, opts)
  local snacks = get_snacks()
  opts = opts or {}

  if snacks and snacks.profiler then
    return snacks.profiler.start({
      title = task,
      total = opts.total,
    })
  end

  vim.notify(task, vim.log.levels.INFO)
  return nil
end

--- Create dashboard window
--- @param opts table Options: { title = string, items = table }
function M.dashboard(opts)
  local snacks = get_snacks()
  opts = opts or {}
  opts.items = opts.items or {}

  if snacks and snacks.dashboard then
    snacks.dashboard(opts)
    return
  end

  local lines = { "=== " .. (opts.title or "Uranus Dashboard") .. " ===", "" }
  for _, item in ipairs(opts.items) do
    table.insert(lines, string.format("  %s: %s", item.label or item[1], item.value or item[2] or ""))
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

--- Show status in winbar or statusline
--- @param status table Status info: { kernel, running, cells }
function M.show_status(status)
  local snacks = get_snacks()
  status = status or {}

  local parts = {}
  table.insert(parts, "Uranus")

  if status.backend_running then
    table.insert(parts, "●")
  else
    table.insert(parts, "○")
  end

  if status.current_kernel then
    table.insert(parts, status.current_kernel.name)
  else
    table.insert(parts, "no kernel")
  end

  if status.execution_count then
    table.insert(parts, "[#" .. status.execution_count .. "]")
  end

  local status_str = table.concat(parts, " ")

  if snacks and snacks.statusbar then
    snacks.statusbar.set("uranus", {
      { text = status_str, icon = "󰌔" },
    })
  else
    vim.b.uranus_status = status_str
  end
end

--- Update status bar
function M.update_status()
  local ok, uranus = pcall(require, "uranus")
  if not ok then
    return
  end

  local status = uranus.status()
  M.show_status(status)
end

--- Create floating window for rich output
--- @param opts table Options: { title, content, filetype }
--- @return number|nil Window handle
function M.floating_window(opts)
  local snacks = get_snacks()
  opts = opts or {}
  opts.filetype = opts.filetype or "text"

  if snacks and snacks.float then
    return snacks.float({
      title = opts.title or "Uranus Output",
      buf = opts.buf,
      file = opts.file,
    })
  end

  local width = vim.o.columns * 0.8
  local height = vim.o.lines * 0.8
  local row = (vim.o.lines - height) / 2
  local col = (vim.o.columns - width) / 2

  local buf = opts.buf or vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = math.floor(width),
    height = math.floor(height),
    row = math.floor(row),
    col = math.floor(col),
    style = "minimal",
    border = "rounded",
    title = opts.title or "Uranus",
    title_pos = "center",
  })

  return win
end

--- Show image in floating window
--- @param path string Image path
--- @param opts table Options: { title, width, height }
function M.show_image(path, opts)
  local snacks = get_snacks()
  opts = opts or {}

  if snacks and snacks.image then
    snacks.image(path, {
      title = opts.title or "Uranus Image",
      width = opts.width,
      height = opts.height,
    })
  else
    vim.notify("Image: " .. path, vim.log.levels.INFO)
  end
end

--- Confirm dialog
--- @param msg string Message
--- @param on_confirm function Callback on confirm
--- @param on_cancel function Callback on cancel
function M.confirm(msg, on_confirm, on_cancel)
  local snacks = get_snacks()
  msg = msg or "Continue?"

  if snacks and snacks.input then
    snacks.input({
      prompt = msg,
      kind = "confirm",
    }, function(choice)
      if choice and on_confirm then
        on_confirm()
      elseif on_cancel then
        on_cancel()
      end
    end)
  else
    vim.ui.select({ "Yes", "No" }, {
      prompt = msg,
    }, function(choice)
      if choice == "Yes" and on_confirm then
        on_confirm()
      elseif on_cancel then
        on_cancel()
      end
    end)
  end
end

--- Show debug view
function M.debug_view()
  local ok, uranus = pcall(require, "uranus")
  if not ok then
    return
  end

  local status = uranus.status()
  local debug_info = {
    { label = "Backend", value = status.backend_running and "Running" or "Stopped" },
    { label = "Version", value = status.version },
    { label = "Kernel", value = status.current_kernel and status.current_kernel.name or "None" },
    { label = "Language", value = status.current_kernel and status.current_kernel.language or "N/A" },
  }

  M.dashboard({
    title = "Uranus Debug",
    items = debug_info,
  })
end

return M