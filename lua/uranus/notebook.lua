--- Uranus notebook mode
---
--- Provides notebook-style editing with interleaved code and output,
--- live preview, and export capabilities.
---
--- @module uranus.notebook
--- @license MIT

local M = {}

---@class UranusNotebook
---@field buf number Notebook buffer
---@field original_buf number Original buffer
---@field cells UranusCell[] Notebook cells
---@field renderer string Markdown renderer
---@field live_update boolean Live update enabled

--- Module state
---@type table<number, UranusNotebook>
M.notebooks = {}

--- Initialize notebook functionality
---@param config UranusConfig Uranus configuration
---@return UranusResult
function M.init(config)
  M.config = config

  -- Set up notebook autocommands
  M._setup_autocommands()

  return M.ok(true)
end

--- Create notebook from current buffer
---@param opts? table Creation options
---@return UranusResult<UranusNotebook>
function M.create(opts)
  opts = opts or {}

  local original_buf = vim.api.nvim_get_current_buf()
  local renderer = opts.renderer or M.config.ui.markdown_renderer

  -- Create notebook buffer
  local notebook_buf = vim.api.nvim_create_buf(false, false)
  if not notebook_buf then
    return M.err("BUF_CREATE_FAILED", "Failed to create notebook buffer")
  end

  -- Set buffer options
  vim.api.nvim_buf_set_option(notebook_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(notebook_buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(notebook_buf, "swapfile", false)

  -- Set buffer name
  local original_name = vim.api.nvim_buf_get_name(original_buf)
  local notebook_name = "Notebook: " .. vim.fn.fnamemodify(original_name, ":t")
  vim.api.nvim_buf_set_name(notebook_buf, notebook_name)

  -- Parse cells from original buffer
  local repl = require("uranus.repl")
  local cells_result = repl.parse_cells(original_buf)
  if not cells_result.success then
    vim.api.nvim_buf_delete(notebook_buf, { force = true })
    return cells_result
  end

  -- Create notebook object
  local notebook = {
    buf = notebook_buf,
    original_buf = original_buf,
    cells = cells_result.data,
    renderer = renderer,
    live_update = opts.live_update or true,
  }

  M.notebooks[notebook_buf] = notebook

  -- Render initial notebook
  M._render_notebook(notebook)

  -- Set up notebook keymaps
  M._setup_notebook_keymaps(notebook)

  -- Switch to notebook buffer
  vim.api.nvim_set_current_buf(notebook_buf)

  vim.notify("Notebook created from " .. vim.fn.fnamemodify(original_name, ":t"),
    vim.log.levels.INFO)

  return M.ok(notebook)
end

--- Open notebook from file
---@param filepath string Path to notebook file
---@return UranusResult<UranusNotebook>
function M.open(filepath)
  if not vim.fn.filereadable(filepath) then
    return M.err("FILE_NOT_FOUND", "Notebook file not found: " .. filepath)
  end

  -- Send notebook file to backend for parsing
  local backend = require("uranus.backend")
  local result = backend.send_command("parse_notebook", {
    filepath = filepath
  })

  if not result.success then
    return result
  end

  -- Create buffer and populate with parsed content
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(buf, "Notebook: " .. vim.fn.fnamemodify(filepath, ":t"))

  -- Use parsed content from backend
  local lines = result.data.lines or {}
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Create notebook object
  local notebook = {
    buf = buf,
    original_buf = buf, -- Same buffer for opened notebooks
    cells = {},
    renderer = M.config.ui.markdown_renderer,
    live_update = true,
  }

  M.notebooks[buf] = notebook

  -- Set up notebook
  M._setup_notebook_keymaps(notebook)
  vim.api.nvim_set_current_buf(buf)

  return M.ok(notebook)
end

--- Save notebook to file
---@param notebook UranusNotebook Notebook to save
---@param filepath? string Save path (prompt if not provided)
---@return UranusResult
function M.save(notebook, filepath)
  if not filepath then
    filepath = vim.fn.input("Save notebook as: ", "", "file")
    if filepath == "" then
      return M.err("CANCELLED", "Save cancelled")
    end
  end

  -- Send notebook to backend for nbformat conversion and saving
  local backend = require("uranus.backend")
  local result = backend.send_command("save_notebook", {
    notebook = notebook,
    filepath = filepath
  })

  if not result.success then
    return result
  end

  vim.notify("Notebook saved to " .. filepath, vim.log.levels.INFO)

  return M.ok(true)
end

--- Toggle notebook mode for current buffer
---@return UranusResult
function M.toggle()
  local current_buf = vim.api.nvim_get_current_buf()
  local notebook = M.notebooks[current_buf]

  if notebook then
    -- Close notebook and return to original buffer
    M.close(notebook)
    return M.ok(true)
  else
    -- Create notebook from current buffer
    return M.create()
  end
end

--- Close notebook
---@param notebook UranusNotebook Notebook to close
---@return UranusResult
function M.close(notebook)
  -- Remove from tracking
  M.notebooks[notebook.buf] = nil

  -- Close buffer
  if vim.api.nvim_buf_is_valid(notebook.buf) then
    vim.api.nvim_buf_delete(notebook.buf, { force = true })
  end

  -- Return to original buffer
  if vim.api.nvim_buf_is_valid(notebook.original_buf) then
    vim.api.nvim_set_current_buf(notebook.original_buf)
  end

  return M.ok(true)
end

--- Render notebook content
---@param notebook UranusNotebook Notebook to render
function M._render_notebook(notebook)
  if not vim.api.nvim_buf_is_valid(notebook.buf) then
    return
  end

  local lines = {}

  for i, cell in ipairs(notebook.cells) do
    -- Add cell header
    table.insert(lines, string.format("## Cell %d", i))
    table.insert(lines, "")

    -- Add code block
    table.insert(lines, "```python")
    for _, code_line in ipairs(vim.split(cell.code, "\n")) do
      table.insert(lines, code_line)
    end
    table.insert(lines, "```")
    table.insert(lines, "")

    -- Add output if available
    if cell.output then
      local output = require("uranus.output")
      local output_text = output.format_result(cell.output)

      if output_text then
        table.insert(lines, "**Output:**")
        table.insert(lines, "")
        for _, line in ipairs(vim.split(output_text, "\n")) do
          table.insert(lines, line)
        end
        table.insert(lines, "")
      end
    end

    -- Add separator
    if i < #notebook.cells then
      table.insert(lines, "---")
      table.insert(lines, "")
    end
  end

  -- Update buffer content
  vim.api.nvim_buf_set_lines(notebook.buf, 0, -1, false, lines)

  -- Apply markdown rendering
  M._apply_markdown_rendering(notebook)
end

--- Apply markdown rendering to notebook
---@param notebook UranusNotebook Notebook to render
function M._apply_markdown_rendering(notebook)
  local renderer = notebook.renderer

  if renderer == "markview" then
    pcall(function()
      require("markview").render(notebook.buf)
    end)
  elseif renderer == "render-markdown" then
    pcall(function()
      require("render-markdown").render(notebook.buf)
    end)
  end
end

--- Set up notebook keymaps
---@param notebook UranusNotebook Notebook object
function M._setup_notebook_keymaps(notebook)
  local opts = { buffer = notebook.buf, noremap = true, silent = true }

  -- Navigation
  vim.keymap.set("n", "<leader>nj", function()
    M._next_cell(notebook)
  end, vim.tbl_extend("force", opts, { desc = "Next cell" }))

  vim.keymap.set("n", "<leader>nk", function()
    M._prev_cell(notebook)
  end, vim.tbl_extend("force", opts, { desc = "Previous cell" }))

  -- Execution
  vim.keymap.set("n", "<leader>nc", function()
    M._run_cell(notebook)
  end, vim.tbl_extend("force", opts, { desc = "Run cell" }))

  vim.keymap.set("n", "<leader>na", function()
    M._run_all(notebook)
  end, vim.tbl_extend("force", opts, { desc = "Run all cells" }))

  -- Notebook operations
  vim.keymap.set("n", "<leader>ns", function()
    M.save(notebook)
  end, vim.tbl_extend("force", opts, { desc = "Save notebook" }))

  vim.keymap.set("n", "<leader>nq", function()
    M.close(notebook)
  end, vim.tbl_extend("force", opts, { desc = "Close notebook" }))
end



--- Set up notebook autocommands
function M._setup_autocommands()
  local augroup = vim.api.nvim_create_augroup("UranusNotebook", { clear = true })

  -- Clean up notebooks when buffers are deleted
  vim.api.nvim_create_autocmd("BufDelete", {
    group = augroup,
    callback = function(args)
      if M.notebooks[args.buf] then
        M.notebooks[args.buf] = nil
      end
    end,
  })
end

--- Get notebook statistics
---@return table Notebook statistics
function M.stats()
  return {
    active_notebooks = vim.tbl_count(M.notebooks),
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