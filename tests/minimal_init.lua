-- Adds plenary and this plugin to runtimepath for headless test runs.
local plenary = vim.fn.expand('~/.local/share/nvim/lazy/plenary.nvim')
local root = vim.fn.getcwd()
vim.opt.runtimepath:append(plenary)
vim.opt.runtimepath:append(root)
vim.cmd('runtime plugin/plenary.vim')
