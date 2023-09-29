-- This is my personal Nvim configuration supporting Mac, Linux and Windows, with various plugins configured.
-- This configuration evolves as I learn more about Nvim and become more proficient in using Nvim.
-- Since it is very long (more than 1000 lines!), you should read it carefully and take only the settings that suit you.
-- I would not recommend cloning this repo and replace your own config. Good configurations are personal,
-- built over time with a lot of polish.
--
-- Author: Jiedong Hao
-- Email: jdhao@hotmail.com
-- Blog: https://jdhao.github.io/
-- GitHub: https://github.com/jdhao
-- StackOverflow: https://stackoverflow.com/users/6064933/jdhao

local api = vim.api
local utils = require("utils")

-- check if we have the latest stable version of nvim
local expected_ver = "0.9.1"
local nvim_ver = utils.get_nvim_version()

if nvim_ver ~= expected_ver then
  local msg = string.format("Unsupported nvim version: expect %s, but got %s instead!", expected_ver, nvim_ver)
  api.nvim_err_writeln(msg)
  return
end

local core_conf_files = {
  "globals.lua", -- some global settings
  "options.vim", -- setting options in nvim
  "autocommands.vim", -- various autocommands
  "mappings.lua", -- all the user-defined mappings
  "plugins.vim", -- all the plugins installed and their configurations
  "colorschemes.lua", -- colorscheme settings
}

-- source all the core config files
for _, name in ipairs(core_conf_files) do
  local path = string.format("%s/core/%s", vim.fn.stdpath("config"), name)
  local source_cmd = "source " .. path
  vim.cmd(source_cmd)
end

require'lspconfig'.pyright.setup{}
--require'lspconfig'.grammarly.setup { filetypes = "latex", init_options = { clientId = "client_BGjmY3spPxC4m2FkjRtXe6" } }
require("nvim-python-repl").setup()
require("nvim-lsp-installer").setup {}
local lspconfig = require('lspconfig')
lspconfig.tsserver.setup {}
--lspconfig.ltex.setup {}

--require'lspconfig'.grammarly.setup{filetypes = "latex"}
--require("grammar-guard").init()
require("lspconfig").ltex.setup({
  cmd = { '/home/patrick/.local/share/ltex-ls/ltex-ls-16.0.0/bin/ltex-ls' }, -- add this if you install ltex-ls yourself
	settings = {
		ltex = {
			enabled = { "latex", "tex", "bib", "markdown" },
			language = "en-US",
			diagnosticSeverity = "information",
			setenceCacheSize = 2000,
			additionalRules = {
				enablePickyRules = true,
				motherTongue = "en",
			},
			trace = { server = "verbose" },
			--dictionary = { "en-US": '/home/patrick/.config/nvim/spell/en.utf-8.add' },
			disabledRules = {},
			hiddenFalsePositives = {},
		},
	},
})
