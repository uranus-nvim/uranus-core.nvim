--- Uranus Notebook UI - Cell execution
---
--- @module uranus.notebook.notebook_ui.execution

local M = {}

local async_enabled = false
local parallel_enabled = false
local max_parallel = 4
local stop_requested = false

local function get_init()
  local ok, init = pcall(require, "uranus.notebook.notebook_ui.init")
  return ok and init or nil
end

local function get_uranus()
  local ok, uranus = pcall(require, "uranus")
  return ok and uranus or nil
end

local function get_cells()
  local init = get_init()
  if not init then
    return nil
  end
  return init.get_state().cells
end

function M.execute_cell()
  local init = get_init()
  if not init then
    return false, "notebook_ui.init not loaded"
  end

  local state = init.get_state()
  local cells = state.cells

  if state.current_cell > #cells then
    return false, "No cell at current index"
  end

  local cell = cells[state.current_cell]
  if cell.cell_type ~= "code" then
    return false, "Cannot execute markdown cell"
  end

  local uranus = get_uranus()
  if not uranus then
    return false, "Uranus backend not loaded"
  end

  local code = table.concat(cell.source, "\n")
  if #code == 0 then
    return false, "Cell is empty"
  end

  local result = uranus.execute(code)
  if result and result.success then
    cell.execution_count = result.execution_count
  end

  return result
end

function M.execute_and_next()
  local result = M.execute_cell()
  if result and result.success then
    local init = get_init()
    if init then
      init.next_cell()
    end
  end
  return result
end

function M.run_all_async(callback)
  local init = get_init()
  if not init then
    return false, "notebook_ui.init not loaded"
  end

  local state = init.get_state()
  local cells = state.cells

  local code_cells = {}
  for i, cell in ipairs(cells) do
    if cell.cell_type == "code" then
      table.insert(code_cells, i)
    end
  end

  if #code_cells == 0 then
    return false, "No code cells to execute"
  end

  local uranus = get_uranus()
  if not uranus then
    return false, "Uranus backend not loaded"
  end

  local function run_sequential(idx)
    if idx > #code_cells then
      if callback then
        callback(true)
      end
      return
    end

    local cell_idx = code_cells[idx]
    local cell = cells[cell_idx]
    local code = table.concat(cell.source, "\n")

    local result = uranus.execute(code)
    if result and result.success then
      cell.execution_count = result.execution_count
    end

    vim.defer_fn(function()
      run_sequential(idx + 1)
    end, 10)
  end

  run_sequential(1)
  return true
end

function M.run_all_parallel()
  local init = get_init()
  if not init then
    return false, "notebook_ui.init not loaded"
  end

  local state = init.get_state()
  local cells = state.cells

  local code_cells = {}
  for i, cell in ipairs(cells) do
    if cell.cell_type == "code" then
      table.insert(code_cells, i)
    end
  end

  if #code_cells == 0 then
    return false, "No code cells to execute"
  end

  local uranus = get_uranus()
  if not uranus then
    return false, "Uranus backend not loaded"
  end

  local concurrency = math.min(max_parallel, #code_cells)
  local active = 0
  local idx = 1

  local function spawn()
    while active < concurrency and idx <= #code_cells do
      local cell_idx = code_cells[idx]
      local cell = cells[cell_idx]
      local code = table.concat(cell.source, "\n")

      active = active + 1
      local current_idx = idx

      vim.defer_fn(function()
        local result = uranus.execute(code)
        if result and result.success then
          cell.execution_count = result.execution_count
        end
        active = active - 1

        if current_idx < #code_cells then
          idx = idx + 1
          spawn()
        end
      end, 0)

      idx = idx + 1
    end
  end

  spawn()
  return true
end

function M.stop_execution()
  stop_requested = true
  local uranus = get_uranus()
  if uranus and uranus.interrupt then
    uranus.interrupt()
  end
  return true
end

function M.toggle_async_mode()
  async_enabled = not async_enabled
  return async_enabled
end

function M.toggle_parallel_mode()
  parallel_enabled = not parallel_enabled
  return parallel_enabled
end

function M.set_max_parallel(n)
  max_parallel = n or 4
end

function M.is_async_enabled()
  return async_enabled
end

function M.is_parallel_enabled()
  return parallel_enabled
end

return M