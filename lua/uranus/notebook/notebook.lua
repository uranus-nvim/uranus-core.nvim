local M = {}

local config = nil

local function get_config()
  if not config then
    local cfg = require("uranus.config")
    local defaults = cfg.get("notebook") or {}
    config = vim.deepcopy(defaults)
    config.auto_sync = true
    config.render_markdown = true
  end
  return config
end

local ns_notebook = vim.api.nvim_create_namespace("uranus_notebook")
local ns_output = vim.api.nvim_create_namespace("uranus_notebook_output")

local cell_cache = {}
local cell_cache_time = 0
local cell_cache_ttl = 2000

local function get_uranus()
  local ok, uranus = pcall(require, "uranus")
  return ok and uranus or nil
end

local function get_output()
  local ok, output = pcall(require, "uranus.output")
  return ok and output or nil
end

function M.configure(opts)
  local cfg = require("uranus.config")
  local current = cfg.get("notebook") or {}
  config = vim.tbl_deep_extend("force", current, opts or {})
  config.auto_sync = true
  config.render_markdown = true
end

function M.get_config()
  return get_config()
end

function M.invalidate_cache()
  cell_cache = {}
  cell_cache_time = 0
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
    return nil, "Invalid JSON: " .. data
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

function M.get_cells(notebook)
  return notebook.cells or {}
end

function M.to_buffer(notebook)
  local lines = {}
  local cells = M.get_cells(notebook)
  local marker = config.cell_marker

  for i, cell in ipairs(cells) do
    local cell_type = cell.cell_type or "code"
    local source = table.concat(cell.source or {}, "\n")

    if cell_type == "markdown" then
      table.insert(lines, marker .. " [markdown]")
      for _, line in ipairs(vim.split(source, "\n", { trimempty = false })) do
        table.insert(lines, "# " .. line)
      end
    else
      table.insert(lines, marker)
      for _, line in ipairs(vim.split(source, "\n", { trimempty = false })) do
        table.insert(lines, line)
      end
    end

    if config.show_outputs and cell.outputs and #cell.outputs > 0 then
      table.insert(lines, "## outputs:")
      for _, output in ipairs(cell.outputs) do
        if output.output_type == "stream" then
          table.insert(lines, "# " .. (output.name or "stdout") .. ": " .. table.concat(output.text or {}, ""))
        elseif output.output_type == "execute_result" or output.output_type == "display_data" then
          for mime, data in pairs(output.data or {}) do
            if mime == "text/plain" then
              table.insert(lines, "# result: " .. table.concat(data, ""))
            else
              table.insert(lines, "# [" .. mime .. ": " .. #data .. " bytes]")
            end
          end
        elseif output.output_type == "error" then
          table.insert(lines, "# Error: " .. table.concat(output.traceback or {}, "\n"))
        end
      end
    end

    table.insert(lines, "")
  end

  return lines
end

function M.from_buffer(lines)
  local cells = {}
  local current_cell = nil
  local marker = config.cell_marker

  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)

    if trimmed:find("^" .. vim.pesc(marker)) then
      if current_cell then
        table.insert(cells, current_cell)
      end

      local is_markdown = trimmed:find("markdown")
      current_cell = {
        cell_type = is_markdown and "markdown" or "code",
        source = {},
        outputs = {},
        metadata = {},
      }
    elseif current_cell then
      if trimmed:find("^# ") then
        table.insert(current_cell.source, trimmed:sub(3))
      else
        table.insert(current_cell.source, line)
      end
    end
  end

  if current_cell then
    table.insert(cells, current_cell)
  end

  return cells
end

function M.create(kernel_name)
  kernel_name = kernel_name or "python3"

  return {
    nbformat = 4,
    nbformat_minor = 5,
    metadata = {
      kernelspec = {
        display_name = "Python 3",
        language = "python",
        name = kernel_name,
      },
      language_info = {
        name = "python",
        version = "3.10.0",
      },
    },
    cells = {
      {
        cell_type = "code",
        execution_count = nil,
        metadata = {},
        outputs = {},
        source = { "" },
      },
    },
  }
end

function M.save(path)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cells = M.from_buffer(lines)

  local notebook = {
    nbformat = 4,
    nbformat_minor = 5,
    metadata = {
      kernelspec = {
        display_name = "Python 3",
        language = "python",
        name = "python3",
      },
    },
    cells = cells,
  }

  return M.write_file(path, notebook)
end

function M.open(path)
  local notebook, err = M.parse_file(path)
  if not notebook then
    vim.notify("Failed to open notebook: " .. err, vim.log.levels.ERROR)
    return
  end

  local lines = M.to_buffer(notebook)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(buf, path)
  vim.api.nvim_set_current_buf(buf)

  vim.b.uranus_notebook_path = path
  vim.b.uranus_notebook_data = notebook
end

function M.new(name, path)
  path = path or vim.fn.getcwd()
  local notebook = M.create("python3")
  local file_path = path .. "/" .. name .. ".ipynb"

  local ok, err = M.write_file(file_path, notebook)
  if not ok then
    vim.notify("Failed to create notebook: " .. err, vim.log.levels.ERROR)
    return
  end

  M.open(file_path)
end

function M.run_cell()
  local u = get_uranus()
  if not u then
    vim.notify("Uranus not available", vim.log.levels.ERROR)
    return
  end

  local cell = M.get_current_cell()
  if not cell then
    vim.notify("No cell found", vim.log.levels.WARN)
    return
  end

  local source = table.concat(cell.source, "\n")
  local result = u.execute(source)

  if result.success and config.show_outputs then
    local out = get_output()
    if out then
      out.display(result.data)
    end
  end

  return result
end

function M.get_current_cell()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local marker = config.cell_marker

  local current_cell = nil

  for i, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed:find("^" .. vim.pesc(marker)) then
      if current_cell and i > cursor[1] then
        break
      end
      current_cell = {
        source = {},
        outputs = {},
      }
    elseif current_cell then
      local trimmed_line = vim.trim(line)
      if trimmed_line:find("^" .. vim.pesc(marker)) then
        break
      end
      if trimmed_line:find("^# ") and not trimmed_line:find("^# %%" ) then
      else
        table.insert(current_cell.source, line)
      end
    end
  end

  return current_cell
end

function M.run_all()
  local u = get_uranus()
  if not u then
    return {}
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cells = M.from_buffer(lines)
  local results = {}

  for _, cell in ipairs(cells) do
    if cell.cell_type == "code" then
      local source = table.concat(cell.source, "\n")
      local result = u.execute(source)
      table.insert(results, result)
    end
  end

  return results
end

function M.insert_cell_above()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local marker = config.cell_marker

  local insert_at = 1
  for i = cursor[1] - 1, 1, -1 do
    if vim.trim(lines[i]):find("^" .. vim.pesc(marker)) then
      insert_at = i
      break
    end
  end

  table.insert(lines, insert_at, marker)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { insert_at, 0 })
end

function M.insert_cell_below()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local marker = config.cell_marker

  local insert_at = #lines
  for i = cursor[1] + 1, #lines do
    if vim.trim(lines[i]):find("^" .. vim.pesc(marker)) then
      insert_at = i - 1
      break
    end
  end

  table.insert(lines, insert_at + 1, marker)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { insert_at + 1, 0 })
end

function M.delete_cell()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local marker = config.cell_marker

  local cell_start = nil
  local cell_end = nil

  for i = cursor[1], 1, -1 do
    if vim.trim(lines[i]):find("^" .. vim.pesc(marker)) then
      cell_start = i
      break
    end
  end

  for i = cursor[1], #lines do
    if vim.trim(lines[i]):find("^" .. vim.pesc(marker)) and i > cursor[1] then
      cell_end = i - 1
      break
    end
  end

  if not cell_end then
    cell_end = #lines
  end

  if cell_start then
    local new_lines = {}
    for i = 1, #lines do
      if i < cell_start or i > cell_end then
        table.insert(new_lines, lines[i])
      end
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
  end
end

function M.toggle_cell_type()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local marker = config.cell_marker

  for i = cursor[1], 1, -1 do
    local trimmed = vim.trim(lines[i])
    if trimmed:find("^" .. vim.pesc(marker)) then
      local is_markdown = trimmed:find("markdown")
      if is_markdown then
        lines[i] = marker
      else
        lines[i] = marker .. " [markdown]"
      end
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      return
    end
  end
end

function M.render_markdown()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local marker = config.cell_marker
  local ns = vim.api.nvim_create_namespace("uranus_markdown")

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local in_markdown = false
  for i, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed:find("^" .. vim.pesc(marker)) then
      in_markdown = trimmed:find("markdown")
    elseif in_markdown then
      if trimmed:find("^#%s+") then
        vim.api.nvim_buf_add_highlight(bufnr, ns, "UranusH1", i - 1, 0, -1)
      elseif trimmed:find("^##%s+") then
        vim.api.nvim_buf_add_highlight(bufnr, ns, "UranusH2", i - 1, 0, -1)
      elseif trimmed:find("^###%s+") then
        vim.api.nvim_buf_add_highlight(bufnr, ns, "UranusH3", i - 1, 0, -1)
      elseif trimmed:find("^```") then
        vim.api.nvim_buf_add_highlight(bufnr, ns, "UranusCodeBlock", i - 1, 0, -1)
      end
    end
  end
end

function M.show_execution_state(state)
  local ns = vim.api.nvim_create_namespace("uranus_execution")
  local bufnr = vim.api.nvim_get_current_buf()
  local marker = config.cell_marker
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for i, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed:find("^" .. vim.pesc(marker)) and not trimmed:find("markdown") then
      if state == "executing" then
        vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
          virt_text = { { " 🔄", "UranusExecuting" } },
          virt_text_pos = "eol",
        })
      else
        vim.api.nvim_buf_clear_namespace(bufnr, ns, i - 1, i)
      end
    end
  end
end

function M.next_cell()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local marker = config.cell_marker

  for i = cursor[1] + 1, #lines do
    local trimmed = vim.trim(lines[i])
    if trimmed:find("^" .. vim.pesc(marker)) then
      vim.api.nvim_win_set_cursor(0, { i, 0 })
      return
    end
  end

  vim.notify("No next cell", vim.log.levels.INFO)
end

function M.prev_cell()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local marker = config.cell_marker

  for i = cursor[1] - 1, 1, -1 do
    local trimmed = vim.trim(lines[i])
    if trimmed:find("^" .. vim.pesc(marker)) then
      vim.api.nvim_win_set_cursor(0, { i, 0 })
      return
    end
  end

  vim.notify("No previous cell", vim.log.levels.INFO)
end

function M.clear_output()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local output_start = nil
  local output_end = nil

  for i = cursor[1], #lines do
    local trimmed = vim.trim(lines[i])
    if trimmed == "## outputs:" then
      output_start = i
    elseif output_start and vim.trim(lines[i]):find("^# ") == nil then
      output_end = i - 1
      break
    end
  end

  if not output_end then
    output_end = #lines
  end

  if output_start then
    local new_lines = {}
    for i = 1, #lines do
      if i < output_start or i > output_end then
        table.insert(new_lines, lines[i])
      end
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
  end
end

function M.get_toc()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local marker = config.cell_marker
  local toc = {}

  local current_cell_is_markdown = false

  for i, line in ipairs(lines) do
    local trimmed = vim.trim(line)

    if trimmed:find("^" .. vim.pesc(marker)) then
      current_cell_is_markdown = trimmed:find("markdown")
    elseif current_cell_is_markdown then
      local heading = trimmed:match("^#%s+(.+)$")
      if heading then
        local level = #(trimmed:match("^#+") or "#")
        table.insert(toc, {
          level = level,
          title = heading,
          line = i - 1,
        })
      end
    end
  end

  return toc
end

function M.open_toc()
  local toc = M.get_toc()

  local lines = { "=== Table of Contents ===", "" }

  if #toc == 0 then
    table.insert(lines, "  No markdown headings found")
  else
    for _, item in ipairs(toc) do
      local indent = string.rep("  ", item.level - 1)
      table.insert(lines, string.format("%s%s (line %d)", indent, item.title, item.line + 1))
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = 40
  local height = math.min(#lines + 2, vim.o.lines - 10)

  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = 5,
    col = vim.o.columns - 50,
    style = "minimal",
    border = "rounded",
    title = "Uranus TOC",
    title_pos = "center",
  })

  vim.keymap.set("n", "<cr>", function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_idx = cursor[1]
    if line_idx > 1 and line_idx <= #toc then
      local target_line = toc[line_idx - 1].line
      vim.api.nvim_win_set_cursor(0, { target_line + 1, 0 })
    end
  end, { buffer = buf, nowait = true })
end

function M.save_outputs(path)
  local notebook = M.parse_file(path)
  if not notebook then
    return false, "Could not parse notebook"
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cells = M.from_buffer(lines)
  local marker = config.cell_marker

  for i, cell in ipairs(notebook.cells) do
    if cell.cell_type == "code" and cells[i] then
      local exec_count = nil
      local outputs = {}

      for j, line in ipairs(lines) do
        if vim.trim(line):find("^" .. vim.pesc(marker)) and j > (i == 1 and 0 or j - 1) then
          break
        end
        local output_match = line:match("## execution_count: (%d+)")
        if output_match then
          exec_count = tonumber(output_match)
        end
      end

      cell.execution_count = exec_count or i

      local uranus_ok, uranus = pcall(require, "uranus")
      if uranus_ok then
        local result = uranus.execute(table.concat(cells[i].source, "\n"))
        if result.success and result.data then
          if result.data.execution_count then
            cell.execution_count = result.data.execution_count
          end
          if result.data.stdout or result.data.stderr then
            table.insert(outputs, {
              output_type = "stream",
              name = result.data.stderr and "stderr" or "stdout",
              text = { result.data.stdout or result.data.stderr or "" },
            })
          end
          if result.data.error then
            table.insert(outputs, {
              output_type = "error",
              ename = "Error",
              evalue = result.data.error,
              traceback = { result.data.error },
            })
          end
        end
      end

      cell.outputs = outputs
    end
  end

  return M.write_file(path, notebook)
end

function M.load_outputs(path)
  local notebook = M.parse_file(path)
  if not notebook then
    return false, "Could not parse notebook"
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local output_section = {}
  local in_output = false

  for _, line in ipairs(lines) do
    if vim.trim(line) == "## outputs:" then
      in_output = true
    elseif in_output and vim.trim(line) == "" then
      in_output = false
    elseif in_output then
      table.insert(output_section, line)
    end
  end

  return output_section
end

function M.detect_virtualenv()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  if not filepath or vim.fn.filereadable(filepath) ~= 1 then
    return nil
  end

  local dir = vim.fn.fnamemodify(filepath, ":p:h")

  while dir ~= "" and dir ~= "/" do
    local venv_path = dir .. "/.venv"
    if vim.fn.isdirectory(venv_path) == 1 then
      return venv_path
    end

    local pyvenv = dir .. "/pyvenv.toml"
    if vim.fn.filereadable(pyvenv) == 1 then
      return dir
    end

    local poetry = dir .. "/poetry.lock"
    if vim.fn.filereadable(poetry) == 1 then
      return dir
    end

    dir = vim.fn.fnamemodify(dir, ":h")
  end

  return nil
end

function M.detect_kernel()
  local venv = M.detect_virtualenv()

  if venv then
    local python = venv .. "/bin/python"
    if vim.fn.executable(python) == 1 then
      return "python3"
    end
  end

  local uranus_ok, uranus = pcall(require, "uranus")
  if uranus_ok then
    local result = uranus.list_kernels()
    if result.success and result.data and result.data.kernels then
      for _, k in ipairs(result.data.kernels) do
        if k.name == "python3" then
          return "python3"
        end
      end
      return result.data.kernels[1] and result.data.kernels[1].name
    end
  end

  return "python3"
end

M.dirty = false
M.auto_save = false

function M.is_dirty()
  return M.dirty
end

return M