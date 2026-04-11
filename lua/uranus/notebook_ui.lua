--- Uranus Notebook UI - Jupyter-like modal notebook editor
--- Modal approach: Notebook mode (navigation) + Cell mode (isolated editing)
---
--- @module uranus.notebook_ui

local M = {}

local config = {
  auto_connect = false,
  show_outputs = true,
  show_status = true,
  show_cell_bar = true,
  cell_marker = "#%%",
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
    on_progress = nil,
    on_complete = nil,
  },
  treesitter = {
    enabled = false,
    auto_highlight = true,
    language = "python",
  },
}

local ns_notebook = vim.api.nvim_create_namespace("uranus_notebook_ui")
local ns_output = vim.api.nvim_create_namespace("uranus_notebook_ui_output")
local ns_border = vim.api.nvim_create_namespace("uranus_notebook_ui_border")
local ns_codelens = vim.api.nvim_create_namespace("uranus_notebook_ui_codelens")
local ns_hover = vim.api.nvim_create_namespace("uranus_notebook_ui_hover")

local state = {
  mode = "notebook",
  bufnr = nil,
  filepath = nil,
  notebook = nil,
  cells = {},
  current_cell = 1,
  kernel = nil,
  executing = {},
  dirty = false,
  shadow_bufnr = nil,
  hover_winid = nil,
  hover_bufnr = nil,
}

local cell_mode_bufnr = nil
local cell_mode_winid = nil

local hover_timer = nil

local function get_uranus()
  local ok, uranus = pcall(require, "uranus")
  return ok and uranus or nil
end

local function get_output()
  local ok, output = pcall(require, "uranus.output")
  return ok and output or nil
end

local function get_kernel()
  local ok, kernel = pcall(require, "uranus.kernel")
  return ok and kernel or nil
end

local function get_lsp()
  local ok, lsp = pcall(require, "uranus.lsp")
  return ok and lsp or nil
end

local function get_inspector()
  local ok, inspector = pcall(require, "uranus.inspector")
  return ok and inspector or nil
end

function M.configure(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
end

function M.get_config()
  return config
end

function M.is_notebook_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return state.bufnr == bufnr
end

function M.get_mode()
  return state.mode
end

function M.get_current_cell()
  return state.current_cell
end

function M.get_cells()
  return state.cells
end

function M.parse_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil, "Could not open file: " .. path
  end

  local content = file:read("*a")
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    return nil, "Invalid JSON: " .. tostring(data)
  end

  return data
end

function M.write_file(path, notebook)
  local content = vim.json.encode(notebook)
  local file = io.open(path, "w")
  if not file then
    return false, "Could not open file for writing: " .. path
  end

  file:write(content)
  file:close()
  return true
end

function M.parse_cells(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cells = {}

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local marker = config.cell_marker

  for i, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed == marker or trimmed:find("^" .. vim.pesc(marker) .. "%s*$") then
      table.insert(cells, {
        start = i - 1,
        cell_type = "code",
        source = {},
      })
    end
  end

  for i = 1, #cells do
    local start = cells[i].start
    local stop = cells[i + 1] and cells[i + 1].start or #lines
    local source = {}

    for j = start + 1, stop - 1 do
      local line = lines[j]
      if vim.trim(line) == marker or (marker ~= "#%%" and vim.trim(line):find("^" .. vim.pesc(marker))) then
        break
      end
      table.insert(source, line)
    end

    cells[i].source = source
    cells[i].stop = start + #source
  end

  return cells
end

function M.to_notebook(cells)
  local notebook = {
    cells = {},
    metadata = {
      kernelspec = {
        display_name = "Python 3",
        language = "python",
        name = "python3",
      },
    },
    nbformat = 4,
    nbformat_minor = 5,
  }

  for _, cell in ipairs(cells or {}) do
    table.insert(notebook.cells, {
      cell_type = cell.cell_type or "code",
      execution_count = cell.execution_count or nil,
      metadata = {},
      source = cell.source or {},
      outputs = cell.outputs or {},
    })
  end

  return notebook
end

function M.open(path)
  local notebook, err = M.parse_file(path)
  if not notebook then
    return nil, err
  end

  local bufnr = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(bufnr, path)
  vim.api.nvim_buf_set_option(bufnr, "filetype", "python")

  state.bufnr = bufnr
  state.filepath = path
  state.notebook = notebook
  
  state.cells = {}
  local all_lines = {}
  local line_offset = 0
  for i, cell in ipairs(notebook.cells or {}) do
    local source_lines = cell.source or {}
    table.insert(state.cells, {
      start = line_offset,
      stop = line_offset + #source_lines - 1,
      cell_type = cell.cell_type or "code",
      source = source_lines,
      outputs = cell.outputs or {},
      execution_count = cell.execution_count,
    })
    vim.list_extend(all_lines, source_lines)
    if i < #(notebook.cells or {}) then
      table.insert(all_lines, "")
    end
    line_offset = line_offset + #source_lines + 1
  end
  
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, all_lines)
  
  state.dirty = false
  state.current_cell = 1

  M.render_notebook()

  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_create_autocmd({ "BufWipeOut" }, {
    buffer = bufnr,
    callback = function()
      if state.shadow_bufnr then
        vim.api.nvim_buf_delete(state.shadow_bufnr, { force = true })
        state.shadow_bufnr = nil
      end
      if cell_mode_bufnr then
        vim.api.nvim_buf_delete(cell_mode_bufnr, { force = true })
        cell_mode_bufnr = nil
      end
    end,
  })

  return true
end

function M.save(path)
  path = path or state.filepath
  local notebook = M.to_notebook(state.cells)
  local ok, err = M.write_file(path, notebook)
  if ok then
    state.dirty = false
    state.filepath = path
  end
  return ok, err
end

function M.render_notebook()
  if not state.bufnr then
    return
  end

  vim.api.nvim_buf_clear_namespace(state.bufnr, ns_notebook, 0, -1)
  vim.api.nvim_buf_clear_namespace(state.bufnr, ns_border, 0, -1)
  vim.api.nvim_buf_clear_namespace(state.bufnr, ns_output, 0, -1)
  vim.api.nvim_buf_clear_namespace(state.bufnr, ns_codelens, 0, -1)

  local cells = state.cells
  for i, cell in ipairs(cells) do
    local start = cell.start or 0
    local is_current = (i == state.current_cell)
    local is_executing = state.executing[i] ~= nil

    M.render_cell_border(i, cell, is_current, is_executing)

    if config.show_outputs and cell.outputs and #cell.outputs > 0 then
      M.render_cell_output(i, cell)
    end

    if config.code_lens.enabled and config.code_lens.show_execution_count then
      M.render_code_lens(i, cell)
    end
  end

  M.render_shadow_buffer()
  M.render_lsp_diagnostics()
end

function M.render_cell_border(idx, cell, is_current, is_executing)
  local cfg = config.highlights
  local bc = config.border_hints

  local exec_count = cell.execution_count
  local count_str = "[ ]:"
  if exec_count and type(exec_count) == "number" then
    count_str = ("[%d]:"):format(exec_count)
  end
  local cell_type = cell.cell_type or "code"

  local hl_border = cfg.border
  local text = (" |%s %s|"):format(count_str, cell_type:sub(1, 1):upper())

  if is_current then
    hl_border = is_executing and cfg.executing or cfg.border_active
  elseif is_executing then
    hl_border = cfg.executing
  end

  vim.api.nvim_buf_set_extmark(state.bufnr, ns_border, cell.start, 0, {
    virt_text = { { text, hl_border } },
    virt_text_pos = "eol",
  })

  if bc.enabled and (is_current or bc.show_on_hover) then
    local hints = {}
    if is_current then
      hints = {
        { "↲Enter", cfg.hint },
        { "⌃↵Exec", cfg.hint },
      }
    end
    if #hints > 0 then
      vim.api.nvim_buf_set_extmark(state.bufnr, ns_border, cell.start, 0, {
        virt_text = hints,
        virt_text_pos = "right_align",
      })
    end
  end
end

function M.render_cell_output(idx, cell)
  local cfg = config.highlights

  local output_lines = {}
  for _, output in ipairs(cell.outputs or {}) do
    if output.output_type == "stream" then
      local text = output.text or {}
      for _, line in ipairs(text) do
        for _, split_line in ipairs(vim.split(line, "\n", { plain = true })) do
          if #split_line > 0 then
            table.insert(output_lines, split_line)
          end
        end
      end
    elseif output.output_type == "execute_result" then
      local data = output.data or {}
      local text = data["text/plain"] or {}
      for _, line in ipairs(text) do
        for _, split_line in ipairs(vim.split(line, "\n", { plain = true })) do
          if #split_line > 0 then
            table.insert(output_lines, split_line)
          end
        end
      end
    elseif output.output_type == "error" then
      table.insert(output_lines, "❌ " .. (output.ename or "Error"))
      local traceback = output.traceback or {}
      for _, line in ipairs(traceback) do
        table.insert(output_lines, "   " .. line)
      end
    end
  end

  if #output_lines > 0 then
    local output_start = (cell.stop or cell.start) + 1
    if output_start < 0 then
      return
    end

    local output_buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, output_lines)
    vim.api.nvim_buf_attach(output_buf, false, {})

    local buf_line_count = vim.api.nvim_buf_line_count(state.bufnr)
    if output_start < buf_line_count then
      vim.api.nvim_buf_set_extmark(state.bufnr, ns_output, output_start, 0, {
        virt_text = { { "↓ Output", cfg.output } },
        virt_text_pos = "eol",
      })
    end
  end
end

function M.render_shadow_buffer()
  if state.shadow_bufnr then
    vim.api.nvim_buf_delete(state.shadow_bufnr, { force = true })
  end

  local shadow = vim.api.nvim_create_buf(false, false)
  state.shadow_bufnr = shadow

  local lines = {}
  for _, cell in ipairs(state.cells) do
    if cell.cell_type == "code" then
      vim.list_extend(lines, cell.source)
      table.insert(lines, "")
    end
  end

  vim.api.nvim_buf_set_lines(shadow, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(shadow, "filetype", "python")
end

function M.render_code_lens(idx, cell)
  if cell.cell_type ~= "code" then
    return
  end

  local exec_count = cell.execution_count
  if not exec_count or type(exec_count) ~= "number" then
    return
  end

  local line = cell.start or 0
  local text = (" [In %d]"):format(exec_count)
  vim.api.nvim_buf_set_extmark(state.bufnr, ns_codelens, line, 0, {
    virt_text = { { text, config.highlights.code_lens } },
    virt_text_pos = "eol",
  })
end

function M.render_lsp_diagnostics()
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

  local cell_ranges = {}
  for i, cell in ipairs(state.cells) do
    local start = cell.start or 0
    local stop = cell.stop or start
    cell_ranges[i] = { start = start, stop = stop }
  end

  for _, diag in ipairs(buffer_diagnostics) do
    local line = (diag.range.start.line)
    for i, range in ipairs(cell_ranges) do
      if line >= range.start and line <= range.stop then
        local cell = state.cells[i]
        cell._has_diagnostic = true
        cell._diagnostic_count = (cell._diagnostic_count or 0) + 1
        break
      end
    end
  end

  for i, cell in ipairs(state.cells) do
    if cell._has_diagnostic then
      local count = cell._diagnostic_count
      local line = cell.start or 0
      local hint = (" [%d diagnostic%s]"):format(count, count == 1 and "" or "s")
      vim.api.nvim_buf_set_extmark(state.bufnr, ns_codelens, line + 1, 0, {
        virt_text = { { hint, "DiagnosticError" } },
        virt_text_pos = "eol",
      })
      cell._has_diagnostic = nil
      cell._diagnostic_count = nil
    end
  end
end

function M.show_hover_at_cursor()
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

  local uranus = get_uranus()
  local lsp = get_lsp()

  local inspect_result = nil
  local lsp_hover_result = nil

if config.auto_hover.inspect and uranus then
     -- Get cursor position for better inspection
     local cursor = vim.api.nvim_win_get_cursor(0)
     local line = cursor[1]
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
  vim.api.nvim_buf_set_option(buf, "filetype", "python")

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

  if state.hover_winid and vim.api.nvim_win_is_valid(state.hover_winid) then
    vim.api.nvim_win_close(state.hover_winid, true)
    state.hover_winid = nil
  end
  if state.hover_bufnr and vim.api.nvim_buf_is_valid(state.hover_bufnr) then
    vim.api.nvim_buf_delete(state.hover_bufnr, { force = true })
    state.hover_bufnr = nil
  end
end

function M.render_images()
  if not config.images.enabled or not config.images.inline then
    return
  end

  local output = get_output()
  if not output then
    return
  end

  for i, cell in ipairs(state.cells) do
    if cell.outputs and #cell.outputs > 0 then
      for _, out in ipairs(cell.outputs) do
        if out.output_type == "execute_result" and out.data then
          local data = out.data
          if data["image/png"] then
            local line = (cell.stop or cell.start) + 1
            local base64 = data["image/png"]
            output.display_image(base64, ("Cell %d Image"):format(i))
          elseif data["image/svg+xml"] then
            local line = (cell.stop or cell.start) + 1
            local svg = data["image/svg+xml"]
            output.display_svg(svg, ("Cell %d SVG"):format(i))
          end
        end
      end
    end
  end
end

function M.format_cell()
  local lsp = get_lsp()
  if not lsp or not config.lsp.enabled then
    return
  end

  local cell = state.cells[state.current_cell]
  if not cell or cell.cell_type ~= "code" then
    return
  end

  lsp.format()
end

function M.format_all_cells()
  local lsp = get_lsp()
  if not lsp or not config.lsp.enabled then
    return
  end

  lsp.format()
  vim.notify("Formatted notebook", vim.log.levels.INFO)
end

function M.enter_cell_mode()
  if state.mode == "cell" then
    return
  end

  local cell = state.cells[state.current_cell]
  if not cell or cell.cell_type == "markdown" then
    vim.notify("Cannot edit markdown cell in cell mode", vim.log.levels.WARN)
    return
  end

  if not cell_mode_bufnr then
    cell_mode_bufnr = vim.api.nvim_buf_create(true, false)
    vim.api.nvim_buf_set_name(cell_mode_bufnr, ("Uranus Cell %d"):format(state.current_cell))
  end

  vim.api.nvim_buf_set_lines(cell_mode_bufnr, 0, -1, false, cell.source)
  vim.api.nvim_buf_set_option(cell_mode_bufnr, "filetype", "python")
  vim.api.nvim_buf_set_option(cell_mode_bufnr, "modifiable", true)

  local width = math.min(vim.o.columns - 10, 80)
  local height = math.min(#cell.source + 4, vim.o.lines - 10)

  cell_mode_winid = vim.api.nvim_open_win(cell_mode_bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = (vim.o.lines - height) / 2,
    col = (vim.o.columns - width) / 2,
    style = "minimal",
    border = { "╭", "─", "╮", "│", "╯", "─", "╰", "╱" },
  })

  state.mode = "cell"

  vim.api.nvim_create_autocmd({ "BufWipeOut" }, {
    buffer = cell_mode_bufnr,
    callback = function()
      M.exit_cell_mode()
    end,
  })

  vim.keymap.set("n", "<Esc>", function()
    M.exit_cell_mode()
  end, { buffer = cell_mode_bufnr, noremap = true })

  vim.keymap.set("n", "<Leader>kx", function()
    M.execute_cell()
  end, { buffer = cell_mode_bufnr, noremap = true })

  vim.keymap.set("n", "<C-j>", function()
    M.next_cell()
    M.exit_cell_mode()
  end, { buffer = cell_mode_bufnr, noremap = true })

  vim.keymap.set("n", "<C-k>", function()
    M.prev_cell()
    M.exit_cell_mode()
  end, { buffer = cell_mode_bufnr, noremap = true })
end

function M.exit_cell_mode()
  if state.mode ~= "cell" then
    return
  end

  if cell_mode_bufnr and vim.api.nvim_buf_is_valid(cell_mode_bufnr) then
    local lines = vim.api.nvim_buf_get_lines(cell_mode_bufnr, 0, -1, false)
    state.cells[state.current_cell].source = lines
  end

  if cell_mode_winid and vim.api.nvim_win_is_valid(cell_mode_winid) then
    vim.api.nvim_win_close(cell_mode_winid, true)
  end

  cell_mode_bufnr = nil
  cell_mode_winid = nil
  state.mode = "notebook"

  M.render_notebook()
  state.dirty = true
end

function M.next_cell()
  if state.current_cell < #state.cells then
    state.current_cell = state.current_cell + 1
  end
end

function M.prev_cell()
  if state.current_cell > 1 then
    state.current_cell = state.current_cell - 1
  end
end

function M.goto_cell(idx)
  if idx >= 1 and idx <= #state.cells then
    state.current_cell = idx
  end
end

function M.execute_cell()
  local cell = state.cells[state.current_cell]
  if not cell then
    return
  end

  local uranus = get_uranus()
  if not uranus then
    vim.notify("Uranus backend not available", vim.log.levels.ERROR)
    return
  end

  state.executing[state.current_cell] = true
  M.render_notebook()

  local code = table.concat(cell.source, "\n")
  local ok, result = pcall(uranus.execute, code)

  state.executing[state.current_cell] = nil

  if ok and result then
    if result.status == "ok" then
      local count = result.execution_count or state.current_cell
      cell.execution_count = count
      cell.outputs = result.outputs or {}

      if result.output then
        cell.outputs = { {
          output_type = "execute_result",
          data = {
            ["text/plain"] = vim.split(result.output, "\n"),
          },
        } }
      end
    elseif result.status == "error" then
      cell.outputs = { {
        output_type = "error",
        ename = result.error_type or "Error",
        evalue = result.error_value or "",
        traceback = vim.split(result.traceback or "", "\n"),
      } }
    end
  end

  state.dirty = true
  M.render_notebook()
end

function M.execute_and_next()
  M.execute_cell()
  if state.current_cell < #state.cells then
    M.next_cell()
    M.enter_cell_mode()
  end
end

function M.clear_output()
  local cell = state.cells[state.current_cell]
  if cell then
    cell.outputs = {}
    cell.execution_count = nil
    state.dirty = true
    M.render_notebook()
  end
end

function M.execute_cell_async(on_complete)
  if not config.async.enabled then
    M.execute_cell()
    if on_complete then on_complete() end
    return
  end

  local cell = state.cells[state.current_cell]
  if not cell then
    if on_complete then on_complete() end
    return
  end

  local uranus = get_uranus()
  if not uranus then
    vim.notify("Uranus backend not available", vim.log.levels.ERROR)
    if on_complete then on_complete() end
    return
  end

  state.executing[state.current_cell] = true
  M.render_notebook()

  local code = table.concat(cell.source, "\n")

  vim.defer_fn(function()
    local ok, result = pcall(uranus.execute, code)

    state.executing[state.current_cell] = nil

    if ok and result then
      if result.status == "ok" then
        local count = result.execution_count or state.current_cell
        cell.execution_count = count
        cell.outputs = result.outputs or {}

        if result.output then
          cell.outputs = { {
            output_type = "execute_result",
            data = {
              ["text/plain"] = vim.split(result.output, "\n"),
            },
          } }
        end
      elseif result.status == "error" then
        cell.outputs = { {
          output_type = "error",
          ename = result.error_type or "Error",
          evalue = result.error_value or "",
          traceback = vim.split(result.traceback or "", "\n"),
        } }
      end
    end

    state.dirty = true
    M.render_notebook()

    if config.async.on_progress then
      config.async.on_progress(state.current_cell, result)
    end

    if on_complete then on_complete() end
  end, 1)
end

function M.run_all_async(on_complete)
  if not config.async.enabled then
    for i = 1, #state.cells do
      state.current_cell = i
      M.execute_cell()
    end
    if on_complete then on_complete() end
    return
  end

  local index = 1
  local total = #state.cells

  local function run_next()
    if index > total then
      if on_complete then on_complete() end
      if config.async.on_complete then
        config.async.on_complete()
      end
      vim.notify("All cells executed", vim.log.levels.INFO)
      return
    end

    state.current_cell = index
    local cell = state.cells[index]
    if not cell or cell.cell_type ~= "code" then
      index = index + 1
      vim.defer_fn(run_next, config.async.sequential_delay)
      return
    end

    local uranus = get_uranus()
    if not uranus then
      index = index + 1
      vim.defer_fn(run_next, config.async.sequential_delay)
      return
    end

    state.executing[index] = true
    M.render_notebook()

    local code = table.concat(cell.source, "\n")

    vim.defer_fn(function()
      local ok, result = pcall(uranus.execute, code)

      state.executing[index] = nil

      if ok and result then
        if result.status == "ok" then
          local count = result.execution_count or index
          cell.execution_count = count
          cell.outputs = result.outputs or {}

          if result.output then
            cell.outputs = { {
              output_type = "execute_result",
              data = {
                ["text/plain"] = vim.split(result.output, "\n"),
              },
            } }
          end
        elseif result.status == "error" then
          cell.outputs = { {
            output_type = "error",
            ename = result.error_type or "Error",
            evalue = result.error_value or "",
            traceback = vim.split(result.traceback or "", "\n"),
          } }
        end
      end

      state.dirty = true
      M.render_notebook()

      if config.async.on_progress then
        config.async.on_progress(index, result)
      end

      index = index + 1
      vim.defer_fn(run_next, config.async.sequential_delay)
    end, 1)
  end

  vim.notify("Starting async execution of " .. total .. " cells", vim.log.levels.Info)
  run_next()
end

function M.run_all_parallel(on_complete)
  if not config.async.enabled or not config.async.parallel then
    M.run_all_async(on_complete)
    return
  end

  local cells = {}
  for i, cell in ipairs(state.cells) do
    if cell.cell_type == "code" then
      table.insert(cells, { index = i, cell = cell })
    end
  end

  local max_parallel = config.async.max_parallel
  local running = 0
  local completed = 0
  local total = #cells

  local uranus = get_uranus()
  if not uranus then
    vim.notify("Uranus backend not available", vim.log.levels.ERROR)
    if on_complete then on_complete() end
    return
  end

  local function spawn_next()
    while #cells > 0 and running < max_parallel do
      local item = table.remove(cells, 1)
      running = running + 1
      state.executing[item.index] = true

      local code = table.concat(item.cell.source, "\n")

      vim.defer_fn(function()
        local ok, result = pcall(uranus.execute, code)

        state.executing[item.index] = nil
        completed = completed + 1

        if ok and result then
          if result.status == "ok" then
            local count = result.execution_count or item.index
            item.cell.execution_count = count
            item.cell.outputs = result.outputs or {}

            if result.output then
              item.cell.outputs = { {
                output_type = "execute_result",
                data = {
                  ["text/plain"] = vim.split(result.output, "\n"),
                },
              } }
            end
          elseif result.status == "error" then
            item.cell.outputs = { {
              output_type = "error",
              ename = result.error_type or "Error",
              evalue = result.error_value or "",
              traceback = vim.split(result.traceback or "", "\n"),
            } }
          end
        end

        state.dirty = true
        M.render_notebook()

        if config.async.on_progress then
          config.async.on_progress(item.index, result)
        end

        running = running - 1

        if #cells > 0 or running > 0 then
          spawn_next()
        else
          if on_complete then on_complete() end
          if config.async.on_complete then
            config.async.on_complete()
          end
          vim.notify("Parallel execution complete: " .. completed .. " cells", vim.log.levels.INFO)
        end
      end, 1)
    end
  end

  vim.notify("Starting parallel execution (" .. max_parallel .. " concurrent)", vim.log.levels.Info)
  spawn_next()
end

function M.toggle_async_mode()
  config.async.parallel = not config.async.parallel
  vim.notify("Async mode: " .. (config.async.parallel and "parallel" or "sequential"), vim.log.levels.INFO)
end

function M.stop_execution()
  for i, _ in pairs(state.executing) do
    state.executing[i] = nil
  end

  local uranus = get_uranus()
  if uranus then
    uranus.interrupt()
  end

  M.render_notebook()
  vim.notify("Execution stopped", vim.log.levels.Info)
end

function M.setup_treesitter()
  if not config.treesitter.enabled then
    return false
  end

  local ok, treesitter = pcall(require, "nvim-treesitter")
  if not ok then
    vim.notify("Treesitter not available", vim.log.levels.WARN)
    return false
  end

  local lang = config.treesitter.language or "python"
  local installed = treesitter.get_installed_langparsers()

  for _, parser in ipairs(installed) do
    if parser == lang then
      return true
    end
  end

  vim.notify("Treesitter parser '" .. lang .. "' not installed. Run :TSInstall " .. lang, vim.log.levels.WARN)
  return false
end

function M.highlight_cell_syntax()
  if not config.treesitter.enabled or not config.treesitter.auto_highlight then
    return
  end

  local ok, _ = pcall(require, "nvim-treesitter")
  if not ok then
    return
  end

  local lang = config.treesitter.language or "python"
  
  if state.shadow_bufnr and vim.api.nvim_buf_is_valid(state.shadow_bufnr) then
    vim.api.nvim_buf_set_option(state.shadow_bufnr, "filetype", lang)
    vim.api.nvim_buf_set_option(state.shadow_bufnr, "syntax", lang)
  end

  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    vim.api.nvim_buf_set_option(state.bufnr, "filetype", lang)
    vim.api.nvim_buf_set_option(state.bufnr, "syntax", lang)
  end
end

function M.enable_treesitter(enabled)
  config.treesitter.enabled = enabled
  if enabled then
    M.setup_treesitter()
    M.highlight_cell_syntax()
    vim.notify("Treesitter enabled for notebook", vim.log.levels.INFO)
  else
    vim.notify("Treesitter disabled for notebook", vim.log.levels.INFO)
  end
end

function M.get_treesitter_status()
  local ok, treesitter = pcall(require, "nvim-treesitter")
  if not ok then
    return { available = false, reason = "not installed" }
  end

  local lang = config.treesitter.language or "python"
  local installed = treesitter.get_installed_langparsers()
  
  local lang_installed = false
  for _, parser in ipairs(installed) do
    if parser == lang then
      lang_installed = true
      break
    end
  end

  return {
    available = true,
    enabled = config.treesitter.enabled,
    language = lang,
    parser_installed = lang_installed,
  }
end

function M.clear_all_outputs()
  for _, cell in ipairs(state.cells) do
    cell.outputs = {}
    cell.execution_count = nil
  end
  state.dirty = true
  M.render_notebook()
end

function M.add_cell_below()
  local new_cell = {
    start = (state.cells[state.current_cell].stop or 0) + 1,
    cell_type = "code",
    source = { "" },
    outputs = {},
  }
  table.insert(state.cells, state.current_cell + 1, new_cell)
  state.current_cell = state.current_cell + 1
  state.dirty = true
  M.render_notebook()
end

function M.add_cell_above()
  local new_cell = {
    start = (state.cells[state.current_cell].start or 0),
    cell_type = "code",
    source = { "" },
    outputs = {},
  }
  table.insert(state.cells, state.current_cell, new_cell)
  state.dirty = true
  M.render_notebook()
end

function M.delete_cell()
  if #state.cells <= 1 then
    vim.notify("Cannot delete the last cell", vim.log.levels.WARN)
    return
  end

  table.remove(state.cells, state.current_cell)
  if state.current_cell > #state.cells then
    state.current_cell = #state.cells
  end
  state.dirty = true
  M.render_notebook()
end

function M.toggle_cell_type()
  local cell = state.cells[state.current_cell]
  if not cell then
    return
  end

  cell.cell_type = cell.cell_type == "code" and "markdown" or "code"
  state.dirty = true
  M.render_notebook()
end

function M.move_cell_up()
  if state.current_cell <= 1 then
    return
  end

  local cell = table.remove(state.cells, state.current_cell)
  state.current_cell = state.current_cell - 1
  table.insert(state.cells, state.current_cell, cell)
  state.dirty = true
  M.render_notebook()
end

function M.move_cell_down()
  if state.current_cell >= #state.cells then
    return
  end

  local cell = table.remove(state.cells, state.current_cell)
  state.current_cell = state.current_cell + 1
  table.insert(state.cells, state.current_cell, cell)
  state.dirty = true
  M.render_notebook()
end

function M.fold_cell()
  local cell = state.cells[state.current_cell]
  if not cell then
    return
  end

  local start = cell.start or 0
  local stop = cell.stop or (start + #cell.source)
  vim.cmd(start + 1 .. "," .. stop + 1 .. "fold")
end

function M.unfold_cell()
  local cell = state.cells[state.current_cell]
  if not cell then
    return
  end

  local start = cell.start or 0
  local stop = cell.stop or (start + #cell.source)
  vim.cmd(start + 1 .. "," .. stop + 1 .. "foldopen")
end

function M.fold_toggle()
  local cell = state.cells[state.current_cell]
  if vim.cmd("."):match("folded") then
    M.unfold_cell()
  else
    M.fold_cell()
  end
end

function M.output()
  local cell = state.cells[state.current_cell]
  if not cell or not cell.outputs or #cell.outputs == 0 then
    return
  end

  local lines = {}
  for _, output in ipairs(cell.outputs) do
    if output.output_type == "stream" then
      vim.list_extend(lines, output.text or {})
    elseif output.output_type == "execute_result" then
      local data = output.data or {}
      vim.list_extend(lines, data["text/plain"] or {})
    elseif output.output_type == "error" then
      table.insert(lines, "❌ " .. (output.ename or "Error"))
      vim.list_extend(lines, output.traceback or {})
    end
  end

  local output_buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(output_buf, "filetype", "python")

  vim.cmd("botright split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, output_buf)
end

function M.statusline()
  if not state.bufnr then
    return nil
  end

  local kernel_state = "idle"
  local kernel_name = "python3"

  for _, executing in pairs(state.executing) do
    if executing then
      kernel_state = "busy"
      break
    end
  end

  local current_cell = state.current_cell
  local total_cells = #state.cells
  local cell_info = ("Cell %d/%d"):format(current_cell, total_cells)

  return ("%s | [%s] %s"):format(cell_info, kernel_name:sub(1, 6), kernel_state:sub(1, 4):upper())
end

function M.setup_keymaps(bufnr)
  vim.keymap.set("n", "]]", function()
    M.next_cell()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "[[", function()
    M.prev_cell()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "i", function()
    M.enter_cell_mode()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<CR>", function()
    M.enter_cell_mode()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<Esc>", function()
    M.exit_cell_mode()
  end, { buffer = bufnr, noremap = true, silent = true })

  vim.keymap.set("n", "<Leader>kb", function()
    M.add_cell_below()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<Leader>ka", function()
    M.add_cell_above()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<Leader>kd", function()
    M.delete_cell()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<Leader>km", function()
    M.toggle_cell_type()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<Leader>kx", function()
    M.execute_cell()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<S-CR>", function()
    M.execute_and_next()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<C-CR>", function()
    M.execute_cell()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<Leader>ko", function()
    M.output()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<Leader>kc", function()
    M.clear_output()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<Leader>kf", function()
    M.fold_toggle()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<M-k>", function()
    M.move_cell_up()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<M-j>", function()
    M.move_cell_down()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<Leader>kj", function()
    vim.ui.select(state.cells, {
      prompt = "Go to cell:",
      format_item = function(cell, idx)
        return ("[%d] %s"):format(idx, cell.cell_type or "code")
      end,
    }, function(choice)
      if choice then
        for i, c in ipairs(state.cells) do
          if c == choice then
            M.goto_cell(i)
            break
          end
        end
      end
    end)
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "K", function()
    M.show_hover_at_cursor()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<Leader>kh", function()
    M.hide_hover()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<Leader>ke", function()
    M.format_cell()
  end, { buffer = bufnr, noremap = true })

  vim.keymap.set("n", "<Leader>kE", function()
    M.format_all_cells()
  end, { buffer = bufnr, noremap = true })

  vim.api.nvim_create_autocmd({ "CursorMoved" }, {
    buffer = bufnr,
    callback = function()
      if config.auto_hover.enabled then
        M.show_hover_at_cursor()
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufLeave" }, {
    buffer = bufnr,
    callback = function()
      M.hide_hover()
    end,
  })
end

function M.setup(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not M.is_notebook_buffer(bufnr) then
    return
  end

  state.bufnr = bufnr
  state.cells = M.parse_cells(bufnr)

  M.setup_keymaps(bufnr)

  vim.api.nvim_buf_attach(bufnr, false, {
    on_reload = function()
      state.cells = M.parse_cells(bufnr)
      M.render_notebook()
    end,
  })
end

function M.health_check()
  local issues = {}
  local warnings = {}
  local info = {}

  table.insert(info, "Uranus Notebook UI - Health Check")
  table.insert(info, string.rep("─", 40))

  table.insert(info, "")
  table.insert(info, "Module Status:")
  table.insert(info, "  ✓ notebook_ui loaded")

  local uranus = get_uranus()
  if uranus then
    table.insert(info, "  ✓ uranus core available")
  else
    table.insert(issues, "  ✗ uranus core not available")
  end

  local output = get_output()
  if output then
    table.insert(info, "  ✓ output module available")
  else
    table.insert(warnings, "  ⚠ output module not available")
  end

  local lsp = get_lsp()
  if lsp and lsp.is_available() then
    local status = lsp.status()
    table.insert(info, "  ✓ LSP connected: " .. (status.clients[1] and status.clients[1].name or "unknown"))
  else
    table.insert(warnings, "  ⚠ LSP not connected (optional)")
  end

  local inspector = get_inspector()
  if inspector then
    table.insert(info, "  ✓ inspector module available")
  else
    table.insert(warnings, "  ⚠ inspector module not available")
  end

  table.insert(info, "")
  table.insert(info, "Configuration:")
  table.insert(info, "  auto_hover: " .. (config.auto_hover.enabled and "enabled" or "disabled"))
  table.insert(info, "  lsp.diagnostics: " .. (config.lsp.diagnostics and "enabled" or "disabled"))
  table.insert(info, "  code_lens: " .. (config.code_lens.enabled and "enabled" or "disabled"))
  table.insert(info, "  images.inline: " .. (config.images.inline and "enabled" or "disabled"))

  table.insert(info, "")
  table.insert(info, "Current State:")
  table.insert(info, "  mode: " .. state.mode)
  table.insert(info, "  cells: " .. #state.cells)
  table.insert(info, "  current_cell: " .. state.current_cell)
  table.insert(info, "  dirty: " .. (state.dirty and "yes" or "no"))

  if #issues > 0 then
    table.insert(info, "")
    table.insert(info, "Issues:")
    vim.list_extend(info, issues)
  end

  if #warnings > 0 then
    table.insert(info, "")
    table.insert(info, "Warnings:")
    vim.list_extend(info, warnings)
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, info)
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = 60,
    height = math.min(#info + 4, vim.o.lines - 10),
    row = 5,
    col = (vim.o.columns - 60) / 2,
    style = "minimal",
    border = "rounded",
    title = "Uranus Health Check",
    title_pos = "center",
  })
end

function M.toggle_auto_hover()
  config.auto_hover.enabled = not config.auto_hover.enabled
  vim.notify("Auto-hover " .. (config.auto_hover.enabled and "enabled" or "disabled"), vim.log.levels.INFO)
end

function M.toggle_lsp_diagnostics()
  config.lsp.diagnostics = not config.lsp.diagnostics
  M.render_notebook()
  vim.notify("LSP diagnostics " .. (config.lsp.diagnostics and "enabled" or "disabled"), vim.log.levels.INFO)
end

function M.toggle_code_lens()
  config.code_lens.enabled = not config.code_lens.enabled
  M.render_notebook()
  vim.notify("Code lens " .. (config.code_lens.enabled and "enabled" or "disabled"), vim.log.levels.INFO)
end

return M