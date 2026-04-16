--- Uranus REPL module
--- Handles cell-based code execution with visual cell markers
---
--- @module uranus.repl

local M = {}

local config = nil

local function get_config()
  if not config then
    local cfg = require("uranus.config")
    local defaults = cfg.get("repl")
    config = vim.deepcopy(defaults)
  end
  return config
end

local ns_cell = vim.api.nvim_create_namespace("uranus_cell")
local ns_output = vim.api.nvim_create_namespace("uranus_output")

local uranus = nil
local output_module = nil

local cell_cache = {}
local cell_cache_time = 0
local cell_cache_ttl = 2000
local cell_cache_bufnr = nil

local debounce_timers = {}

local function get_uranus()
  if not uranus then
    uranus = require("uranus")
  end
  return uranus
end

local function get_output()
  if not output_module then
    output_module = require("uranus.output")
  end
  return output_module
end

function M.configure(opts)
  local cfg = require("uranus.config")
  local current = cfg.get("repl") or {}
  config = vim.tbl_deep_extend("force", current, opts or {})
end

function M.get_config()
  return get_config()
end

local function invalidate_cell_cache(bufnr)
  if cell_cache_bufnr == bufnr then
    cell_cache_bufnr = nil
    cell_cache = {}
  end
end

function M.invalidate_cache()
  cell_cache_bufnr = nil
  cell_cache = {}
end

--- Parse cells from buffer
--- @param bufnr number Buffer number (0 for current)
--- @return table Array of { start, end, text } cells
function M.parse_cells(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  local now = vim.loop.now()
  if cell_cache_bufnr == bufnr and now - cell_cache_time < cell_cache_ttl and #cell_cache > 0 then
    return cell_cache
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
      current_cell = { start = i - 1, text = {} }
    elseif current_cell then
      table.insert(current_cell.text, line)
    end
  end

  if current_cell and #current_cell.text > 0 then
    table.insert(cells, current_cell)
  end

  cell_cache = cells
  cell_cache_time = now
  cell_cache_bufnr = bufnr
  
  return cells
end

--- Mark cells in buffer with extmarks
--- @param bufnr number Buffer number
function M.mark_cells(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns_cell, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local marker = config.cell_marker

  for i, line in ipairs(lines) do
    if vim.trim(line):find("^" .. vim.pesc(marker)) then
      vim.api.nvim_buf_set_extmark(bufnr, ns_cell, i - 1, 0, {
        sign_text = " ",
        sign_hl_group = "UranusCell",
        hl_group = "UranusCell",
        ephemeral = false,
      })
    end
  end
end

--- Get cell at cursor position
--- @param bufnr number Buffer number
--- @return table|nil Cell at cursor
function M.get_cell_at_cursor(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_buf_get_mark(bufnr, ".")
  local cells = M.parse_cells(bufnr)

  for _, cell in ipairs(cells) do
    if cell.start <= cursor[1] then
      return cell
    end
  end

  return cells[#cells]
end

--- Run a single cell
--- @param cell table Cell with start and text
--- @param bufnr number Buffer number
--- @return table Execution result
function M.run_cell(cell, bufnr)
  local u = get_uranus()
  local text = table.concat(cell.text, "\n")

  if config.show_outputs and config.output_method == "virtual_text" then
    local line = cell.start + #cell.text - 1
    local result = u.execute(text)

    if result.success and result.data then
      local out = get_output()
      out.display_virtual_text(bufnr, line, result.data.stdout or result.data.result or "", false)
    end

    return result
  end

  return u.execute(text)
end

--- Run all cells in buffer
--- @param bufnr number Buffer number
--- @return table Array of results
function M.run_all(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cells = M.parse_cells(bufnr)
  local results = {}

  for _, cell in ipairs(cells) do
    local result = M.run_cell(cell, bufnr)
    table.insert(results, result)
  end

  return results
end

--- Run cells asynchronously (sequential)
--- @param bufnr number Buffer number
--- @param callback function Callback for each result
function M.run_all_async(bufnr, callback)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cells = M.parse_cells(bufnr)
  
  local index = 1
  local results = {}
  
  local function run_next()
    if index > #cells then
      if callback then
        callback(results)
      end
      return
    end
    
    local cell = cells[index]
    local result = M.run_cell(cell, bufnr)
    table.insert(results, result)
    
    if callback then
      callback(result, index)
    end
    
    index = index + 1
    vim.defer_fn(run_next, 10)
  end
  
  run_next()
end

--- Run cells in parallel
--- @param bufnr number Buffer number
--- @return table Array of results
function M.run_all_parallel(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cells = M.parse_cells(bufnr)
  local results = {}
  local running = 0
  local max_parallel = config.max_parallel
  
  local function start_next()
    while #cells > 0 and running < max_parallel do
      local cell = table.remove(cells, 1)
      running = running + 1
      
      local u = get_uranus()
      local text = table.concat(cell.text, "\n")
      
      vim.defer_fn(function()
        local result = u.execute(text)
        table.insert(results, result)
        running = running - 1
        
        if #cells > 0 or running > 0 then
          start_next()
        end
      end, 10)
    end
  end
  
  start_next()
  return results
end

--- Run current cell and move to next
--- @return table Execution result
function M.run_cell_and_next()
  local bufnr = vim.api.nvim_get_current_buf()
  local cell = M.get_cell_at_cursor(bufnr)
  
  if not cell then
    return { success = false, error = { code = "NO_CELL", message = "No cell at cursor" } }
  end
  
  local result = M.run_cell(cell, bufnr)
  M.next_cell(bufnr)
  
  return result
end

--- Run current cell with interrupt support
--- @return table Execution result
function M.run_cell_interruptible()
  local bufnr = vim.api.nvim_get_current_buf()
  local cell = M.get_cell_at_cursor(bufnr)
  
  if not cell then
    return { success = false, error = { code = "NO_CELL", message = "No cell at cursor" } }
  end
  
  local u = get_uranus()
  local text = table.concat(cell.text, "\n")
  
  local done = false
  local result
  
  vim.defer_fn(function()
    if not done then
      local u = get_uranus()
      vim.cmd("UranusInterrupt")
    end
  end, 10000)
  
  result = u.execute(text)
  done = true
  
  return result
end

--- Clear all cell outputs
--- @param bufnr number Buffer number
function M.clear_outputs(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns_output, 0, -1)
end

--- Go to next cell
--- @param bufnr number Buffer number
function M.next_cell(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_buf_get_mark(bufnr, ".")
  local cells = M.parse_cells(bufnr)

  for _, cell in ipairs(cells) do
    if cell.start > cursor[1] then
      vim.api.nvim_buf_set_mark(bufnr, "'", cell.start, 0, {})
      vim.api.nvim_win_set_cursor(0, { cell.start + 1, 0 })
      return
    end
  end
end

--- Go to previous cell
--- @param bufnr number Buffer number
function M.prev_cell(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_buf_get_mark(bufnr, ".")
  local cells = M.parse_cells(bufnr)

  for i = #cells, 1, -1 do
    if cells[i].start < cursor[1] then
      vim.api.nvim_buf_set_mark(bufnr, "'", cells[i].start, 0, {})
      vim.api.nvim_win_set_cursor(0, { cells[i].start + 1, 0 })
      return
    end
  end
end

--- Insert cell marker at cursor
function M.insert_cell()
  local marker = config.cell_marker
  local line = vim.api.nvim_get_current_line()

  if vim.trim(line):find("^" .. vim.pesc(marker)) then
    return
  end

  vim.cmd(string.format("normal! O%s ", marker))
end

return M