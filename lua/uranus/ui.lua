--- Uranus UI components
---
--- Provides UI components for displaying output, managing windows,
--- and handling user interactions in different display modes.
---
--- @module uranus.ui
--- @license MIT

local M = {}

---@class UranusUIWindow
---@field buf number Buffer number
---@field win number Window number
---@field type "floating"|"split"|"virtual" Window type

---@class UranusUIOptions
---@field mode? "floating"|"virtualtext"|"terminal"|"split" Display mode
---@field width? number Window width
---@field height? number Window height
---@field row? number Window row position
---@field col? number Window column position
---@field border? string|table Border style
---@field title? string Window title
---@field autoclose? boolean Auto-close window
---@field persistent? boolean Keep window open

--- Module state
---@type table<number, UranusUIWindow>
M.windows = {}

---@type table<number, number[]>
M.virtual_text = {}

--- Initialize UI components
---@param config UranusConfig Uranus configuration
---@return UranusResult
function M.init(config)
  M.config = config

  -- Set up UI-specific autocommands
  M._setup_autocommands()

  return M.ok(true)
end

--- Display content in the configured UI mode
---@param content string Content to display
---@param opts? UranusUIOptions Display options
---@return UranusResult<UranusUIWindow>
function M.display(content, opts)
  opts = opts or {}
  local mode = opts.mode or M.config.ui.repl.view

  if mode == "floating" then
    return M.display_floating(content, opts)
  elseif mode == "virtualtext" then
    return M.display_virtual_text(content, opts)
  elseif mode == "terminal" then
    return M.display_terminal(content, opts)
  elseif mode == "split" then
    return M.display_split(content, opts)
  else
    return M.err("INVALID_MODE", "Invalid display mode: " .. mode)
  end
end

--- Display content in a floating window
---@param content string Content to display
---@param opts? UranusUIOptions Display options
---@return UranusResult<UranusUIWindow>
function M.display_floating(content, opts)
  opts = opts or {}

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  if not buf then
    return M.err("BUF_CREATE_FAILED", "Failed to create buffer")
  end

  -- Set buffer content
  local lines = vim.split(content, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)

  -- Set up keymaps
  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":close<CR>", { silent = true })

  -- Calculate window dimensions
  local width = opts.width or M.config.ui.repl.max_width or 80
  local height = opts.height or math.min(#lines, M.config.ui.repl.max_height or 20)

  -- Calculate window position
  local row = opts.row
  local col = opts.col

  if not row or not col then
    -- Auto-position based on cursor
    local cursor = vim.api.nvim_win_get_cursor(0)
    row = cursor[1] + 1
    col = cursor[2] + 1

    -- Adjust if window would go off-screen
    local screen_height = vim.api.nvim_get_option("lines")
    local screen_width = vim.api.nvim_get_option("columns")

    if row + height > screen_height then
      row = screen_height - height - 1
    end

    if col + width > screen_width then
      col = screen_width - width - 1
    end
  end

  -- Window configuration
  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = opts.border or M.config.ui.repl.border or "rounded",
    title = opts.title,
    title_pos = "center",
  }

  -- Create window
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  if not win then
    vim.api.nvim_buf_delete(buf, { force = true })
    return M.err("WIN_CREATE_FAILED", "Failed to create window")
  end

  -- Set window options
  vim.api.nvim_win_set_option(win, "wrap", true)
  vim.api.nvim_win_set_option(win, "cursorline", false)
  vim.api.nvim_win_set_option(win, "number", false)
  vim.api.nvim_win_set_option(win, "relativenumber", false)

  -- Store window reference
  local ui_window = {
    buf = buf,
    win = win,
    type = "floating",
  }

  M.windows[buf] = ui_window

  -- Set up auto-close if requested
  if opts.autoclose then
    vim.defer_fn(function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, 5000) -- Auto-close after 5 seconds
  end

  return M.ok(ui_window)
end

--- Display content as virtual text
---@param content string Content to display
---@param opts? UranusUIOptions Display options
---@return UranusResult<UranusUIWindow>
function M.display_virtual_text(content, opts)
  opts = opts or {}

  -- Get current line
  local line = opts.line or vim.api.nvim_win_get_cursor(0)[1] - 1

  -- Create namespace for virtual text
  local ns_id = vim.api.nvim_create_namespace("uranus_virtual_text")

  -- Clear existing virtual text on this line
  if M.virtual_text[line] then
    vim.api.nvim_buf_clear_namespace(0, ns_id, line, line + 1)
  end

  -- Add virtual text
  local virt_text = { { content, "Comment" } }
  local extmark_id = vim.api.nvim_buf_set_extmark(0, ns_id, line, 0, {
    virt_text = virt_text,
    virt_text_pos = "eol",
  })

  -- Store reference
  if not M.virtual_text[line] then
    M.virtual_text[line] = {}
  end
  table.insert(M.virtual_text[line], extmark_id)

  local ui_window = {
    buf = vim.api.nvim_get_current_buf(),
    win = vim.api.nvim_get_current_win(),
    type = "virtual",
    extmark_id = extmark_id,
    namespace = ns_id,
  }

  return M.ok(ui_window)
end

--- Display content in terminal buffer
---@param content string Content to display
---@param opts? UranusUIOptions Display options
---@return UranusResult<UranusUIWindow>
function M.display_terminal(content, opts)
  opts = opts or {}

  -- Create terminal buffer
  local buf = vim.api.nvim_create_buf(false, true)
  if not buf then
    return M.err("BUF_CREATE_FAILED", "Failed to create buffer")
  end

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "buftype", "terminal")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  -- Create terminal
  local term_cmd = opts.terminal_cmd or "echo"
  vim.fn.termopen(term_cmd, {
    on_exit = function()
      -- Auto-close terminal on exit
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end, 1000)
    end,
  })

  -- Send content to terminal
  vim.api.nvim_chan_send(vim.b[buf].terminal_job_id, content .. "\n")

  -- Create window
  local win_opts = {
    split = "below",
    height = opts.height or 10,
  }

  vim.api.nvim_set_current_win(vim.api.nvim_open_win(buf, true, win_opts))

  local ui_window = {
    buf = buf,
    win = vim.api.nvim_get_current_win(),
    type = "terminal",
  }

  M.windows[buf] = ui_window

  return M.ok(ui_window)
end

--- Display content in a split window
---@param content string Content to display
---@param opts? UranusUIOptions Display options
---@return UranusResult<UranusUIWindow>
function M.display_split(content, opts)
  opts = opts or {}

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  if not buf then
    return M.err("BUF_CREATE_FAILED", "Failed to create buffer")
  end

  -- Set buffer content
  local lines = vim.split(content, "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)

  -- Create split
  local split_cmd = opts.split_cmd or "split"
  vim.cmd(split_cmd)

  -- Set buffer in new window
  vim.api.nvim_win_set_buf(0, buf)

  -- Set window options
  vim.api.nvim_win_set_option(0, "wrap", true)
  vim.api.nvim_win_set_option(0, "number", false)

  local ui_window = {
    buf = buf,
    win = vim.api.nvim_get_current_win(),
    type = "split",
  }

  M.windows[buf] = ui_window

  return M.ok(ui_window)
end

--- Update existing window content
---@param ui_window UranusUIWindow Window to update
---@param content string New content
---@return UranusResult
function M.update_content(ui_window, content)
  if not vim.api.nvim_buf_is_valid(ui_window.buf) then
    return M.err("INVALID_BUFFER", "Buffer is not valid")
  end

  -- Make buffer modifiable
  vim.api.nvim_buf_set_option(ui_window.buf, "modifiable", true)

  -- Update content
  local lines = vim.split(content, "\n")
  vim.api.nvim_buf_set_lines(ui_window.buf, 0, -1, false, lines)

  -- Make buffer readonly again
  vim.api.nvim_buf_set_option(ui_window.buf, "modifiable", false)

  return M.ok(true)
end

--- Close a UI window
---@param ui_window UranusUIWindow Window to close
---@return UranusResult
function M.close(ui_window)
  -- Remove from tracking
  M.windows[ui_window.buf] = nil

  -- Close window
  if vim.api.nvim_win_is_valid(ui_window.win) then
    vim.api.nvim_win_close(ui_window.win, true)
  end

  -- Delete buffer if it's not a regular file
  if vim.api.nvim_buf_is_valid(ui_window.buf) then
    local buftype = vim.api.nvim_buf_get_option(ui_window.buf, "buftype")
    if buftype ~= "" then
      vim.api.nvim_buf_delete(ui_window.buf, { force = true })
    end
  end

  return M.ok(true)
end

--- Close all UI windows
---@return UranusResult
function M.close_all()
  for buf, ui_window in pairs(M.windows) do
    M.close(ui_window)
  end

  -- Clear virtual text
  for line, extmarks in pairs(M.virtual_text) do
    local ns_id = vim.api.nvim_create_namespace("uranus_virtual_text")
    vim.api.nvim_buf_clear_namespace(0, ns_id, line, line + 1)
  end

  M.virtual_text = {}

  return M.ok(true)
end

--- Create a progress indicator
---@param message string Progress message
---@param opts? table Progress options
---@return UranusProgressIndicator
function M.create_progress(message, opts)
  opts = opts or {}

  local progress = {
    message = message,
    spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
    index = 1,
    timer = nil,
    win = nil,
  }

  -- Create floating window for progress
  local result = M.display_floating(message, {
    width = opts.width or 40,
    height = 1,
    title = opts.title or "Uranus",
    border = "rounded",
  })

  if result.success then
    progress.win = result.data

    -- Start spinner animation
    progress.timer = vim.fn.timer_start(100, function()
      M._update_progress_spinner(progress)
    end, { ["repeat"] = -1 })
  end

  return progress
end

--- Update progress indicator
---@param progress UranusProgressIndicator Progress indicator
---@param message? string New message
function M.update_progress(progress, message)
  if message then
    progress.message = message
  end

  if progress.win and vim.api.nvim_win_is_valid(progress.win.win) then
    M.update_content(progress.win, progress.message)
  end
end

--- Close progress indicator
---@param progress UranusProgressIndicator Progress indicator
function M.close_progress(progress)
  if progress.timer then
    vim.fn.timer_stop(progress.timer)
  end

  if progress.win then
    M.close(progress.win)
  end
end

--- Update progress spinner
---@param progress UranusProgressIndicator Progress indicator
function M._update_progress_spinner(progress)
  if not progress.win or not vim.api.nvim_win_is_valid(progress.win.win) then
    if progress.timer then
      vim.fn.timer_stop(progress.timer)
    end
    return
  end

  progress.index = progress.index % #progress.spinner + 1
  local spinner = progress.spinner[progress.index]
  local message = spinner .. " " .. progress.message

  M.update_content(progress.win, message)
end

--- Set up UI autocommands
function M._setup_autocommands()
  local augroup = vim.api.nvim_create_augroup("UranusUI", { clear = true })

  -- Clean up windows when buffer is deleted
  vim.api.nvim_create_autocmd("BufDelete", {
    group = augroup,
    callback = function(args)
      local buf = args.buf
      if M.windows[buf] then
        M.windows[buf] = nil
      end
    end,
  })

  -- Clean up virtual text when buffer is unloaded
  vim.api.nvim_create_autocmd("BufUnload", {
    group = augroup,
    callback = function(args)
      local buf = args.buf
      M.virtual_text[buf] = nil
    end,
  })
end

--- Get UI statistics
---@return table UI statistics
function M.stats()
  return {
    active_windows = vim.tbl_count(M.windows),
    virtual_text_lines = vim.tbl_count(M.virtual_text),
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