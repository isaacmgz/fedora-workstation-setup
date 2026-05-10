local o = vim.opt

o.number = true
o.relativenumber = true
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true
o.termguicolors = true
o.ignorecase = true
o.smartcase = true
o.cursorline = true
o.splitright = true
o.splitbelow = true
o.scrolloff = 4
o.signcolumn = "yes"

-- system clipboard when available
o.clipboard = "unnamedplus"

vim.g.mapleader = " "

return {}
