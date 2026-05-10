-- Basic LSP setup to be used with mason
local lspconfig = require('lspconfig')

local on_attach = function(client, bufnr)
  local buf_set_option = vim.api.nvim_buf_set_option
  buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
end

-- Servers will be installed via Mason normally; here we only configure defaults
local servers = { 'pyright', 'tsserver', 'lua_ls' }
for _, lsp in ipairs(servers) do
  if lspconfig[lsp] then
    lspconfig[lsp].setup({ on_attach = on_attach })
  end
end

return {}
