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
