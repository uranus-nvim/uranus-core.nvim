-- Config file for luacheck
-- https://luacheck.readthedocs.io/

cache = true
exclude = { ".luarocks", "target" }
max-line-length = 120
max-cyclomatic-complexity = 20

globals = {
  "vim",
  "describe",
  "it",
  "before_each",
  "after_each",
}

[*.lua]
globals = {
  "describe",
  "it",
  "before_each",
  "after_each",
}