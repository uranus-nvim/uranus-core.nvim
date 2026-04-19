-- Config file for luacheck
-- https://luacheck.readthedocs.io/

cache = true
exclude = { ".luarocks", "target" }
max_line_length = 120
max_cyclomatic_complexity = 20

-- Only report errors, not warnings (quiet = 1.0 means suppress warnings)
-- Warnings include: unused variables, whitespace issues, line length, etc.
-- CI will only fail on actual errors (like accessing undefined globals)
quiet = 1.0

globals = {
    "vim",
    "describe",
    "it",
    "before_each",
    "after_each",
}
