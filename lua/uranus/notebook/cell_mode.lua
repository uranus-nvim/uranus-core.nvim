--- Uranus modal cell editing
--- Focus on one cell at a time in isolated buffer
---
--- @module uranus.cell_mode

local M = {}

local config = nil

local function get_config()
  if not config then
    config = {
      auto_enter = true,
      show_cell_bar = true,
      cell_marker = "#%%",
    }
  end
  return config
end

local ns_cell = vim.api.nvim_create_namespace("uranus_cell_mode")
local original_bufnr = nil
local cell_bufnr = nil
local cell_winid = nil
local current_cell_index = 1

local function get_notebook()
  local ok, nb = pcall(require, "uranus.notebook")
  return ok and nb or nil
end

function M.configure(opts)
  config = vim.tbl_deep_extend("force", get_config(), opts or {})
end

function M.get_config()
  return get_config()
end

--- Get all cells from current notebook buffer
--- @return table Array of cells
function M.get_cells()
  local bufnr = original_bufnr or vim.api.nvim_get_current_buf()
  local notebook = get_notebook()
  if notebook and notebook.parse_cells then
    return notebook.parse_cells(bufnr)
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cells = {}
  local current_cell = nil
  local marker = config.cell_marker

  for i, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed:find("^" .. vim.pesc(marker)) then
      if current_cell then
        table.insert(cells, current_cell)
      end
      current_cell = {
        start = i - 1,
        text = {},
      }
    elseif current_cell then
      table.insert(current_cell.text, line)
    end
  end

  if current_cell and #current_cell.text > 0 then
    table.insert(cells, current_cell)
  end

  return cells
end

--- Enter cell mode for current cell
function M.enter_cell_mode()
  original_bufnr = original_bufnr or vim.api.nvim_get_current_buf()
  local cells = M.get_cells()

  if #cells == 0 then
    vim.notify("No cells found", vim.log.levels.WARN)
    return
  end

  local cell_idx = current_cell_index or 1
  if cell_idx > #cells then
    cell_idx = #cells
  end

  local cell = cells[cell_idx]
  if not cell then
    return
  end

  cell_bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(cell_bufnr, "Uranus Cell " .. cell_idx)
  vim.api.nvim_buf_set_lines(cell_bufnr, 0, -1, false, cell.text)

  vim.api.nvim_buf_set_option(cell_bufnr, "filetype", "python")
  vim.api.nvim_buf_set_option(cell_bufnr, "modifiable", true)

  local width = vim.o.columns - 20
  local height = math.min(#cell.text + 4, vim.o.lines - 10)
  local row = (vim.o.lines - height) / 2

  cell_winid = vim.api.nvim_open_win(cell_bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor(row),
    col = 10,
    style = "minimal",
    border = "rounded",
    title = "📝 Cell " .. cell_idx .. "/" .. #cells,
    title_pos = "center",
  })

  vim.wo[cell_winid].wrap = true
  vim.wo[cell_winid].number = true
  vim.wo[cell_winid].relativenumber = true

  M.setup_cell_keymaps(cell_idx, #cells)
end

--- Setup keymaps for cell mode
function M.setup_cell_keymaps(cell_idx, total_cells)
  local opts = { buffer = cell_bufnr, silent = true, noremap = true }

  vim.keymap.set("n", "<esc>", function()
    M.exit_cell_mode()
  end, opts)

  vim.keymap.set("n", "<cr>", function()
    M.run_cell()
  end, opts)

  vim.keymap.set("n", "q", function()
    M.exit_cell_mode()
  end, opts)

  vim.keymap.set("n", "j", function()
    if cell_idx < total_cells then
      M.goto_cell(cell_idx + 1)
    end
  end, opts)

  vim.keymap.set("n", "k", function()
    if cell_idx > 1 then
      M.goto_cell(cell_idx - 1)
    end
  end, opts)

  vim.keymap.set("n", "gg", function()
    M.goto_cell(1)
  end, opts)

  vim.keymap.set("n", "G", function()
    M.goto_cell(total_cells)
  end, opts)

  vim.keymap.set("n", "w", function()
    M.save_cell()
  end, opts)
end

--- Save cell changes back to notebook
function M.save_cell()
  if not cell_bufnr or not original_bufnr then
    return
  end

  local cells = M.get_cells()
  local new_text = vim.api.nvim_buf_get_lines(cell_bufnr, 0, -1, false)

  if current_cell_index and current_cell_index <= #cells then
    cells[current_cell_index].text = new_text
  end

  local lines = {}
  local marker = config.cell_marker

  for _, cell in ipairs(cells) do
    table.insert(lines, marker)
    vim.list_extend(lines, cell.text)
    table.insert(lines, "")
  end

  vim.api.nvim_buf_set_lines(original_bufnr, 0, -1, false, lines)
  vim.notify("Cell saved", vim.log.levels.INFO)
end

--- Run current cell
function M.run_cell()
  local u = nil
  local ok, uranus = pcall(require, "uranus")
  if ok then
    u = uranus
  end

  if not u then
    vim.notify("Uranus not available", vim.log.levels.ERROR)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(cell_bufnr, 0, -1, false)
  local code = table.concat(lines, "\n")

  vim.notify("Running cell...", vim.log.levels.INFO)

  local result = u.execute(code)

  if result.success and result.data then
    local data = result.data
    local output_lines = {}

    if data.stdout then
      vim.list_extend(output_lines, vim.split(data.stdout, "\n"))
    end

    if data.error then
      vim.list_extend(output_lines, { "ERROR: " .. data.error })
    end

    if #output_lines > 0 then
      local out_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(out_bufnr, 0, -1, false, output_lines)
      vim.api.nvim_open_win(out_bufnr, true, {
        relative = "cell",
        width = vim.o.columns / 2,
        height = math.min(#output_lines + 2, vim.o.lines / 3),
        row = vim.api.nvim_win_get_position(cell_winid)[1] - #output_lines - 2,
        col = vim.o.columns / 4,
        style = "minimal",
        border = "rounded",
      })
    end
  end
end

--- Go to specific cell
function M.goto_cell(index)
  M.save_cell()

  local cells = M.get_cells()
  if index < 1 or index > #cells then
    return
  end

  current_cell_index = index

  local cell = cells[index]
  if not cell then
    return
  end

  vim.api.nvim_buf_set_lines(cell_bufnr, 0, -1, false, cell.text)
  vim.api.nvim_win_set_cursor(cell_winid, { 1, 0 })

  local title = "📝 Cell " .. index .. "/" .. #cells
  vim.api.nvim_win_set_config(cell_winid, { title = title })
end

--- Exit cell mode
function M.exit_cell_mode()
  if cell_winid and vim.api.nvim_win_is_valid(cell_winid) then
    vim.api.nvim_win_close(cell_winid, true)
  end

  if cell_bufnr and vim.api.nvim_buf_is_valid(cell_bufnr) then
    vim.api.nvim_buf_delete(cell_bufnr, { force = true })
  end

  cell_bufnr = nil
  cell_winid = nil

  vim.api.nvim_set_current_buf(original_bufnr)
  original_bufnr = nil
end

--- Toggle cell mode
function M.toggle_cell_mode()
  if cell_bufnr and vim.api.nvim_buf_is_valid(cell_bufnr) then
    M.exit_cell_mode()
  else
    M.enter_cell_mode()
  end
end

return M