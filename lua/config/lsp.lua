-- utils detection helper
local utils = require("utils")

-- ── Capabilities ──────────────────────────────────────────────────────────────
-- Prefer lsp_utils if present (new API), otherwise fall back to cmp_nvim_lsp.
local ok_utils, lsp_utils = pcall(require, "lsp_utils")
local capabilities
if ok_utils and lsp_utils.get_default_capabilities then
  capabilities = lsp_utils.get_default_capabilities()
else
  local ok_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
  if ok_cmp and cmp_lsp.default_capabilities then
    capabilities = cmp_lsp.default_capabilities()
  else
    capabilities = vim.lsp.protocol.make_client_capabilities()
  end
end

-- nvim-ufo folding capability (kept from old code)
capabilities.textDocument = capabilities.textDocument or {}
capabilities.textDocument.foldingRange = {
  dynamicRegistration = false,
  lineFoldingOnly = true,
}

-- ── UI: reference highlights & diagnostics/signs/hover ────────────────────────
-- Nice highlight for LSP references (from old code)
vim.cmd([[
  hi! link LspReferenceRead  Visual
  hi! link LspReferenceText  Visual
  hi! link LspReferenceWrite Visual
]])

-- Change diagnostic signs (from old code)
vim.fn.sign_define("DiagnosticSignError", { text = "🆇", texthl = "DiagnosticSignError" })
vim.fn.sign_define("DiagnosticSignWarn",  { text = "⚠️",  texthl = "DiagnosticSignWarn" })
vim.fn.sign_define("DiagnosticSignInfo",  { text = "ℹ️",  texthl = "DiagnosticSignInfo" })
vim.fn.sign_define("DiagnosticSignHint",  { text = "",  texthl = "DiagnosticSignHint" })

-- Global diagnostic behavior (from old code)
vim.diagnostic.config({
  underline = false,
  virtual_text = false,
  signs = true,
  severity_sort = true,
})

-- Global hover border (from old code). We'll keep this AND a per-K config.
vim.lsp.handlers["textDocument/hover"] =
  vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })

-- ── Per-buffer keymaps & behavior on attach ───────────────────────────────────
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp_buf_conf", { clear = true }),
  nested = true,
  desc = "Configure buffer keymaps & behavior based on LSP",
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client then return end

    local bufnr = event.buf

    -- keymap helper
    local function map(mode, lhs, rhs, opts)
      opts = opts or {}
      opts.silent = true
      opts.buffer = bufnr
      vim.keymap.set(mode, lhs, rhs, opts)
    end

    -- Deduping 'gd' (from new code) – keeps the clever on_list filter
    map("n", "gd", function()
      vim.lsp.buf.definition({
        on_list = function(options)
          local unique, seen = {}, {}
          for _, item in pairs(options.items or {}) do
            local key = (item.filename or "") .. (item.lnum or 0)
            if not seen[key] then
              seen[key] = true
              table.insert(unique, item)
            end
          end
          options.items = unique
          vim.fn.setloclist(0, {}, " ", options)
          if #options.items > 1 then
            vim.cmd.lopen()
          else
            vim.cmd([[silent! lfirst]])
          end
        end,
      })
    end, { desc = "Go to definition (deduped)" })

    -- Vanilla definition too (kept)
    map("n", "<C-]>", vim.lsp.buf.definition)

    -- Hover with constrained size (from new), still benefits from global rounded border
    map("n", "K", function()
      vim.lsp.buf.hover({
        border = "single",
        max_height = 20,
        max_width  = 130,
        close_events = { "CursorMoved", "BufLeave", "WinLeave", "LSPDetach" },
      })
    end, { desc = "Hover" })

    map("n", "<C-k>", vim.lsp.buf.signature_help)
    map("n", "<space>rn", vim.lsp.buf.rename,                    { desc = "Rename symbol" })
    map("n", "<space>ca", vim.lsp.buf.code_action,               { desc = "Code action" })
    map("n", "<space>wa", vim.lsp.buf.add_workspace_folder,      { desc = "Add workspace folder" })
    map("n", "<space>wr", vim.lsp.buf.remove_workspace_folder,   { desc = "Remove workspace folder" })
    map("n", "<space>wl", function() vim.print(vim.lsp.buf.list_workspace_folders()) end,
      { desc = "List workspace folders" })

    -- Prefer Pyright (or other) hover over Ruff's (from new code)
    if client.name == "ruff" then
      client.server_capabilities.hoverProvider = false
    end

    -- Inlay hints are optional; uncomment to enable:
    -- vim.lsp.inlay_hint.enable(true, { buffer = bufnr })

    -- Document highlights (merged: new autocmds + old highlight links)
    if client.server_capabilities.documentHighlightProvider then
      local gid = vim.api.nvim_create_augroup("lsp_document_highlight_" .. bufnr, { clear = true })
      vim.api.nvim_create_autocmd("CursorHold", {
        group = gid, buffer = bufnr,
        callback = function() vim.lsp.buf.document_highlight() end,
      })
      vim.api.nvim_create_autocmd("CursorMoved", {
        group = gid, buffer = bufnr,
        callback = function() vim.lsp.buf.clear_references() end,
      })
    end

    if vim.g.logging_level == "debug" then
      vim.notify(string.format("Language server %s started!", client.name),
                 vim.log.levels.DEBUG, { title = "Nvim-config" })
    end
  end,
})

-- ── Global defaults for all servers (new API) ─────────────────────────────────
vim.lsp.config("*", {
  capabilities = capabilities,
  flags = { debounce_text_changes = 500 },
})

-- ── Explicit lspconfig setups for servers that need custom settings (old code) ─
local ok_lspconfig, lspconfig = pcall(require, "lspconfig")
if ok_lspconfig then
  -- pylsp: formatter/linter/mypy/isort, venv-aware mypy executable
  if utils.executable("pylsp") then
    local venv_path = os.getenv("VIRTUAL_ENV")
    local py_path = venv_path and (venv_path .. "/bin/python3") or vim.g.python3_host_prog
    lspconfig.pylsp.setup({
      settings = {
        pylsp = {
          plugins = {
            -- formatters
            black = { enabled = true },
            autopep8 = { enabled = false },
            yapf = { enabled = false },
            -- linters
            pylint = { enabled = true, executable = "pylint" },
            ruff = { enabled = false },
            pyflakes = { enabled = false },
            pycodestyle = { enabled = false },
            -- type checking
            pylsp_mypy = {
              enabled = true,
              overrides = { "--python-executable", py_path, true },
              report_progress = true,
              live_mode = false,
            },
            -- completion
            jedi_completion = { fuzzy = true },
            -- import sorting
            isort = { enabled = true },
          },
        },
      },
      flags = { debounce_text_changes = 200 },
      capabilities = capabilities,
    })
  else
    vim.notify("pylsp not found!", vim.log.levels.WARN, { title = "Nvim-config" })
  end

  -- ltex-ls (grammar/spell)
  if utils.executable("ltex-ls") then
    lspconfig.ltex.setup({
      -- If you installed a specific binary, set cmd here; otherwise use "ltex-ls"
      -- cmd = { "/home/patrick/.local/share/ltex-ls/ltex-ls-16.0.0/bin/ltex-ls" },
      filetypes = { "text", "plaintex", "tex", "markdown" },
      settings = {
        ltex = {
          language = "en-US",
          diagnosticSeverity = "information",
          setenceCacheSize = 2000,
          additionalRules = { enablePickyRules = true, motherTongue = "en" },
          trace = { server = "verbose" },
        },
      },
      flags = { debounce_text_changes = 300 },
      capabilities = capabilities,
    })
  end

  -- clangd
  if utils.executable("clangd") then
    lspconfig.clangd.setup({
      filetypes = { "c", "cpp", "cc" },
      flags = { debounce_text_changes = 500 },
      capabilities = capabilities,
    })
  end

  -- vim-language-server
  if utils.executable("vim-language-server") then
    lspconfig.vimls.setup({
      flags = { debounce_text_changes = 500 },
      capabilities = capabilities,
    })
  else
    vim.notify("vim-language-server not found!", vim.log.levels.WARN, { title = "Nvim-config" })
  end

  -- bash-language-server
  if utils.executable("bash-language-server") then
    lspconfig.bashls.setup({ capabilities = capabilities })
  end

  -- lua-language-server
  if utils.executable("lua-language-server") then
    lspconfig.lua_ls.setup({
      settings = { Lua = { runtime = { version = "LuaJIT" } } },
      capabilities = capabilities,
    })
  end
end

-- ── Turn on “generic” servers with the new API, when binaries exist ───────────
-- Skip ones we already configured explicitly above.
local explicitly_configured = {
  pylsp = true, ltex = true, clangd = true, vimls = true, bashls = true, lua_ls = true,
}

local enabled_lsp_servers = {
  pyright = "pyright-langserver",   -- fixed executable name
  ruff    = "ruff",
  yamlls  = "yaml-language-server",
  -- Add others here as you like; they’ll inherit defaults from vim.lsp.config("*", ...)
}

for server_name, exe in pairs(enabled_lsp_servers) do
  if not explicitly_configured[server_name] then
    if utils.executable(exe) then
      vim.lsp.enable(server_name)
    else
      vim.notify(
        string.format("Executable '%s' for server '%s' not found! Server will not be enabled", exe, server_name),
        vim.log.levels.WARN,
        { title = "Nvim-config" }
      )
    end
  end
end
