-- Config file for luacheck
-- https://luacheck.readthedocs.io/

cache = true
exclude = { ".luarocks", "target" }
max_line_length = 120
max_cyclomatic_complexity = 20

globals = {
  "vim",
  "describe",
  "it",
  "before_each",
  "after_each",
}

-- Define 'state' as a global (it's used in init.lua)
read_globals = { "state" }

-- Allow unused variables with underscore prefix
unused = false

-- Ignore warnings by code:
-- 2..: redefined variables
-- 3..: unused variables/arguments
-- 4..: unused/undefined globals
-- 5..: unused loop variables
-- 6..: whitespace issues
ignore = {
  "2..", -- redefined variables (ok is often redefined)
  "3..", -- unused variables
  "4..", -- unused globals
  "5..", -- unused loop variables
  "6..", -- whitespace issues
}

-- Allow cyclomatic complexity to be exceeded (just warn, don't error)
std = "luajit"
