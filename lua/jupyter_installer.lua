--- Jupyter installation helper with fallback strategy
--- Provides installation options: project venv or system-wide
---@module jupyter_installer

local M = {}

local function detect_python()
    local python_cmds = { "python3", "python", "py" }
    for _, cmd in ipairs(python_cmds) do
        local handle = io.popen(cmd .. " --version 2>&1")
        if handle then
            local result = handle:read("*a")
            handle:close()
            if result and not result:match("not found") and not result:match("command not found") then
                return cmd
            end
        end
    end
    return nil
end

local function has_uv()
    local handle = io.popen("which uv 2>/dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        return result and result:match("uv") ~= nil
    end
    return false
end

local function find_project_root()
    local cwd = vim.loop.cwd() or vim.fn.getcwd()
    local venv_indicators = { ".venv", "venv", ".env", "env", "pyvenv.toml", "poetry.lock", "requirements.txt" }

    local function check_dir(dir)
        for _, indicator in ipairs(venv_indicators) do
            local path = dir .. "/" .. indicator
            if vim.fn.isdirectory(path) == 1 or vim.fn.filereadable(path) == 1 then
                return dir
            end
        end
        local parent = vim.fn.fnamemodify(dir, ":h")
        if parent and parent ~= dir and parent ~= "" then
            return check_dir(parent)
        end
        return nil
    end

    return check_dir(cwd)
end

local function get_venv_python(venv_path)
    local venv_python = venv_path .. "/bin/python"
    if vim.fn.executable(venv_python) == 1 then
        return venv_python
    end
    venv_python = venv_path .. "/Scripts/python.exe"
    if vim.fn.executable(venv_python) == 1 then
        return venv_python
    end
    return nil
end

local function install_with_cmd(cmd, notify)
    local handle = io.popen(cmd .. " 2>&1")
    if not handle then
        notify("Failed to run install command", vim.log.levels.ERROR)
        return false, "Failed to run install command"
    end

    local output = handle:read("*a")
    local success = handle:close()

    if success then
        return true, output
    else
        return false, output
    end
end

function M.get_install_strategy()
    local strategies = {}

    if has_uv() then
        table.insert(strategies, {
            name = "uv (project venv)",
            description = "Fast, modern package manager with project virtual environment",
            install = function(notify)
                notify("Installing Jupyter with uv...", vim.log.levels.INFO)
                local project_root = find_project_root()
                local venv_path = project_root and project_root .. "/.venv" or ".venv"
                local cmd = string.format("cd %s && uv venv && uv add jupyter notebook ipykernel",
                    project_root or ".")
                local ok, output = install_with_cmd(cmd, notify)
                if ok then
                    notify("Jupyter installed to .venv via uv!", vim.log.levels.INFO)
                    return true, { method = "uv", venv = venv_path }
                end
                return false, output
            end,
        })
    end

    local project_root = find_project_root()
    if project_root then
        local venv_path = project_root .. "/.venv"
        if vim.fn.isdirectory(venv_path) == 1 then
            local venv_python = get_venv_python(venv_path)
            if venv_python then
                table.insert(strategies, {
                    name = "project venv",
                    description = "Install to existing .venv in project",
                    install = function(notify)
                        notify("Installing Jupyter to project venv...", vim.log.levels.INFO)
                        local cmd = venv_python .. " -m pip install jupyter notebook ipykernel"
                        local ok, output = install_with_cmd(cmd, notify)
                        if ok then
                            notify("Jupyter installed to project venv!", vim.log.levels.INFO)
                            return true, { method = "venv", venv = venv_path, python = venv_python }
                        end
                        return false, output
                    end,
                })
            end
        end
    end

    local python = detect_python()
    if python then
        table.insert(strategies, {
            name = "system (break-system-packages)",
            description = "Install to system Python (may require sudo)",
            install = function(notify)
                notify("Installing Jupyter to system...", vim.log.levels.INFO)
                local cmd = python .. " -m pip install --break-system-packages jupyter notebook ipykernel"
                local ok, output = install_with_cmd(cmd, notify)
                if ok then
                    notify("Jupyter installed to system!", vim.log.levels.INFO)
                    return true, { method = "system", python = python }
                end
                return false, output
            end,
        })
    end

    table.insert(strategies, {
        name = "system (no flag)",
        description = "Install to system Python (legacy, may fail on PEP 668)",
        install = function(notify)
            notify("Installing Jupyter to system (legacy)...", vim.log.levels.INFO)
            local cmd = (python or "pip3") .. " install jupyter notebook ipykernel"
            local ok, output = install_with_cmd(cmd, notify)
            if ok then
                notify("Jupyter installed to system!", vim.log.levels.INFO)
                return true, { method = "system-legacy", python = python or "pip3" }
            end
            return false, output
        end,
    })

    return strategies
end

function M.show_install_dialog(callback)
    local strategies = M.get_install_strategy()

    if #strategies == 0 then
        vim.notify("No Python installation found. Please install Python first.", vim.log.levels.ERROR)
        if callback then callback(false) end
        return
    end

    local choices = {}
    for i, s in ipairs(strategies) do
        table.insert(choices, string.format("%d. %s - %s", i, s.name, s.description))
    end

    vim.ui.select(choices, {
        prompt = "Select Jupyter installation method:",
    }, function(choice)
        if not choice then
            if callback then callback(false) end
            return
        end

        local idx = tonumber(choice:match("^%d+"))
        local strategy = strategies[idx]

        if strategy then
            local ok, result = strategy.install(vim.notify or print)
            if ok then
                vim.notify("Jupyter installed successfully!", vim.log.levels.INFO)
                if callback then callback(true, result) end
            else
                vim.notify("Failed to install Jupyter: " .. tostring(result), vim.log.levels.ERROR)
                if callback then callback(false, result) end
            end
        else
            if callback then callback(false) end
        end
    end)
end

function M.check_jupyter()
    local checks = {
        "jupyter --version",
        "jupyter-client version",
        "python3 -c 'import jupyter_client'",
        "python -c 'import jupyter_client'",
    }

    for _, cmd in ipairs(checks) do
        local handle = io.popen(cmd .. " 2>&1")
        if handle then
            local result = handle:read("*a")
            handle:close()
            if result and not result:match("not found") and not result:match("command not found")
                and not result:match("No module named") then
                return true
            end
        end
    end
    return false
end

M.detect_python = detect_python
M.has_uv = has_uv
M.find_project_root = find_project_root
M.get_install_strategy = M.get_install_strategy
M.show_install_dialog = M.show_install_dialog
M.check_jupyter = M.check_jupyter

return M
