--- Minimal Neovim initialization for testing
---
--- This file provides a minimal Neovim setup for running Uranus tests
--- with plenary.nvim test framework.
---
--- @module tests.minimal_init

-- Set up package path for local development
local current_dir = vim.fn.fnamemodify(vim.fn.expand("<sfile>"), ":h:h")
local lua_dir = current_dir .. "/lua"

-- Add lua directory to package.path explicitly
package.path = package.path .. ";" .. lua_dir .. "/?.lua"
package.path = package.path .. ";" .. lua_dir .. "/?/init.lua"

-- Also add to runtimepath
vim.opt.runtimepath:prepend(current_dir)

-- Load the uranus Rust module via rplugin
-- The compiled library should be loaded automatically by Neovim's remote plugin system

-- Add plenary.nvim from lazy directory
local plenary_dir = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(plenary_dir) == 1 then
  package.path = package.path .. ";" .. plenary_dir .. "/lua/?.lua"
  package.path = package.path .. ";" .. plenary_dir .. "/lua/?/init.lua"
end

-- Disable unnecessary plugins and features for testing
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_getscript = 1
vim.g.loaded_getscriptPlugin = 1
vim.g.loaded_gzip = 1
vim.g.loaded_logiPat = 1
vim.g.loaded_rrhelper = 1
vim.g.loaded_spellfile_plugin = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_vimball = 1
vim.g.loaded_vimballPlugin = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1

-- Basic Neovim options for testing
vim.opt.termguicolors = true
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.undofile = false
vim.opt.shadafile = "NONE"

-- Set up runtime path to include Uranus
vim.opt.runtimepath:prepend(current_dir)
vim.opt.runtimepath:append(current_dir .. "/tests")

-- Mock vim.notify for testing
_G.original_notify = vim.notify
vim.notify = function(msg, level, opts)
  -- Store notifications for test verification
  _G.test_notifications = _G.test_notifications or {}
  table.insert(_G.test_notifications, {
    message = msg,
    level = level,
    opts = opts,
  })

  -- Still call original for debugging
  if level and level >= vim.log.levels.ERROR then
    _G.original_notify(msg, level, opts)
  end
end

-- Mock vim.api for safer testing
_G.original_nvim_create_buf = vim.api.nvim_create_buf
vim.api.nvim_create_buf = function(listed, scratch)
  -- Track created buffers for cleanup
  _G.test_buffers = _G.test_buffers or {}
  local buf = _G.original_nvim_create_buf(listed, scratch)
  table.insert(_G.test_buffers, buf)
  return buf
end

-- Test cleanup function
_G.cleanup_test = function()
  -- Clear notifications
  _G.test_notifications = {}

  -- Delete test buffers
  if _G.test_buffers then
    for _, buf in ipairs(_G.test_buffers) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
    _G.test_buffers = {}
  end

  -- Close test windows
  if _G.test_windows then
    for _, win in ipairs(_G.test_windows) do
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end
    _G.test_windows = {}
  end
end

-- Set up test environment
vim.cmd([[
  augroup TestSetup
    autocmd!
    autocmd VimEnter * lua _G.test_setup_complete = true
  augroup END
]])

-- Export test utilities
return {
  cleanup = _G.cleanup_test,
  notifications = function() return _G.test_notifications or {} end,
  buffers = function() return _G.test_buffers or {} end,
  windows = function() return _G.test_windows or {} end,
}