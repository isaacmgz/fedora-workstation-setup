-- Plugins managed by lazy.nvim
return {
  {
    "loctvl842/monokai-pro.nvim",
    config = function()
      require('monokai-pro').setup({ filter = 'spectrum' })
      vim.cmd('colorscheme monokai-pro')
    end,
  },
  { "nvim-treesitter/nvim-treesitter", run = ":TSUpdate" },
  { "neovim/nvim-lspconfig" },
  { "williamboman/mason.nvim", config = true },
  { "williamboman/mason-lspconfig.nvim" },
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "L3MON4D3/LuaSnip" },
  { "saadparwaiz1/cmp_luasnip" },
  { "nvim-telescope/telescope.nvim", requires = { { "nvim-lua/plenary.nvim" } } },
  { "nvim-lua/plenary.nvim" },
  { "lewis6991/gitsigns.nvim" },
  { "jose-elias-alvarez/null-ls.nvim" },
}
