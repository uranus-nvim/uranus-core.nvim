local M = {}

local config = {
    prefer_static = true,
    merge_with_kernel = true,
    use_cache = true,
    cache_ttl = 5000,
}

local cache = {}
local pending_requests = {}
local debounce_timers = {}

local function make_key(...)
    local n = select("#", ...)
    if n == 1 then
        local v = select(1, ...)
        if type(v) == "string" then return "s" .. v end
    end
    local sb = {}
    for i = 1, n do
        local v = select(i, ...)
        if type(v) == "table" then
            sb[i] = vim.inspect(v)
        else
            sb[i] = tostring(v)
        end
    end
    return table.concat(sb, ":")
end

local function get_cached(key)
    if not config.use_cache then
        return nil
    end
    local entry = cache[key]
    if not entry then
        return nil
    end
    local now = vim.loop.now()
    if now - entry.timestamp > config.cache_ttl then
        cache[key] = nil
        return nil
    end
    return entry.value
end

local function set_cached(key, value)
    if not config.use_cache then
        return
    end
    local max_entries = 200
    local count = 0
    for _ in pairs(cache) do count = count + 1 end
    if count >= max_entries then
        local oldest_key, oldest_time = nil, math.huge
        for k, v in pairs(cache) do
            if v.timestamp < oldest_time then
                oldest_time = v.timestamp
                oldest_key = k
            end
        end
        if oldest_key then cache[oldest_key] = nil end
    end
    cache[key] = {
        value = value,
        timestamp = vim.loop.now(),
    }
end

local function clear_cache()
    cache = {}
end

local function debounce(id, fn, delay)
    if debounce_timers[id] then
        debounce_timers[id]:close()
    end
    debounce_timers[id] = vim.defer_fn(function()
        fn()
        debounce_timers[id] = nil
    end, delay)
end

function M.configure(opts)
    config = vim.tbl_deep_extend("force", config, opts or {})
end

function M.get_config()
    return config
end

function M.clear_cache()
    clear_cache()
end

function M.cache_stats()
    local count = 0
    for _ in pairs(cache) do count = count + 1 end
    return {
        size = count,
        ttl = config.cache_ttl,
        enabled = config.use_cache,
    }
end

local client_cache_time = 0
local client_cache_ttl = 2000
local cached_clients = {}

local function get_clients_fast()
    local now = vim.loop.now()
    if now - client_cache_time < client_cache_ttl and cached_clients[1] then
        return cached_clients
    end
    local all_clients = vim.lsp.get_active_clients()
    local python_clients = {}
    local filter = { py = true, ty = true, ruff = true }
    
    for _, client in ipairs(all_clients) do
        local name = client.name
        local lower = client.name:lower()
        if filter[lower:sub(1, 2)] or lower:match("py") or lower:match("ruff") then
            python_clients[#python_clients + 1] = client
        end
    end
    
    cached_clients = python_clients
    client_cache_time = now
    return python_clients
end

function M.get_clients()
    return get_clients_fast()
end

function M.get_first_client()
    local clients = get_clients_fast()
    return clients[1]
end

function M.is_available()
    return cached_clients[1] ~= nil
end

function M.status()
    local clients = get_clients_fast()
    if #clients == 0 then
        return { running = false, clients = {} }
    end
    
    local buf = vim.api.nvim_get_current_buf()
    local info = { running = true, clients = {} }
    for i = 1, #clients do
        local client = clients[i]
        info.clients[i] = {
            name = client.name,
            id = client.id,
            attached = client.attached_buffers[buf] or false,
        }
    end
    return info
end

function M.hover(word)
    local cache_key = "hover:" .. word
    local cached = get_cached(cache_key)
    if cached then
        return cached
    end
    
    local lsp_info = M.get_lsp_hover(word)
    
    if config.merge_with_kernel then
        local kernel_info = M.get_kernel_info(word)
        
        if lsp_info or kernel_info then
            local result = {
                name = word,
                type_name = (lsp_info and lsp_info.type) or (kernel_info and kernel_info.type_name) or "unknown",
                value = (kernel_info and kernel_info.value) or (lsp_info and lsp_info.value),
                docstring = (lsp_info and lsp_info.doc) or (kernel_info and kernel_info.docstring),
                from_lsp = lsp_info ~= nil,
                from_kernel = kernel_info ~= nil,
            }
            set_cached(cache_key, result)
            return result
        end
    end
    
    if lsp_info then
        set_cached(cache_key, lsp_info)
    end
    return lsp_info
end

function M.get_lsp_hover(word)
    local clients = get_clients_fast()
    if not clients[1] then
        return nil
    end

    local params = vim.lsp.util.make_position_params()
    local client = clients[1]
    local response = client.request_sync("textDocument/hover", params, 500)
    
    if response and response.result and response.result.contents then
        local content = response.result.contents
        local type_info, doc = nil, nil
        
        if type(content) == "string" then
            type_info = content:match("```python\n(.+)\n```") or content:match("```\n(.+)\n```") or content
        elseif content.value then
            local val = content.value
            type_info = val:match("```python\n(.+)\n```") or val
            doc = val
        end
        
        return {
            type = type_info,
            doc = doc,
            client = client.name,
        }
    end
    
    return nil
end

function M.get_lsp_definition(word)
    local clients = get_clients_fast()
    if not clients[1] then
        return nil
    end

    local params = vim.lsp.util.make_position_params()
    local response = clients[1].request_sync("textDocument/definition", params, 500)
    
    if response and response.result then
        local location = response.result.location or response.result[1]
        if location then
            return {
                uri = location.uri,
                range = location.range,
                client = clients[1].name,
            }
        end
    end
    
    return nil
end

function M.get_lsp_references(word)
    local clients = get_clients_fast()
    if not clients[1] then
        return {}
    end

    local params = vim.lsp.util.make_position_params()
    local refs = {}
    local response = clients[1].request_sync("textDocument/references", params, 500)
    
    if response and response.result then
        local locations = response.result
        for i = 1, #locations do
            refs[i] = {
                uri = locations[i].uri,
                range = locations[i].range,
                client = clients[1].name,
            }
        end
    end
    
    return refs
end

function M.get_lsp_completions()
    local client = M.get_first_client()
    if not client then
        return {}
    end

    local params = vim.lsp.util.make_position_params()
    local result = client.request_sync("textDocument/completion", params, 300)
    
    if result and result.result then
        return result.result.items or result.result or {}
    end
    
    return {}
end

function M.get_diagnostics()
    return vim.diagnostic.get(vim.api.nvim_get_current_buf())
end

function M.goto_definition()
    vim.lsp.buf.definition()
end

function M.goto_type_definition()
    vim.lsp.buf.type_definition()
end

function M.references()
    vim.lsp.buf.references()
end

function M.implementation()
    vim.lsp.buf.implementation()
end

function M.rename()
    vim.lsp.buf.rename()
end

function M.code_action()
    vim.lsp.buf.code_action()
end

function M.format()
    vim.lsp.buf.format()
end

function M.hover()
    vim.lsp.buf.hover()
end

function M.signature_help()
    vim.lsp.buf.signature_help()
end

function M.document_symbol()
    vim.lsp.buf.document_symbol()
end

function M.workspace_symbol()
    vim.lsp.buf.workspace_symbol()
end

function M.diagnostics()
    vim.diagnostic.open_float()
end

function M.list_diagnostics()
    vim.diagnostic.setqflist()
    vim.cmd("copen")
end

function M.get_kernel_info(word)
    local ok, uranus = pcall(require, "uranus")
    if not ok or not uranus.state or not uranus.state.current_kernel then
        return nil
    end
    
    local result = uranus.inspect(word, 0)
    if result.success and result.data then
        return result.data
    end
    return nil
end

function M.show_hover_enhanced(word)
    local info = M.hover(word)
    
    if not info or not info.name then
        vim.notify("No information available", vim.log.levels.WARN)
        return
    end

    local lines = { "📌 " .. info.name }

    if info.from_lsp or info.from_kernel then
        local source = {}
        if info.from_lsp then source[#source + 1] = "LSP" end
        if info.from_kernel then source[#source + 1] = "Kernel" end
        lines[#lines + 1] = "Source: " .. table.concat(source, " + ")
    end

    if info.type_name and #info.type_name > 0 then
        lines[#lines + 1] = "Type: " .. info.type_name
    end

    if info.value then
        local value = #info.value > 100 and info.value:sub(1, 100) .. "..." or info.value
        lines[#lines + 1] = "Value: " .. value
    end

    if info.docstring then
        local doc = #info.docstring > 500 and info.docstring:sub(1, 500) .. "..." or info.docstring
        lines[#lines + 1] = ""
        lines[#lines + 1] = doc
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    local width = math.min(vim.o.columns - 10, 60)
    local height = math.min(#lines + 2, 20)
    local row = vim.fn.win_screenpos(0)[1]
    local col = vim.fn.win_screenpos(0)[2] + vim.fn.getcurpos()[2]

    vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = "Inspector",
        title_pos = "center",
    })
end

function M.get_capabilities()
    local client = M.get_first_client()
    return client and client.server_capabilities or {}
end

function M.workspace_symbols(query)
    query = query or ""
    local client = M.get_first_client()
    if not client then
        return {}
    end

    local response = client.request_sync("workspace/symbol", { query = query }, 1500)
    return (response and response.result) or {}
end

function M.get_document_symbols(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local client = M.get_first_client()
    if not client then
        return {}
    end

    local params = { textDocument = vim.lsp.util.TextDocumentIdentifier.create(bufnr) }
    local response = client.request_sync("textDocument/documentSymbol", params, 500)
    return (response and response.result) or {}
end

function M.rename_with_preview(new_name)
    local params = vim.lsp.util.make_position_params()
    local client = M.get_first_client()
    if not client then
        vim.notify("No LSP client available", vim.log.levels.WARN)
        return
    end

    local response = client.request_sync("textDocument/rename", {
        textDocument = params.textDocument,
        newName = new_name,
    }, 500)

    if response and response.result then
        vim.lsp.util.apply_workspace_edit(response.result)
        vim.notify("Renamed to: " .. new_name, vim.log.levels.INFO)
    else
        vim.notify("Rename failed", vim.log.levels.ERROR)
    end
end

function M.get_code_actions()
    local client = M.get_first_client()
    if not client then
        return {}
    end

    local params = vim.lsp.util.make_position_params()
    params.context = { diagnostics = vim.diagnostic.get(vim.api.nvim_get_current_buf()) }
    local response = client.request_sync("textDocument/codeAction", params, 500)
    return (response and response.result) or {}
end

function M.execute_code_action(action)
    if not action or not action.edit then
        vim.notify("No edit in action", vim.log.levels.WARN)
        return
    end
    vim.lsp.util.apply_workspace_edit(action.edit)
    if action.command then
        vim.lsp.buf.execute_command(action.command)
    end
end

function M.show_inlay_hints(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local client = M.get_first_client()
    if client and client.server_capabilities.inlayHintProvider then
        vim.lsp.inlay_hint.enable(bufnr, true)
    end
end

function M.hide_inlay_hints(bufnr)
    vim.lsp.inlay_hint.enable(bufnr or vim.api.nvim_get_current_buf(), false)
end

function M.toggle_inlay_hints(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local enabled = vim.b[bufnr].lsp_inlay_hints_enabled
    if enabled then
        M.hide_inlay_hints(bufnr)
        vim.b[bufnr].lsp_inlay_hints_enabled = false
    else
        M.show_inlay_hints(bufnr)
        vim.b[bufnr].lsp_inlay_hints_enabled = true
    end
end

function M.get_semantic_tokens(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local client = M.get_first_client()
    if not client or not client.server_capabilities.semanticTokensProvider then
        return {}
    end

    local params = { textDocument = vim.lsp.util.TextDocumentIdentifier.create(bufnr) }
    local response = client.request_sync("textDocument/semanticTokens/full", params, 1500)
    return (response and response.result) or {}
end

function M.refresh_semantic_tokens(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local client = M.get_first_client()
    if client and client.server_capabilities.semanticTokensProvider then
        vim.lsp.semantic_tokens.start(bufnr, client.id)
    end
end

function M.get_folding_ranges(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local client = M.get_first_client()
    if not client or not client.server_capabilities.foldingRangeProvider then
        return {}
    end

    local params = { textDocument = vim.lsp.util.TextDocumentIdentifier.create(bufnr) }
    local response = client.request_sync("textDocument/foldingRange", params, 500)
    return (response and response.result) or {}
end

function M.apply_format(options)
    options = options or {}
    local client = M.get_first_client()
    if not client then
        vim.notify("No LSP client available", vim.log.levels.WARN)
        return
    end

    local params = {
        textDocument = vim.lsp.util.TextDocumentIdentifier.create(),
        options = options,
    }
    local response = client.request_sync("textDocument/formatting", params, 3000)
    if response and response.result then
        vim.lsp.util.apply_text_edits(response.result)
    end
end

function M.get_color_presentation(color, label)
    local client = M.get_first_client()
    if not client then
        return {}
    end

    local params = {
        textDocument = vim.lsp.util.TextDocumentIdentifier.create(),
        color = color,
        range = vim.api.nvim_get_current_buf():get_mark("."),
    }
    local response = client.request_sync("textDocument/colorPresentation", params, 500)
    return (response and response.result) or {}
end

function M.get_document_colors()
    local client = M.get_first_client()
    if not client then
        return {}
    end

    local params = { textDocument = vim.lsp.util.TextDocumentIdentifier.create() }
    local response = client.request_sync("textDocument/documentColor", params, 500)
    return (response and response.result) or {}
end

function M.server_info()
    local client = M.get_first_client()
    if not client then
        return nil
    end
    return {
        name = client.name,
        version = client.server_metadata and client.server_metadata.version or "unknown",
        pid = client.process_id,
    }
end

function M.document_link()
    local client = M.get_first_client()
    if not client or not client.server_capabilities.documentLinkProvider then
        return {}
    end

    local params = { textDocument = vim.lsp.util.TextDocumentIdentifier.create() }
    local response = client.request_sync("textDocument/documentLink", params, 500)
    return (response and response.result) or {}
end

function M.incoming_calls()
    local client = M.get_first_client()
    if client then
        vim.lsp.buf.incoming_calls(vim.lsp.util.make_position_params())
    end
end

function M.outgoing_calls()
    local client = M.get_first_client()
    if client then
        vim.lsp.buf.outgoing_calls(vim.lsp.util.make_position_params())
    end
end

function M.type_definition()
    vim.lsp.buf.type_definition()
end

function M.select_range()
    local client = M.get_first_client()
    if not client then
        return
    end

    local params = {
        textDocument = vim.lsp.util.TextDocumentIdentifier.create(),
        positions = { vim.lsp.util.make_position_params() },
    }
    local response = client.request_sync("textDocument/selectionRange", params, 500)
    if response and response.result then
        vim.lsp.util.select_range(response.result)
    end
end

function M.prepare_call_hierarchy()
    local client = M.get_first_client()
    if client then
        vim.lsp.buf.prepare_call_hierarchy(vim.lsp.util.make_position_params())
    end
end

function M.prepare_type_hierarchy()
    vim.lsp.buf.prepare_type_hierarchy()
end

return M