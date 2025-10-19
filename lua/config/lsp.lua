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


-- ── Global defaults for all servers (already above; keep as-is) ──────────────
-- vim.lsp.config("*", { capabilities = capabilities, flags = { debounce_text_changes = 500 } })

-- Helper
local function have(exe) return vim.fn.executable(exe) == 1 end

-- ── pylsp (formatter/linter/mypy/isort; venv-aware mypy) ─────────────────────
if have("pylsp") then
  local venv_path = os.getenv("VIRTUAL_ENV")
  local py_path = venv_path and (venv_path .. "/bin/python3") or vim.g.python3_host_prog
  vim.lsp.config("pylsp", {
    cmd = { "pylsp" },
    settings = {
      pylsp = {
        plugins = {
          black = { enabled = true },
          autopep8 = { enabled = false },
          yapf = { enabled = false },
          pylint = { enabled = true, executable = "pylint" },
          ruff = { enabled = false },
          pyflakes = { enabled = false },
          pycodestyle = { enabled = false },
          pylsp_mypy = {
            enabled = true,
            overrides = { "--python-executable", py_path, true },
            report_progress = true,
            live_mode = false,
          },
          jedi_completion = { fuzzy = true },
          isort = { enabled = true },
        },
      },
    },
    flags = { debounce_text_changes = 200 },
    capabilities = capabilities,
  })
  vim.lsp.enable("pylsp")
else
  vim.notify("pylsp not found!", vim.log.levels.WARN, { title = "Nvim-config" })
end

-- ── ltex-ls (grammar/spell) ──────────────────────────────────────────────────
if have("ltex-ls") then
  vim.lsp.config("ltex", {
    cmd = { "ltex-ls" }, -- set absolute path here if you use a custom install
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
  vim.lsp.enable("ltex")
end

-- ── clangd ───────────────────────────────────────────────────────────────────
if have("clangd") then
  vim.lsp.config("clangd", {
    cmd = { "clangd" },
    filetypes = { "c", "cpp", "cc" },
    flags = { debounce_text_changes = 500 },
    capabilities = capabilities,
  })
  vim.lsp.enable("clangd")
end

-- ── vim-language-server ──────────────────────────────────────────────────────
if have("vim-language-server") then
  vim.lsp.config("vimls", {
    cmd = { "vim-language-server", "--stdio" },
    flags = { debounce_text_changes = 500 },
    capabilities = capabilities,
  })
  vim.lsp.enable("vimls")
else
  vim.notify("vim-language-server not found!", vim.log.levels.WARN, { title = "Nvim-config" })
end

-- ── bash-language-server ─────────────────────────────────────────────────────
if have("bash-language-server") then
  vim.lsp.config("bashls", {
    cmd = { "bash-language-server", "start" },
    capabilities = capabilities,
  })
  vim.lsp.enable("bashls")
end

-- ── lua-language-server ──────────────────────────────────────────────────────
if have("lua-language-server") then
  vim.lsp.config("lua_ls", {
    cmd = { "lua-language-server" },
    settings = { Lua = { runtime = { version = "LuaJIT" } } },
    capabilities = capabilities,
  })
  vim.lsp.enable("lua_ls")
end

-- ── Simple servers (enable if binaries exist) ────────────────────────────────
-- Register minimal configs so enable() knows how to start them.
vim.lsp.config("pyright", { cmd = { "pyright-langserver", "--stdio" }, capabilities = capabilities })
vim.lsp.config("yamlls",  { cmd = { "yaml-language-server", "--stdio" }, capabilities = capabilities })
vim.lsp.config("ruff",    { cmd = { "ruff", "server" }, capabilities = capabilities })

local simple = {
  pyright = "pyright-langserver",
  yamlls  = "yaml-language-server",
  ruff    = "ruff",
}

for name, exe in pairs(simple) do
  if have(exe) then
    vim.lsp.enable(name)
  else
    vim.notify(
      ("Executable '%s' for server '%s' not found! Server will not be enabled"):format(exe, name),
      vim.log.levels.WARN, { title = "Nvim-config" }
    )
  end
end
