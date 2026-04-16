--- Uranus Notebook UI - Cell operations
---
--- @module uranus.notebook.notebook_ui.cells

local M = {}

local function get_init()
  local ok, init = pcall(require, "uranus.notebook.notebook_ui.init")
  return ok and init or nil
end

function M.add_cell_below()
  local init = get_init()
  if not init then
    return false, "notebook_ui.init not loaded"
  end

  local state = init.get_state()
  local cells = state.cells
  local current = state.current_cell

  local new_idx = current + 1
  table.insert(cells, new_idx, {
    start = 0,
    cell_type = "code",
    source = {},
  })

  state.current_cell = new_idx
  return true
end

function M.add_cell_above()
  local init = get_init()
  if not init then
    return false, "notebook_ui.init not loaded"
  end

  local state = init.get_state()
  local cells = state.cells
  local current = state.current_cell

  table.insert(cells, current, {
    start = 0,
    cell_type = "code",
    source = {},
  })

  return true
end

function M.delete_cell()
  local init = get_init()
  if not init then
    return false, "notebook_ui.init not loaded"
  end

  local state = init.get_state()
  local cells = state.cells

  if #cells == 0 then
    return false, "No cells to delete"
  end

  table.remove(cells, state.current_cell)

  if state.current_cell > #cells then
    state.current_cell = #cells
  end

  return true
end

function M.toggle_cell_type()
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
  if cell.cell_type == "code" then
    cell.cell_type = "markdown"
  else
    cell.cell_type = "code"
  end

  return true
end

function M.move_cell_up()
  local init = get_init()
  if not init then
    return false, "notebook_ui.init not loaded"
  end

  local state = init.get_state()
  local cells = state.cells

  if state.current_cell <= 1 then
    return false, "Already at top"
  end

  local current = state.current_cell
  cells[current - 1], cells[current] = cells[current], cells[current - 1]
  state.current_cell = current - 1

  return true
end

function M.move_cell_down()
  local init = get_init()
  if not init then
    return false, "notebook_ui.init not loaded"
  end

  local state = init.get_state()
  local cells = state.cells

  if state.current_cell >= #cells then
    return false, "Already at bottom"
  end

  local current = state.current_cell
  cells[current], cells[current + 1] = cells[current + 1], cells[current]
  state.current_cell = current + 1

  return true
end

function M.get_current_cell()
  local init = get_init()
  if not init then
    return nil
  end

  local state = init.get_state()
  local cells = state.cells

  return cells[state.current_cell]
end

function M.set_cell_source(idx, source)
  local init = get_init()
  if not init then
    return false
  end

  local state = init.get_state()
  local cells = state.cells

  if idx < 1 or idx > #cells then
    return false
  end

  cells[idx].source = source
  return true
end

function M.get_cell_source(idx)
  local init = get_init()
  if not init then
    return nil
  end

  local state = init.get_state()
  local cells = state.cells

  if idx < 1 or idx > #cells then
    return nil
  end

  return cells[idx].source
end

function M.set_cell_output(idx, output)
  local init = get_init()
  if not init then
    return false
  end

  local state = init.get_state()
  local cells = state.cells

  if idx < 1 or idx > #cells then
    return false
  end

  cells[idx].outputs = output
  return true
end

function M.get_cell_output(idx)
  local init = get_init()
  if not init then
    return nil
  end

  local state = init.get_state()
  local cells = state.cells

  if idx < 1 or idx > #cells then
    return nil
  end

  return cells[idx].outputs
end

return M