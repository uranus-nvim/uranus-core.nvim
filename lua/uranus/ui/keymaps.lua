--- Uranus keymap management
--- Safe keymap creation with conflict detection and cleanup
---
--- @module uranus.keymaps

local M = {}

--- Track active keymaps for cleanup
---@type table<string, { mode: string, key: string, buffer: integer? }>
local active_keymaps = {}

--- Track buffer-specific keymaps
---@type table<integer, table<string, { mode: string, key: string }>>
local buffer_keymaps = {}

--- Check if a keymap conflicts with existing mappings
---@param mode string
---@param key string
---@param buffer integer?
---@return boolean
local function has_conflict(mode, key, buffer)
  local bufnr = buffer or 0

  -- Check if keymap already exists
  local existing = vim.fn.maparg(key, mode, false, true)
  if existing and not vim.tbl_isempty(existing) then
    -- Check if it's our own keymap (allow redefining our keymaps)
    local lhs = existing.lhs or ""
    if lhs:match("uranus") or lhs:match("Uranus") then
      return false
    end

    -- Check if it's a default Neovim mapping
    local defaults = {
      n = { "q", "Q", "K", "H", "L", "M", "G", "gg", "j", "k", "n", "N", "'", '"', "/" },
      i = { "<C-c>", "<C-x>", "<C-o>" },
      v = { ">", "<", "=" },
    }

    local mode_defaults = defaults[mode] or {}
    for _, default_key in ipairs(mode_defaults) do
      if key == default_key then
        vim.notify(
          string.format("Keymap conflict: '%s' in %s mode is a default Neovim mapping", key, mode),
          vim.log.levels.WARN
        )
        return true
      end
    end

    -- Check if it's from another plugin
    if existing.desc and not existing.desc:match("uranus") then
      vim.notify(
        string.format("Keymap conflict: '%s' in %s mode is already mapped by '%s'", key, mode, existing.desc or "unknown"),
        vim.log.levels.WARN
      )
      return true
    end

    -- For buffer-local keymaps, check buffer-specific conflicts
    if bufnr > 0 then
      local buf_keymaps = buffer_keymaps[bufnr] or {}
      local map_key = string.format("%s:%s", mode, key)
      if buf_keymaps[map_key] then
        return true -- Already our keymap
      end
    end
  end

  return false
end

--- Safe keymap set with conflict detection
---@param mode string|string[] Mode(s) for the keymap (e.g., "n", "v", "i")
---@param key string Key sequence
---@param fn function|string Callback or command
---@param opts table? Options (see vim.keymap.set)
---@param buffer integer? Buffer number (0 for current, nil for global)
---@return boolean success
function M.set(mode, key, fn, opts, buffer)
  opts = opts or {}
  local bufnr = buffer or 0

  -- Check if keymaps are disabled
  local config = require("uranus.config")
  if config.get("keymaps.enabled") == false then
    return false
  end

  -- Check for disabled keymaps
  local disabled = config.get("keymaps.disable") or {}
  for _, disabled_key in ipairs(disabled) do
    if key == disabled_key then
      return false
    end
  end

  -- Normalize mode to array
  local modes = type(mode) == "table" and mode or { mode }

  for _, m in ipairs(modes) do
    -- Check for conflicts (skip for buffer-local keymaps)
    if bufnr == 0 and has_conflict(m, key, bufnr) then
      return false
    end

    -- Create unique ID for tracking
    local keymap_id = string.format("%s:%s:%s", m, key, bufnr)

    -- Check if we already have this keymap
    if active_keymaps[keymap_id] then
      -- Already registered, skip
      return true
    end

    -- Set the keymap
    local success = pcall(function()
      vim.keymap.set(m, key, fn, opts)
    end)

    if success then
      -- Track the keymap
      active_keymaps[keymap_id] = {
        mode = m,
        key = key,
        buffer = bufnr,
      }

      -- Track buffer-specific keymaps
      if bufnr > 0 then
        if not buffer_keymaps[bufnr] then
          buffer_keymaps[bufnr] = {}
        end
        buffer_keymaps[bufnr][keymap_id] = {
          mode = m,
          key = key,
        }
      end
    else
      vim.notify(
        string.format("Failed to set keymap: %s in %s mode", key, m),
        vim.log.levels.ERROR
      )
      return false
    end
  end

  return true
end

--- Delete a keymap
---@param mode string
---@param key string
---@param buffer integer?
function M.del(mode, key, buffer)
  local bufnr = buffer or 0
  local keymap_id = string.format("%s:%s:%s", mode, key, bufnr)

  -- Remove from tracking
  active_keymaps[keymap_id] = nil

  -- Remove from buffer tracking
  if bufnr > 0 and buffer_keymaps[bufnr] then
    buffer_keymaps[bufnr][keymap_id] = nil
  end

  -- Delete the keymap
  pcall(vim.keymap.del, mode, key, { buffer = bufnr })
end

--- Clear all keymaps
function M.clear_all()
  for keymap_id, km in pairs(active_keymaps) do
    pcall(vim.keymap.del, km.mode, km.key, { buffer = km.buffer })
  end
  active_keymaps = {}
  buffer_keymaps = {}
end

--- Clear buffer-specific keymaps
---@param bufnr integer
function M.clear_buffer(bufnr)
  if not buffer_keymaps[bufnr] then
    return
  end

  for keymap_id, km in pairs(buffer_keymaps[bufnr] or {}) do
    pcall(vim.keymap.del, km.mode, km.key, { buffer = bufnr })
    active_keymaps[keymap_id] = nil
  end

  buffer_keymaps[bufnr] = nil
end

--- Get all active keymaps
---@return table<string, { mode: string, key: string, buffer: integer? }>
function M.get_active()
  return active_keymaps
end

--- Check if a keymap is active
---@param mode string
---@param key string
---@param buffer integer?
---@return boolean
function M.is_active(mode, key, buffer)
  local bufnr = buffer or 0
  local keymap_id = string.format("%s:%s:%s", mode, key, bufnr)
  return active_keymaps[keymap_id] ~= nil
end

--- Set up buffer-local keymaps for a specific buffer
---@param bufnr integer
---@param keymaps table Array of { mode, key, fn, opts }
function M.set_buffer_keymaps(bufnr, keymaps)
  for _, km in ipairs(keymaps) do
    M.set(km.mode, km.key, km.fn, km.opts, bufnr)
  end
end

--- Create a keymap with a description prefix
---@param mode string
---@param key string
---@param fn function|string
---@param desc string
---@param opts table?
---@param buffer integer?
function M.set_with_desc(mode, key, fn, desc, opts, buffer)
  opts = opts or {}
  opts.desc = desc
  opts.silent = opts.silent or true
  return M.set(mode, key, fn, opts, buffer)
end

return M
