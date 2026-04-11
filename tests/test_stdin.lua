-- Test stdin functionality
local u = require("uranus")
u.start_backend()
u.connect_kernel("python3")
vim.wait(3000)

print("=== stdin Test ===")

-- Verify stdin socket exists
local r1 = u.execute('import sys; print("stdin isatty:", sys.stdin.isatty())')
print("stdin check: " .. vim.inspect(r1))

-- Verify we can do basic execution
local r2 = u.execute('print(2+2)')
print("basic: " .. vim.inspect(r2))

-- Test input with IPython override
local r3 = u.execute([=[
def _fake_input(prompt, ident, parent, password=False):
    return "answer123"

get_ipython().kernel._input_request = _fake_input
x = input('prompt: ')
print('input result:', x)
]=])
print("with override: " .. vim.inspect(r3))

print("=== stdin Complete ===")
vim.cmd("qa!")