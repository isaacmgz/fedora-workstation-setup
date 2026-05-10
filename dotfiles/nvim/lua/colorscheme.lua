-- colorscheme config
local ok, monokai = pcall(require, 'monokai-pro')
if ok and monokai then
  monokai.setup({ filter = 'spectrum' })
  vim.cmd('colorscheme monokai-pro')
else
  -- fallback to default colorscheme
  vim.cmd('syntax enable')
end

return {}
