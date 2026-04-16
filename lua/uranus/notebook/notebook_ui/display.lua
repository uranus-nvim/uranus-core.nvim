--- Uranus Notebook UI - Display and rendering
---
--- @module uranus.notebook.notebook_ui.display

local M = {}

local hover_timer = nil

local function get_init()
  local ok, init = pcall(require, "uranus.notebook.notebook_ui.init")
  return ok and init or nil
end

local function get_lsp()
  local ok, lsp = pcall(require, "uranus.lsp")
  return ok and lsp or nil
end

local function get_uranus()
  local ok, uranus = pcall(require, "uranus")
  return ok and uranus or nil
end

function M.render_code_lens(idx, cell, config)
  if cell.cell_type ~= "code" then
    return
  end

  local exec_count = cell.execution_count
  if not exec_count or type(exec_count) ~= "number" then
    return
  end

  local init = get_init()
  if not init then
    return
  end

  local ns = init.get_ns()
  local line = cell.start or 0
  local text = (" [In %d]"):format(exec_count)

  vim.api.nvim_buf_set_extmark(init.get_state().bufnr, ns.codelens, line, 0, {
    virt_text = { { text, config.highlights.code_lens } },
    virt_text_pos = "eol",
  })
end

function M.render_lsp_diagnostics()
  local init = get_init()
  if not init then
    return
  end

  local config = init.get_config()
  if not config.lsp.enabled or not config.lsp.diagnostics then
    return
  end

  local lsp = get_lsp()
  if not lsp or not lsp.is_available() then
    return
  end

  local buffer_diagnostics = lsp.get_diagnostics()
  if not buffer_diagnostics or #buffer_diagnostics == 0 then
    return
  end

  local state = init.get_state()
  local cells = state.cells
  local cell_ranges = {}

  for i, cell in ipairs(cells) do
    local start = cell.start or 0
    local stop = cell.stop or start
    cell_ranges[i] = { start = start, stop = stop }
  end

  for _, diag in ipairs(buffer_diagnostics) do
    local line = diag.range.start.line
    for i, range in ipairs(cell_ranges) do
      if line >= range.start and line <= range.stop then
        local cell = cells[i]
        cell._has_diagnostic = true
        cell._diagnostic_count = (cell._diagnostic_count or 0) + 1
        break
      end
    end
  end

  for i, cell in ipairs(cells) do
    if cell._has_diagnostic then
      local count = cell._diagnostic_count
      local line = cell.start or 0
      local hint = (" [%d diagnostic%s]"):format(count, count == 1 and "" or "s")

      vim.api.nvim_buf_set_extmark(state.bufnr, init.get_ns().codelens, line + 1, 0, {
        virt_text = { { hint, "DiagnosticError" } },
        virt_text_pos = "eol",
      })

      cell._has_diagnostic = nil
      cell._diagnostic_count = nil
    end
  end
end

function M.show_hover_at_cursor()
  local init = get_init()
  if not init then
    return
  end

  local config = init.get_config()
  if not config.auto_hover.enabled then
    return
  end

  if hover_timer then
    hover_timer:close()
  end

  hover_timer = vim.defer_fn(function()
    M.do_hover_at_cursor()
  end, config.auto_hover.delay)
end

function M.do_hover_at_cursor()
  local word = vim.fn.expand("<cword>")
  if #word == 0 then
    return
  end

  local init = get_init()
  if not init then
    return
  end

  local config = init.get_config()
  local state = init.get_state()

  local uranus = get_uranus()
  local lsp = get_lsp()

  local inspect_result = nil
  local lsp_hover_result = nil

  if config.auto_hover.inspect and uranus then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local col = cursor[2]
    inspect_result = uranus.inspect(word, col)
  end

  if lsp and config.lsp.enabled then
    lsp_hover_result = lsp.hover(word)
  end

  local lines = {}
  local title = nil

  if inspect_result and inspect_result.success and inspect_result.data then
    local data = inspect_result.data
    title = data.name or word
    if data.type_name and #data.type_name > 0 then
      table.insert(lines, "Type: " .. data.type_name)
    end
    if data.value and #data.value > 0 then
      local value = data.value
      if #value > 200 then
        value = value:sub(1, 200) .. "..."
      end
      table.insert(lines, "Value: " .. value)
    end
    if data.docstring and #data.docstring > 0 then
      local doc = data.docstring
      if #doc > 300 then
        doc = doc:sub(1, 300) .. "..."
      end
      table.insert(lines, "")
      table.insert(lines, doc)
    end
  elseif lsp_hover_result then
    title = word
    if type(lsp_hover_result) == "table" then
      for _, line in ipairs(lsp_hover_result) do
        table.insert(lines, line)
      end
    end
  end

  if #lines == 0 then
    return
  end

  if state.hover_winid and vim.api.nvim_win_is_valid(state.hover_winid) then
    vim.api.nvim_win_close(state.hover_winid, true)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  local title_line = title and ("[ %s ]"):format(title) or "Variable"
  local all_lines = { title_line, string.rep("─", #title_line) }
  vim.list_extend(all_lines, lines)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)

  local width = math.min(vim.o.columns - 10, 70)
  local height = math.min(#all_lines + 2, 25)
  local row = vim.fn.win_screenpos(0)[1]
  local col = vim.fn.win_screenpos(0)[2] + vim.fn.getcurpos()[2] - 5

  state.hover_bufnr = buf
  state.hover_winid = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = row + 1,
    col = col,
    style = "minimal",
    border = "rounded",
    zindex = 50,
  })

  vim.api.nvim_win_set_option(state.hover_winid, "wrap", true)
  vim.api.nvim_win_set_option(state.hover_winid, "conceallevel", 3)
end

function M.hide_hover()
  if hover_timer then
    hover_timer:close()
    hover_timer = nil
  end

  local init = get_init()
  if not init then
    return
  end

  local state = init.get_state()

  if state.hover_winid and vim.api.nvim_win_is_valid(state.hover_winid) then
    vim.api.nvim_win_close(state.hover_winid, true)
    state.hover_winid = nil
  end
  if state.hover_bufnr and vim.api.nvim_buf_is_valid(state.hover_bufnr) then
    vim.api.nvim_buf_delete(state.hover_bufnr, { force = true })
    state.hover_bufnr = nil
  end
end

function M.toggle_auto_hover()
  local init = get_init()
  if not init then
    return false
  end

  local config = init.get_config()
  config.auto_hover.enabled = not config.auto_hover.enabled
  return config.auto_hover.enabled
end

function M.toggle_lsp_diagnostics()
  local init = get_init()
  if not init then
    return false
  end

  local config = init.get_config()
  if not config.lsp then
    config.lsp = {}
  end
  config.lsp.diagnostics = not config.lsp.diagnostics
  return config.lsp.diagnostics
end

function M.toggle_code_lens()
  local init = get_init()
  if not init then
    return false
  end

  local config = init.get_config()
  config.code_lens.enabled = not config.code_lens.enabled
  return config.code_lens.enabled
end

return M