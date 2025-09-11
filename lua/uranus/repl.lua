--- Uranus REPL / Cell mode
---
--- Provides cell-based code execution with markers, selection execution,
--- and interactive REPL functionality.
---
--- @module uranus.repl
--- @license MIT

local M = {}

---@class UranusCell
---@field start_line number 0-based start line
---@field end_line number 0-based end line
---@field code string Cell code content
---@field output? UranusExecutionResult Cell execution result
---@field marker string Cell marker used

---@class UranusCellExecutionOptions
---@field kernel_id? string Specific kernel to use
---@field silent? boolean Suppress notifications
---@field on_result? fun(result: UranusExecutionResult) Result callback
---@field on_error? fun(error: UranusError) Error callback

--- Module state
---@type table<number, UranusCell[]>
M.buffer_cells = {}

---@type table<number, number>
M.current_cell = {}

--- Initialize REPL functionality
---@param config UranusConfig Uranus configuration
---@return UranusResult
function M.init(config)
  M.config = config

  -- Set up REPL-specific autocommands
  M._setup_autocommands()

  -- Set up syntax highlighting for cell markers
  M._setup_syntax()

  return M.ok(true)
end

--- Parse cells in the current buffer
---@param bufnr? number Buffer number (default: current)
---@return UranusResult<UranusCell[]>
function M.parse_cells(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return M.err("INVALID_BUFFER", "Buffer is not valid")
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cells = {}
  local current_cell = nil
  local marker = M.config.cell.marker

  for i, line in ipairs(lines) do
    -- Check if line contains cell marker
    if line:find(marker, 1, true) then
      -- End previous cell
      if current_cell then
        current_cell.end_line = i - 2 -- Previous line
        table.insert(cells, current_cell)
      end

      -- Start new cell
      current_cell = {
        start_line = i, -- Line after marker
        code = "",
        marker = marker,
      }
    elseif current_cell then
      -- Add line to current cell
      if current_cell.code ~= "" then
        current_cell.code = current_cell.code .. "\n"
      end
      current_cell.code = current_cell.code .. line
    elseif not current_cell and line ~= "" then
      -- Start first cell if we haven't found a marker yet
      current_cell = {
        start_line = i - 1, -- 0-based line number
        code = line,
        marker = nil, -- No marker for first cell
      }
    end
  end

  -- Add final cell
  if current_cell then
    current_cell.end_line = #lines - 1
    table.insert(cells, current_cell)
  end

  -- Cache cells for this buffer
  M.buffer_cells[bufnr] = cells

  return M.ok(cells)
end

--- Get cell at cursor position
---@param bufnr? number Buffer number (default: current)
---@return UranusResult<UranusCell>
function M.get_current_cell(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local cells_result = M.parse_cells(bufnr)
  if not cells_result.success then
    return cells_result
  end

  local cells = cells_result.data
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1 -- 0-based

  for _, cell in ipairs(cells) do
    if cursor_line >= cell.start_line and cursor_line <= cell.end_line then
      return M.ok(cell)
    end
  end

  return M.err("NO_CELL", "No cell found at cursor position")
end

--- Execute the current cell
---@param opts? UranusCellExecutionOptions Execution options
---@return UranusResult<UranusExecutionResult>
function M.run_cell(opts)
  opts = opts or {}

  local cell_result = M.get_current_cell()
  if not cell_result.success then
    return cell_result
  end

  local cell = cell_result.data

  -- Trim whitespace from code
  cell.code = vim.trim(cell.code)

  if cell.code == "" then
    return M.err("EMPTY_CELL", "Cell is empty")
  end

  return M.execute_cell(cell, opts)
end

--- Execute a specific cell
---@param cell UranusCell Cell to execute
---@param opts? UranusCellExecutionOptions Execution options
---@return UranusResult<UranusExecutionResult>
function M.execute_cell(cell, opts)
  opts = opts or {}

  -- Check if kernel is available
  local kernel = require("uranus.kernel")
  if not kernel.current_kernel then
    return M.err("NO_KERNEL", "No kernel connected")
  end

  -- Execute code
  local result = kernel.execute(cell.code, {
    kernel_id = opts.kernel_id,
    silent = opts.silent,
  })

  if not result.success then
    if opts.on_error then
      opts.on_error(result.error)
    elseif not opts.silent then
      vim.notify("Cell execution failed: " .. result.error.message, vim.log.levels.ERROR)
    end
    return result
  end

  -- Store result in cell
  cell.output = result.data

  -- Handle result display
  if result.data then
    M._handle_execution_result(cell, result.data, opts)
  end

  if opts.on_result then
    opts.on_result(result.data)
  end

  return result
end

--- Execute all cells in the buffer
---@param opts? UranusCellExecutionOptions Execution options
---@return UranusResult<UranusExecutionResult[]>
function M.run_all(opts)
  opts = opts or {}

  local cells_result = M.parse_cells()
  if not cells_result.success then
    return cells_result
  end

  local cells = cells_result.data
  local results = {}

  for i, cell in ipairs(cells) do
    if not opts.silent then
      vim.notify("Executing cell " .. i .. "/" .. #cells, vim.log.levels.INFO)
    end

    local result = M.execute_cell(cell, opts)
    table.insert(results, result)

    -- Stop on first error unless configured otherwise
    if not result.success and not M.config.cell.continue_on_error then
      break
    end
  end

  return M.ok(results)
end

--- Execute visual selection
---@param opts? UranusCellExecutionOptions Execution options
---@return UranusResult<UranusExecutionResult>
function M.run_selection(opts)
  opts = opts or {}

  -- Get visual selection
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line = start_pos[2] - 1 -- 0-based
  local end_line = end_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_col = end_pos[3] - 1

  -- Get selected lines
  local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line + 1, false)

  -- Handle partial first and last lines
  if #lines > 0 then
    lines[1] = lines[1]:sub(start_col + 1)
    if #lines > 1 then
      lines[#lines] = lines[#lines]:sub(1, end_col)
    end
  end

  local code = table.concat(lines, "\n")

  if code == "" then
    return M.err("EMPTY_SELECTION", "No code selected")
  end

  -- Execute code
  local kernel = require("uranus.kernel")
  local result = kernel.execute(code, {
    kernel_id = opts.kernel_id,
    silent = opts.silent,
  })

  if result.success and result.data then
    M._handle_execution_result({
      start_line = start_line,
      end_line = end_line,
      code = code,
    }, result.data, opts)
  end

  return result
end

--- Execute from cursor to end of buffer
---@param opts? UranusCellExecutionOptions Execution options
---@return UranusResult<UranusExecutionResult>
function M.run_to_cursor(opts)
  opts = opts or {}

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local lines = vim.api.nvim_buf_get_lines(0, cursor_line, -1, false)

  local code = table.concat(lines, "\n")

  if code == "" then
    return M.err("EMPTY_CODE", "No code from cursor to end")
  end

  -- Execute code
  local kernel = require("uranus.kernel")
  local result = kernel.execute(code, {
    kernel_id = opts.kernel_id,
    silent = opts.silent,
  })

  if result.success and result.data then
    M._handle_execution_result({
      start_line = cursor_line,
      end_line = vim.api.nvim_buf_line_count(0) - 1,
      code = code,
    }, result.data, opts)
  end

  return result
end

--- Navigate to next cell
---@return UranusResult
function M.next_cell()
  local cells_result = M.parse_cells()
  if not cells_result.success then
    return cells_result
  end

  local cells = cells_result.data
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

  for i, cell in ipairs(cells) do
    if cursor_line < cell.start_line then
      -- Move cursor to start of cell
      vim.api.nvim_win_set_cursor(0, { cell.start_line + 1, 0 })
      M.current_cell[vim.api.nvim_get_current_buf()] = i
      return M.ok(true)
    end
  end

  return M.err("NO_NEXT_CELL", "No next cell found")
end

--- Navigate to previous cell
---@return UranusResult
function M.prev_cell()
  local cells_result = M.parse_cells()
  if not cells_result.success then
    return cells_result
  end

  local cells = cells_result.data
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1

  for i = #cells, 1, -1 do
    local cell = cells[i]
    if cursor_line > cell.start_line then
      -- Move cursor to start of cell
      vim.api.nvim_win_set_cursor(0, { cell.start_line + 1, 0 })
      M.current_cell[vim.api.nvim_get_current_buf()] = i
      return M.ok(true)
    end
  end

  return M.err("NO_PREV_CELL", "No previous cell found")
end

--- Insert cell marker at cursor
---@param marker? string Cell marker (default: configured marker)
---@return UranusResult
function M.insert_cell_marker(marker)
  marker = marker or M.config.cell.marker

  local line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, line - 1, line - 1, false, { marker, "" })

  -- Move cursor to next line
  vim.api.nvim_win_set_cursor(0, { line + 1, 0 })

  return M.ok(true)
end

--- Clear all cell outputs
---@param bufnr? number Buffer number (default: current)
---@return UranusResult
function M.clear_outputs(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local cells = M.buffer_cells[bufnr]
  if not cells then
    return M.ok(true) -- No cells to clear
  end

  for _, cell in ipairs(cells) do
    cell.output = nil
  end

  -- Clear UI outputs
  local ui = require("uranus.ui")
  ui.close_all()

  return M.ok(true)
end

--- Handle execution result display
---@param cell UranusCell Cell that was executed
---@param result UranusExecutionResult Execution result
---@param opts UranusCellExecutionOptions Execution options
function M._handle_execution_result(cell, result, opts)
  -- Display output based on configuration
  local ui = require("uranus.ui")
  local output = require("uranus.output")

  -- Format result for display
  local display_content = output.format_result(result)

  if display_content then
    ui.display(display_content, {
      mode = M.config.ui.repl.view,
      title = "Cell Output",
      autoclose = not opts.persistent,
    })
  end

  -- Show success/error messages
  if not opts.silent then
    if result.success then
      vim.notify("Cell executed successfully", vim.log.levels.INFO)
    else
      vim.notify("Cell execution failed", vim.log.levels.ERROR)
    end
  end
end

--- Set up REPL autocommands
function M._setup_autocommands()
  local augroup = vim.api.nvim_create_augroup("UranusREPL", { clear = true })

  -- Re-parse cells when buffer changes
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = augroup,
    callback = function(args)
      -- Debounce cell parsing
      if M._parse_timer then
        vim.fn.timer_stop(M._parse_timer)
      end

      M._parse_timer = vim.fn.timer_start(500, function()
        M.parse_cells(args.buf)
        M._parse_timer = nil
      end)
    end,
  })

  -- Clear cell cache when buffer is unloaded
  vim.api.nvim_create_autocmd("BufUnload", {
    group = augroup,
    callback = function(args)
      M.buffer_cells[args.buf] = nil
      M.current_cell[args.buf] = nil
    end,
  })
end

--- Set up syntax highlighting for cell markers
function M._setup_syntax()
  -- Add syntax highlighting for cell markers
  vim.cmd([[
    highlight default link UranusCellMarker Comment
  ]])

  -- Set up syntax matching
  local marker = M.config.cell.marker:gsub("([^%w])", "%%%1") -- Escape special chars
  vim.cmd(string.format([[
    syntax match UranusCellMarker /^%s/
    highlight default link UranusCellMarker SpecialComment
  ]], marker))
end

--- Get REPL statistics
---@return table REPL statistics
function M.stats()
  local bufnr = vim.api.nvim_get_current_buf()
  local cells = M.buffer_cells[bufnr] or {}

  return {
    total_cells = #cells,
    current_cell = M.current_cell[bufnr],
    buffer_cells_cached = vim.tbl_count(M.buffer_cells),
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