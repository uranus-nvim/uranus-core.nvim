--- Uranus Notebook UI - Core initialization and state management
---
--- @module uranus.notebook.notebook_ui.init

local M = {}

local config = nil

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

local function get_config()
  if not config then
    local cfg = require("uranus.config")
    local defaults = cfg.get("notebook_ui")
    config = vim.deepcopy(defaults)
  end
  return config
end

function M.configure(opts)
  local cfg = require("uranus.config")
  local current = cfg.get("notebook_ui") or {}
  config = vim.tbl_deep_extend("force", current, opts or {})
end

function M.get_config()
  return get_config()
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

function M.get_state()
  return state
end

function M.get_ns()
  return {
    notebook = ns_notebook,
    output = ns_output,
    border = ns_border,
    codelens = ns_codelens,
    hover = ns_hover,
  }
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

  return cells
end

function M.open(path)
  if not path then
    return false, "No path provided"
  end

  local data = M.parse_file(path)
  if not data then
    return false, "Failed to parse file"
  end

  state.filepath = path
  state.notebook = data

  vim.cmd("edit " .. path)

  state.bufnr = vim.api.nvim_get_current_buf()
  state.cells = M.parse_cells(state.bufnr)

  return true
end

function M.close()
  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    vim.api.nvim_buf_delete(state.bufnr, { force = true })
  end
  if state.shadow_bufnr and vim.api.nvim_buf_is_valid(state.shadow_bufnr) then
    vim.api.nvim_buf_delete(state.shadow_bufnr, { force = true })
  end
  state.bufnr = nil
  state.shadow_bufnr = nil
  state.filepath = nil
  state.notebook = nil
end

function M.save()
  if not state.filepath or not state.notebook then
    return false, "No notebook open"
  end

  return M.write_file(state.filepath, state.notebook)
end

function M.goto_cell(idx)
  if idx < 1 or idx > #state.cells then
    return false, "Invalid cell index"
  end

  state.current_cell = idx
  local cell = state.cells[idx]
  if cell and cell.start then
    vim.api.nvim_win_set_cursor(0, { cell.start + 1, 0 })
  end

  return true
end

function M.next_cell()
  if state.current_cell < #state.cells then
    state.current_cell = state.current_cell + 1
    return M.goto_cell(state.current_cell)
  end
  return false
end

function M.prev_cell()
  if state.current_cell > 1 then
    state.current_cell = state.current_cell - 1
    return M.goto_cell(state.current_cell)
  end
  return false
end

function M.enter_cell_mode()
  if state.current_cell > #state.cells then
    return false, "No cell to edit"
  end

  state.mode = "cell"
  return true
end

function M.exit_cell_mode()
  state.mode = "notebook"
  return true
end

return M