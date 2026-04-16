local M = {}

local config = nil

local function get_config()
  if not config then
    local cfg = require("uranus.config")
    config = {
      show_types = true,
      show_values = true,
      max_depth = 3,
      max_value_length = 100,
      merge_lsp = true,
    }
  end
  return config
end

local ns_inspector = vim.api.nvim_create_namespace("uranus_inspector")

local variables_cache = {}
local variables_cache_time = 0
local variables_cache_ttl = 5000

local hover_debounce_timer = nil
local hover_debounce_delay = 300

local function get_uranus()
  local ok, uranus = pcall(require, "uranus")
  return ok and uranus or nil
end

local function get_lsp()
  local ok, lsp = pcall(require, "uranus.lsp")
  return ok and lsp or nil
end

function M.configure(opts)
  config = vim.tbl_deep_extend("force", get_config(), opts or {})
end

function M.get_config()
  return get_config()
end

function M.inspect_at_cursor()
  local word = vim.fn.expand("<cword>")
  if #word == 0 then
    return nil
  end

  local lsp = get_lsp()
  if lsp and config.merge_lsp then
    return lsp.hover(word)
  end

  local u = get_uranus()
  if u then
    -- Get cursor position for better inspection
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1]
    local col = cursor[2]
    local result = u.inspect(word, col)
    if result.success and result.data then
      return result.data
    end
  end
   
  return nil
end

function M.show_hover(var_info)
  local lsp = get_lsp()
  if lsp and config.merge_lsp then
    lsp.show_hover_enhanced(var_info.name or vim.fn.expand("<cword>"))
    return
  end

  if not var_info or not var_info.name then
    return
  end

  local lines = {}
  table.insert(lines, "📌 " .. (var_info.name or "unknown"))

  if var_info.type_name and #var_info.type_name > 0 then
    table.insert(lines, "Type: " .. var_info.type_name)
  end

  if var_info.value then
    local value = var_info.value
    if #value > config.max_value_length then
      value = value:sub(1, config.max_value_length) .. "..."
    end
    table.insert(lines, "Value: " .. value)
  end

  if var_info.docstring then
    local doc = var_info.docstring
    if #doc > 500 then
      doc = doc:sub(1, 500) .. "..."
    end
    table.insert(lines, "")
    table.insert(lines, doc)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = math.min(vim.o.columns - 10, 60)
  local height = math.min(#lines + 2, 20)
  local row = vim.fn.win_screenpos(0)[1]
  local col = vim.fn.win_screenpos(0)[2] + vim.fn.getcurpos()[2]

  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = "Variable Inspector",
    title_pos = "center",
  })
end

function M.get_variables()
  local now = vim.loop.now()
  if now - variables_cache_time < variables_cache_ttl and #variables_cache > 0 then
    return variables_cache
  end
  
  local lsp = get_lsp()
  if lsp and config.merge_lsp then
    local completions = lsp.get_lsp_completions()
    local vars = {}
    for _, item in ipairs(completions) do
      if item.kind == 6 or item.kind == 5 then
        table.insert(vars, {
          name = item.label,
          type_name = item.detail or "",
        })
      end
    end
    variables_cache = vars
    variables_cache_time = now
    return vars
  end

  local u = get_uranus()
  if not u then
    return {}
  end

  local code = "__uranus_vars = [locals() for _ in [1]]; print(__uranus_vars)"
  local result = u.execute(code)

  if result.success and result.data and result.data.stdout then
    local vars = {}
    local output = result.data.stdout
    for var in output:gmatch("[%w_]+") do
      if var ~= "__uranus_vars" and var ~= "locals" and var ~= "print" then
        local inspect_result = u.inspect(var, 0)
        if inspect_result.success and inspect_result.data then
          table.insert(vars, inspect_result.data)
        end
      end
    end
    variables_cache = vars
    variables_cache_time = now
    return vars
  end

  return {}
end

function M.invalidate_variables_cache()
  variables_cache = {}
  variables_cache_time = 0
end

function M.open_inspector()
  local lsp = get_lsp()
  if lsp and config.merge_lsp then
    local status = lsp.status()
    if status.running then
      vim.notify("LSP connected: " .. status.clients[1].name, vim.log.levels.INFO)
    end
  end

  local u = get_uranus()
  if not u then
    vim.notify("Uranus not available", vim.log.levels.ERROR)
    return
  end

  local code = "import json; vars = {k: type(v).__name__ + ': ' + repr(v) for k, v in globals().items() if not k.startswith('_')}; print(json.dumps(vars))"
  local result = u.execute(code)

  local lines = { "=== Variable Inspector ===", "" }

  if result.success and result.data and result.data.stdout then
    local ok, vars = pcall(vim.json.decode, result.data.stdout)
    if ok and vars then
      for name, info in pairs(vars) do
        table.insert(lines, string.format("  %s: %s", name, info))
      end
    end
  else
    table.insert(lines, "  No variables found")
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = vim.o.columns - 20
  local height = vim.o.lines - 10

  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = 5,
    col = 10,
    style = "minimal",
    border = "rounded",
    title = "Uranus Variable Inspector",
    title_pos = "center",
  })

  vim.wo[0].wrap = true
end

function M.close_inspector()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match("Uranus Variable Inspector") then
      vim.api.nvim_win_close(win, true)
    end
  end
end

function M.toggle_inspector()
  local visible = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match("Uranus Variable Inspector") then
      visible = true
      break
    end
  end

  if visible then
    M.close_inspector()
  else
    M.open_inspector()
  end
end

return M