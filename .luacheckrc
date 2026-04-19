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

-- Ignore whitespace-only lines, trailing whitespace, and unused variables
-- These are style issues, not actual errors
ignore = {
  "6..", -- whitespace issues (611: empty line, 612: trailing whitespace)
}

-- Allow unused variables in certain contexts (like _ prefix)
std = "luajit"
