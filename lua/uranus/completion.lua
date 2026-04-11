--- Uranus blink.cmp integration
--- Provides kernel-aware completions by merging LSP completions with kernel runtime values
---
--- @module uranus.completion

local M = {}

local config = {
    enable_kernel_completion = true,
    max_kernel_items = 20,
    priority_kernel = 50,
    priority_lsp = 100,
    show_types = true,
}

local ns_completion = vim.api.nvim_create_namespace("uranus_completion")

local function get_uranus()
    local ok, uranus = pcall(require, "uranus")
    return ok and uranus or nil
end

local function get_lsp()
    local ok, lsp = pcall(require, "uranus.lsp")
    return ok and lsp or nil
end

function M.configure(opts)
    config = vim.tbl_deep_extend("force", config, opts or {})
end

function M.get_config()
    return config
end

function M.is_available()
    return vim.fn.exists("g:loaded_msky_blink_cmp") == 1 or 
           vim.fn.exists("g:loaded_blink_cmp") == 1
end

function M.get_kernel_completions(word)
    if not config.enable_kernel_completion then
        return {}
    end

    local u = get_uranus()
    if not u or not u.state or not u.state.current_kernel then
        return {}
    end

    local code = string.format([[
import json
import sys
try:
    _vars = {}
    for k, v in globals().items():
        if not k.startswith('_') and k.startswith('%s'):
            try:
                _vars[k] = type(v).__name__
            except:
                pass
    for k, v in locals().items():
        if not k.startswith('_') and k.startswith('%s'):
            try:
                _vars[k] = type(v).__name__
            except:
                pass
    print(json.dumps(_vars))
except:
    pass
]], word:sub(1, 1), word:sub(1, 1))

    local result = u.execute(code)
    if result.success and result.data and result.data.stdout then
        local ok, vars = pcall(vim.json.decode, result.data.stdout)
        if ok and vars then
            local items = {}
            local count = 0
            for name, type_name in pairs(vars) do
                if count >= config.max_kernel_items then
                    break
                end
                table.insert(items, {
                    label = name,
                    kind = "Variable",
                    detail = type_name,
                    insertText = name,
                    priority = config.priority_kernel,
                    source = "kernel",
                })
                count = count + 1
            end
            return items
        end
    end

    return {}
end

function M.get_lsp_completions()
    local lsp = get_lsp()
    if not lsp then
        return {}
    end

    local items = lsp.get_lsp_completions()
    local results = {}

    for _, item in ipairs(items) do
        local label = item.label or item.textEdit and item.textEdit.newText or ""
        table.insert(results, {
            label = label,
            kind = item.kind and vim.lsp.protocol.CompletionItemKind[item.kind] or "Text",
            detail = item.detail or "",
            documentation = item.documentation or "",
            insertText = item.insertText or label,
            priority = config.priority_lsp,
            source = "lsp",
        })
    end

    return results
end

function M.get_all_completions(word)
    local kernel_items = M.get_kernel_completions(word)
    local lsp_items = M.get_lsp_completions()

    local all = vim.list_extend(kernel_items, lsp_items)

    table.sort(all, function(a, b)
        return a.priority > b.priority
    end)

    return all
end

function M.merge_completions(context)
    local items = context.items or {}
    local kernel_items = M.get_kernel_completions(context.trigger_character or "")

    for _, item in ipairs(kernel_items) do
        local found = false
        for _, existing in ipairs(items) do
            if existing.label == item.label then
                found = true
                break
            end
        end
        if not found then
            table.insert(items, item)
        end
    end

    return items
end

local function setup_blink()
    if not M.is_available() then
        return
    end

    local ok, blink = pcall(require, "blink-cmp")
    if not ok then
        return
    end

    local function blink_config()
        return {
            sources = {
                default = { "lsp", "path", "snippets", "uranus_kernel" },
                providers = {
                    uranus_kernel = {
                        name = "uranus_kernel",
                        module = "uranus.completion",
                        fetch = function(context)
                            return M.get_kernel_completions(context.trigger_character or "")
                        end,
                        is_enabled = function()
                            return config.enable_kernel_completion and
                                   get_uranus() and
                                   get_uranus().state and
                                   get_uranus().state.current_kernel ~= nil
                        end,
                    },
                },
            },
        }
    end

    if vim.fn.exists("g:loaded_msky_blink_cmp") == 1 then
        require("msky.blink_cmp").config(blink_config())
    end
end

function M.setup()
    if M.is_available() then
        setup_blink()
    else
        vim.defer_fn(function()
            setup_blink()
        end, 1000)
    end
end

function M.complete_kernel_variables()
    local u = get_uranus()
    if not u or not u.state or not u.state.current_kernel then
        vim.notify("No kernel connected", vim.log.levels.WARN)
        return
    end

    local code = [[
import json
vars = {k: repr(v)[:50] for k, v in globals().items() if not k.startswith('_')}
print(json.dumps(vars))
]]

    local result = u.execute(code)
    if result.success and result.data and result.data.stdout then
        local ok, vars = pcall(vim.json.decode, result.data.stdout)
        if ok and vars then
            local lines = { "=== Kernel Variables ===", "" }
            for name, value in pairs(vars) do
                table.insert(lines, string.format("  %s = %s", name, value))
            end
            vim.fn.setreg("\"", table.concat(lines, "\n"))
            vim.notify("Copied to register", vim.log.levels.INFO)
        end
    end
end

return M