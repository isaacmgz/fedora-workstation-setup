-- init.lua - Neovim configuration (bootstrapped with lazy.nvim)
-- This file is intended to live at: ~/.config/nvim/init.lua

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Load core modules
local ok, _ = pcall(require, "options")
if not ok then
  -- options may be absent in fallback minimal setup
  -- continue anyway
end
pcall(require, "keymaps")
pcall(require, "plugins")
pcall(require, "colorscheme")
pcall(require, "lsp")
