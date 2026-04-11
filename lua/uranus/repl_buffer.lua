--- Uranus embedded REPL buffer
--- Displays a dedicated output window with streaming and history
---
--- @module uranus.repl_buffer

local M = {}

local config = {
  position = "right",
  width = 80,
  height = 20,
  streaming = true,
  auto_scroll = true,
  show_history = true,
}

local repl_bufnr = nil
local repl_winid = nil
local current_kernel = nil

local ns_repl = vim.api.nvim_create_namespace("uranus_repl")

local function get_uranus()
  local ok, uranus = pcall(require, "uranus")
  return ok and uranus or nil
end

function M.configure(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
end

function M.get_config()
  return config
end

--- Open REPL buffer window
function M.open()
  if repl_bufnr and vim.api.nvim_buf_is_valid(repl_bufnr) then
    if repl_winid and vim.api.nvim_win_is_valid(repl_winid) then
      vim.api.nvim_set_current_win(repl_winid)
      return
    end
  end

  local width = config.width > 0 and config.width or vim.o.columns / 3
  if config.position == "right" then
    width = vim.o.columns - width
  end

  repl_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(repl_bufnr, "Uranus REPL")
  
  local opts = {
    relative = "editor",
    width = width,
    height = config.height,
    row = 1,
    col = config.position == "right" and (vim.o.columns - width - 1) or 0,
    style = "minimal",
    border = "rounded",
    title = "⬢ REPL",
    title_pos = "left",
  }

  repl_winid = vim.api.nvim_open_win(repl_bufnr, true, opts)
  vim.wo[repl_winid].wrap = true
  vim.wo[repl_winid].spell = false
  vim.wo[repl_winid].signcolumn = "no"
  vim.wo[repl_winid].foldcolumn = "0"

  vim.bo[repl_bufnr].filetype = "uranus-repl"
  vim.bo[repl_bufnr].bufhidden = "hide"

  M.write_welcome()
end

--- Write welcome message
function M.write_welcome()
  if not repl_bufnr then return end
  local lines = {
    string.rep("═", 40),
    "  Uranus REPL",
    "  Press ENTER to activate, q to close",
    string.rep("═", 40),
    "",
  }
  vim.api.nvim_buf_set_lines(repl_bufnr, 0, -1, false, lines)
end

--- Close REPL buffer
function M.close()
  if repl_winid and vim.api.nvim_win_is_valid(repl_winid) then
    vim.api.nvim_win_close(repl_winid, true)
    repl_winid = nil
  end
end

--- Toggle REPL buffer
function M.toggle()
  if repl_winid and vim.api.nvim_win_is_valid(repl_winid) then
    M.close()
  else
    M.open()
  end
end

--- Clear REPL buffer
function M.clear()
  if not repl_bufnr then return end
  vim.api.nvim_buf_set_lines(repl_bufnr, 0, -1, false, {})
end

--- Write output to REPL buffer
--- @param text string Output text
--- @param type string Type: "stdout" | "stderr" | "result" | "input"
function M.write(text, typ)
  if not repl_bufnr then
    M.open()
  end

  local line = vim.api.nvim_buf_line_count(repl_bufnr)
  local prefix = ""
  local highlight = "UranusOutput"

  if typ == "stderr" then
    prefix = "ERR | "
    highlight = "UranusError"
  elseif typ == "result" then
    prefix = ">>> "
    highlight = "UranusResult"
  elseif typ == "input" then
    prefix = "<<< "
    highlight = "UranusInput"
  else
    prefix = "   "
  end

  local lines = vim.split(text, "\n", { trimempty = true })
  for i, l in ipairs(lines) do
    local text_line = prefix .. l
    vim.api.nvim_buf_set_lines(repl_bufnr, line + i - 1, line + i, false, { text_line })
    vim.api.nvim_buf_add_highlight(repl_bufnr, ns_repl, highlight, line + i - 1, 0, -1)
  end

  if config.auto_scroll and repl_winid then
    local win_height = vim.api.nvim_win_get_height(repl_winid)
    vim.api.nvim_win_set_cursor(repl_winid, { vim.api.nvim_buf_line_count(repl_bufnr), 0 })
  end
end

--- Write execution count
--- @param count number Execution count
function M.write_execution(count)
  if not repl_bufnr then return end
  local line = vim.api.nvim_buf_line_count(repl_bufnr) + 1
  local prefix = "─── [" .. tostring(count) .. "] "
  vim.api.nvim_buf_set_lines(repl_bufnr, line, line + 1, false, { prefix .. string.rep("═", 30) })
end

--- Execute code in REPL context
--- @param code string Code to execute
--- @return table Execution result
function M.execute(code)
  local u = get_uranus()
  if not u then
    M.write("Uranus not available", "stderr")
    return { success = false, error = "no backend" }
  end

  M.open()
  M.write(code, "input")

  local status = u.status()
  local exec_count = status.data and status.data.execution_count or 0
  M.write_execution(exec_count + 1)

  local result = u.execute(code)

  if result.success and result.data then
    local data = result.data

    if data.stdout then
      M.write(data.stdout, "stdout")
    end

    if data.stderr then
      M.write(data.stderr, "stderr")
    end

    if data.error then
      M.write(data.error, "stderr")
    end

    if data.data and next(data.data) then
      for mime, content in pairs(data.data) do
        if mime == "text/plain" then
          M.write(content, "result")
        end
      end
    end
  elseif result.error then
    M.write(result.error.message or "Execution failed", "stderr")
  end

  return result
end

--- Execute current cell
--- @return table Execution result
function M.execute_cell()
  local notebook = nil
  local ok, nb = pcall(require, "uranus.notebook")
  if ok then
    notebook = nb
  end

  local cell = notebook and notebook.get_current_cell()
  local code = nil

  if cell then
    code = table.concat(cell.source, "\n")
  else
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    code = table.concat(lines, "\n")
  end

  return M.execute(code)
end

--- Add keymaps for REPL buffer
function M.setup_keymaps()
  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = repl_bufnr, silent = true })

  vim.keymap.set("n", "<cr>", function()
    M.execute_cell()
  end, { buffer = repl_bufnr, silent = true })

  vim.keymap.set("n", "r", function()
    M.execute_cell()
  end, { buffer = repl_bufnr, silent = true })

  vim.keymap.set("n", "c", function()
    M.clear()
  end, { buffer = repl_bufnr, silent = true })
end

return M