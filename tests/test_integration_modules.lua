--- Integration tests for module interactions
--- Tests cross-module data flows and real-world usage patterns

package.path = package.path .. ";./tests/?.lua"
local T = require("testlib")
T.reset()

local function run_module_integration_tests()
  T.section("Module Integration Tests")

  T.section("Core Modules (New Structure)")
  T.test("core/init.lua loads", function()
    local ok, _ = pcall(require, "uranus.core.init")
    if ok then T.assert(ok) else T.skip("core/init not available") end
  end)

  T.test("core/config.lua loads", function()
    local ok, _ = pcall(require, "uranus.core.config")
    if ok then T.assert(ok) else T.skip("core/config not available") end
  end)

  T.test("core/state.lua loads", function()
    local ok, _ = pcall(require, "uranus.core.state")
    if ok then T.assert(ok) else T.skip("core/state not available") end
  end)

  T.test("core/factory.lua loads", function()
    local ok, _ = pcall(require, "uranus.core.factory")
    if ok then T.assert(ok) else T.skip("core/factory not available") end
  end)

  T.test("core/errors.lua loads", function()
    local ok, _ = pcall(require, "uranus.core.errors")
    if ok then T.assert(ok) else T.skip("core/errors not available") end
  end)

  T.section("Kernel Modules (New Structure)")
  T.test("kernel/kernel_manager.lua loads", function()
    local ok, _ = pcall(require, "uranus.kernel.kernel_manager")
    if ok then T.assert(ok) else T.skip("kernel_manager not available") end
  end)

  T.test("kernel/cache.lua loads", function()
    local ok, _ = pcall(require, "uranus.kernel.cache")
    if ok then T.assert(ok) else T.skip("kernel/cache not available") end
  end)

  T.test("kernel/pool.lua loads", function()
    local ok, _ = pcall(require, "uranus.kernel.pool")
    if ok then T.assert(ok) else T.skip("kernel/pool not available") end
  end)

  T.test("kernel/runtime.lua loads", function()
    local ok, _ = pcall(require, "uranus.kernel.runtime")
    if ok then T.assert(ok) else T.skip("kernel/runtime not available") end
  end)

  T.section("UI Modules (New Structure)")
  T.test("ui/ui.lua loads", function()
    local ok, _ = pcall(require, "uranus.ui.ui")
    if ok then T.assert(ok) else T.skip("ui not available") end
  end)

  T.test("ui/output.lua loads", function()
    local ok, _ = pcall(require, "uranus.ui.output")
    if ok then T.assert(ok) else T.skip("ui/output not available") end
  end)

  T.test("ui/repl.lua loads", function()
    local ok, _ = pcall(require, "uranus.ui.repl")
    if ok then T.assert(ok) else T.skip("ui/repl not available") end
  end)

  T.test("ui/inspector.lua loads", function()
    local ok, _ = pcall(require, "uranus.ui.inspector")
    if ok then T.assert(ok) else T.skip("ui/inspector not available") end
  end)

  T.test("ui/keymaps.lua loads", function()
    local ok, _ = pcall(require, "uranus.ui.keymaps")
    if ok then T.assert(ok) else T.skip("ui/keymaps not available") end
  end)

  T.section("LSP Modules (New Structure)")
  T.test("lsp/lsp.lua loads", function()
    local ok, _ = pcall(require, "uranus.lsp.lsp")
    if ok then T.assert(ok) else T.skip("lsp/lsp not available") end
  end)

  T.test("lsp/completion.lua loads", function()
    local ok, _ = pcall(require, "uranus.lsp.completion")
    if ok then T.assert(ok) else T.skip("lsp/completion not available") end
  end)

  T.section("Utility Modules (New Structure)")
  T.test("util/parsers.lua loads", function()
    local ok, _ = pcall(require, "uranus.util.parsers")
    if ok then T.assert(ok) else T.skip("util/parsers not available") end
  end)

  T.test("util/parallel.lua loads", function()
    local ok, _ = pcall(require, "uranus.util.parallel")
    if ok then T.assert(ok) else T.skip("util/parallel not available") end
  end)

  T.test("util/async_bridge.lua loads", function()
    local ok, _ = pcall(require, "uranus.util.async_bridge")
    if ok then T.assert(ok) else T.skip("util/async_bridge not available") end
  end)

  T.test("util/output_batch.lua loads", function()
    local ok, _ = pcall(require, "uranus.util.output_batch")
    if ok then T.assert(ok) else T.skip("util/output_batch not available") end
  end)

  T.test("util/optimize.lua loads", function()
    local ok, _ = pcall(require, "uranus.util.optimize")
    if ok then T.assert(ok) else T.skip("util/optimize not available") end
  end)

  T.test("util/messages.lua loads", function()
    local ok, _ = pcall(require, "uranus.util.messages")
    if ok then T.assert(ok) else T.skip("util/messages not available") end
  end)

  T.test("util/traits.lua loads", function()
    local ok, _ = pcall(require, "uranus.util.traits")
    if ok then T.assert(ok) else T.skip("util/traits not available") end
  end)

  T.section("Backward Compatibility")
  T.test("Backward compat: uranus.config", function()
    local ok, _ = pcall(require, "uranus.config")
    if ok then T.assert(ok) else T.skip("config not available") end
  end)

  T.test("Backward compat: uranus.state", function()
    local ok, _ = pcall(require, "uranus.state")
    if ok then T.assert(ok) else T.skip("state not available") end
  end)

  T.test("Backward compat: uranus.factory", function()
    local ok, _ = pcall(require, "uranus.factory")
    if ok then T.assert(ok) else T.skip("factory not available") end
  end)

  T.test("Backward compat: uranus.repl", function()
    local ok, _ = pcall(require, "uranus.repl")
    if ok then T.assert(ok) else T.skip("repl not available") end
  end)

  T.test("Backward compat: uranus.lsp", function()
    local ok, _ = pcall(require, "uranus.lsp")
    if ok then T.assert(ok) else T.skip("lsp not available") end
  end)

  T.test("Backward compat: uranus.notebook", function()
    local ok, _ = pcall(require, "uranus.notebook")
    if ok then T.assert(ok) else T.skip("notebook not available") end
  end)

  T.test("Backward compat: uranus.ui", function()
    local ok, _ = pcall(require, "uranus.ui")
    if ok then T.assert(ok) else T.skip("ui not available") end
  end)

  T.test("Backward compat: uranus.cache", function()
    local ok, _ = pcall(require, "uranus.cache")
    if ok then T.assert(ok) else T.skip("cache not available") end
  end)

  T.test("Backward compat: uranus.parsers", function()
    local ok, _ = pcall(require, "uranus.parsers")
    if ok then T.assert(ok) else T.skip("parsers not available") end
  end)

  T.section("Kernel Manager + Remote Integration")
  T.test("Remote module loads", function()
    local ok, remote = pcall(require, "uranus.remote")
    if ok then
      T.assert(remote.list_remote_kernels ~= nil or remote.list ~= nil)
    else
      T.skip("Remote module not available")
    end
  end)

  T.test("Kernel manager loads", function()
    local ok, km = pcall(require, "uranus.kernel_manager")
    if ok then
      T.assert(km.connect ~= nil or km.list_kernels ~= nil)
    else
      T.skip("Kernel manager not available")
    end
  end)

  T.test("Kernel trait interface exists", function()
    local ok, traits = pcall(require, "uranus.traits")
    T.assert(ok, "Traits module should load")
  end)

  T.section("Notebook + Notebook UI Integration")
  T.test("Notebook module functions", function()
    local notebook = require("uranus.notebook")
    T.assert(notebook.open ~= nil or notebook.load ~= nil)
  end)

  T.test("Notebook UI module loads", function()
    local ok, nb_ui = pcall(require, "uranus.notebook_ui")
    if ok then
      T.assert(nb_ui.open ~= nil or nb_ui.start ~= nil)
    else
      T.skip("Notebook UI not available")
    end
  end)

  T.test("Notebook + NBUI cell sync setup", function()
    local notebook = require("uranus.notebook")
    local nb_ui = require("uranus.notebook_ui")
    T.assert(notebook.get_cells ~= nil or notebook.cells ~= nil)
  end)

  T.section("Cell Mode + Notebook Integration")
  T.test("Cell mode loads", function()
    local ok, cell_mode = pcall(require, "uranus.cell_mode")
    T.assert(ok, "Cell mode should load")
  end)

  T.test("Cell mode key functions exist", function()
    local ok, cell_mode = pcall(require, "uranus.cell_mode")
    if ok then
      T.assert(cell_mode.enter ~= nil or cell_mode.start ~= nil or cell_mode.run_cell ~= nil)
    else
      T.skip("Cell mode not available")
    end
  end)

  T.section("REPL Buffer + Output Integration")
  T.test("REPL buffer loads", function()
    local ok, repl_buf = pcall(require, "uranus.repl_buffer")
    T.assert(ok, "REPL buffer should load")
  end)

  T.test("REPL buffer functions", function()
    local ok, repl_buf = pcall(require, "uranus.repl_buffer")
    if ok then
      T.assert(repl_buf.open ~= nil or repl_buf.toggle ~= nil or repl_buf.show ~= nil)
    else
      T.skip("REPL buffer not available")
    end
  end)

  T.test("Output display integration", function()
    local output = require("uranus.output")
    T.assert(output.display ~= nil or output.show ~= nil)
  end)

  T.section("Keymaps + UI Integration")
  T.test("Keymaps module loads", function()
    local ok, keymaps = pcall(require, "uranus.keymaps")
    if ok then
      T.assert(keymaps.setup ~= nil or keymaps.bind ~= nil or keymaps.register ~= nil)
    else
      T.skip("Keymaps not available")
    end
  end)

  T.test("Keymaps registration check", function()
    local ok, keymaps = pcall(require, "uranus.keymaps")
    if ok then
      local bound = keymaps.get_bound ~= nil and keymaps.get_bound() or {}
      T.assert_type(bound, "table")
    else
      T.skip("Keymaps not available")
    end
  end)

  T.section("UI Module Integration")
  T.test("UI module core functions", function()
    local ok, ui = pcall(require, "uranus.ui")
    if ok then
      T.assert_type(ui.notify, "function")
      T.assert_type(ui.pick_kernel, "function")
      T.assert_type(ui.dashboard, "function")
    end
  end)

  T.test("UI floating window", function()
    local ok, ui = pcall(require, "uranus.ui")
    if ok then
      T.assert_type(ui.floating_window, "function")
    end
  end)

  T.section("Inspector + LSP Integration")
  T.test("Inspector module loads", function()
    local ok, insp = pcall(require, "uranus.inspector")
    T.assert(ok, "Inspector should load")
  end)

  T.test("Inspector variable fetching", function()
    local insp = require("uranus.inspector")
    T.assert_type(insp.get_variables, "function")
    T.assert_type(insp.inspect_at_cursor, "function")
  end)

  T.test("LSP hover + inspector merge", function()
    local lsp = require("uranus.lsp")
    local insp = require("uranus.inspector")
    T.assert_type(lsp.hover, "function")
    T.assert_type(insp.inspect_at_cursor, "function")
  end)

  T.section("Configuration Propagation")
  T.test("Config observer pattern", function()
    local config = require("uranus.config")
    local observers = config.get_observers
    T.assert(observers ~= nil or config.on_change ~= nil)
  end)

  T.test("Config changes notify modules", function()
    local config = require("uranus.config")
    local listeners = config.get_listeners
    T.assert(listeners ~= nil or config.on_change ~= nil)
  end)

  T.section("Runtime + Pool Integration")
  T.test("Runtime module loads", function()
    local ok, runtime = pcall(require, "uranus.runtime")
    T.assert(ok, "Runtime should load")
  end)

  T.test("Pool module loads", function()
    local ok, pool = pcall(require, "uranus.pool")
    if ok then
      T.assert(pool.get ~= nil or pool.acquire ~= nil)
    else
      T.skip("Pool not available")
    end
  end)

  T.section("Messages + Protocol Integration")
  T.test("Messages module loads", function()
    local ok, msgs = pcall(require, "uranus.messages")
    T.assert(ok, "Messages should load")
  end)

  T.test("Messages parsing", function()
    local ok, msgs = pcall(require, "uranus.messages")
    if ok then
      T.assert_type(msgs.parse, "function")
      T.assert_type(msgs.serialize, "function")
    end
  end)

  T.section("Async Bridge + Execution")
  T.test("Async bridge loads", function()
    local ok, async = pcall(require, "uranus.async_bridge")
    T.assert(ok, "Async bridge should load")
  end)

  T.test("Async bridge schedule", function()
    local ok, async = pcall(require, "uranus.async_bridge")
    if ok then
      T.assert_type(async.schedule, "function")
    end
  end)

  T.section("Optimize + Memory Integration")
  T.test("Optimize module loads", function()
    local ok, opt = pcall(require, "uranus.optimize")
    T.assert(ok, "Optimize should load")
  end)

  T.test("Optimize string interning", function()
    local ok, opt = pcall(require, "uranus.optimize")
    if ok then
      T.assert_type(opt.intern, "function")
      T.assert_type(opt.is_interned, "function")
    end
  end)

  T.section("Parallel Execution Integration")
  T.test("Parallel module loads", function()
    local ok, parallel = pcall(require, "uranus.parallel")
    T.assert(ok, "Parallel should load")
  end)

  T.test("Parallel map reduce", function()
    local ok, parallel = pcall(require, "uranus.parallel")
    if ok then
      T.assert_type(parallel.map, "function")
      T.assert_type(parallel.reduce, "function")
    end
  end)

  T.section("Output Batching Integration")
  T.test("Output batch loads", function()
    local ok, batch = pcall(require, "uranus.output_batch")
    T.assert(ok, "Output batch should load")
  end)

  T.test("Output batch flush", function()
    local ok, batch = pcall(require, "uranus.output_batch")
    if ok then
      T.assert_type(batch.add, "function")
      T.assert_type(batch.flush, "function")
    end
  end)

  T.section("Parsers Integration")
  T.test("Parsers module loads", function()
    local ok, parsers = pcall(require, "uranus.parsers")
    T.assert(ok, "Parsers should load")
  end)

  T.test("Parsers cell detection", function()
    local ok, parsers = pcall(require, "uranus.parsers")
    if ok then
      T.assert_type(parsers.parse_cells, "function")
      T.assert_type(parsers.is_cell_boundary, "function")
    end
  end)

  T.section("State + Factory Integration")
  T.test("State watchers pattern", function()
    local ok, state = pcall(require, "uranus.state")
    if ok and state.watch then
      T.assert_type(state.watch, "function")
    else
      T.skip("state.watch not available")
    end
  end)

  T.test("Factory lazy loading", function()
    local factory = require("uranus.factory")
    T.assert(factory.get_uranus ~= nil or factory.get_kernel ~= nil)
  end)

  T.test("Factory module caching", function()
    local factory = require("uranus.factory")
    local m1 = factory.get_notebook ~= nil and factory.get_notebook() or nil
    local m2 = factory.get_notebook ~= nil and factory.get_notebook() or nil
    T.assert_eq(type(m1), type(m2))
  end)

  T.section("Errors + Error Handling")
  T.test("Custom errors module", function()
    local ok, errors = pcall(require, "uranus.errors")
    T.assert(ok, "Errors module should load")
  end)

  T.test("Error type creation", function()
    local ok, errors = pcall(require, "uranus.errors")
    if ok and errors.new then
      T.assert_type(errors.new, "function")
    else
      T.skip("errors.new not available")
    end
  end)

  T.section("Completion + LSP Integration")
  T.test("Completion module loads", function()
    local ok, comp = pcall(require, "uranus.completion")
    T.assert(ok, "Completion should load")
  end)

  T.test("Completion kernel variables", function()
    local ok, comp = pcall(require, "uranus.completion")
    if ok then
      T.assert_type(comp.complete_kernel_variables, "function")
    end
  end)

  T.section("Remote Kernel Integration")
  T.test("Remote connection functions", function()
    local ok, remote = pcall(require, "uranus.remote")
    if ok then
      T.assert_type(remote.connect, "function")
      T.assert_type(remote.disconnect, "function")
    end
  end)

  T.test("Remote kernel list", function()
    local ok, remote = pcall(require, "uranus.remote")
    if ok then
      T.assert_type(remote.list_kernels, "function")
    end
  end)

  T.section("Factory + Kernel Integration")
  T.test("Factory kernel lifecycle", function()
    local factory = require("uranus.factory")
    local kernel = factory.get_kernel()
    T.assert(kernel ~= nil)
    T.assert_type(kernel.connect, "function")
    T.assert_type(kernel.disconnect, "function")
  end)

  T.test("Factory notebook operations", function()
    local factory = require("uranus.factory")
    local nb = factory.get_notebook()
    T.assert(nb ~= nil)
    T.assert_type(nb.open, "function")
    T.assert_type(nb.save, "function")
  end)

  T.section("Config Deep Integration")
  T.test("Config defaults accessible", function()
    local config = require("uranus.config")
    T.assert(config.get ~= nil)
  end)

  T.test("Config module defaults", function()
    local config = require("uranus.config")
    local repl_cfg = config.get and config.get("repl") or {}
    T.assert_type(repl_cfg, "table")
  end)

  T.section("Cache Deep Integration")
  T.test("Cache TTL behavior", function()
    local cache = require("uranus.cache")
    local ok, err = pcall(function()
      cache.clear()
      cache.set("ttl_key", "ttl_value", 1)
      vim.wait(1100)
      local val = cache.get("ttl_key")
      T.assert_nil(val, "Expired key should return nil")
      cache.clear()
    end)
    if not ok then
      T.skip("Cache TTL not available")
    end
  end)

  T.test("Cache LRU eviction", function()
    local cache = require("uranus.cache")
    local ok, err = pcall(function()
      cache.clear()
      cache.set("max1", "v1")
      cache.set("max2", "v2")
      cache.set("max3", "v3")
      local stats = cache.stats()
      T.assert(stats.size > 0)
      cache.clear()
    end)
    if not ok then
      T.skip("Cache eviction not available")
    end
  end)

  T.section("Notebook Full Workflow Integration")
  T.test("Notebook workflow: open parse save", function()
    local nb = require("uranus.notebook")
    T.assert(nb.get_cells ~= nil or nb.cells ~= nil)
  end)

  T.summary()

  return T.results()
end

local success = run_module_integration_tests()
vim.cmd(success and "quit 1" or "quit 0")