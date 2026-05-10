Neovim configuration (dotfiles)
=================================

Descripción
-----------
Esta configuración de Neovim está adaptada para Fedora 44 y pensada para integrarse con el repo fedora-workstation-setup.
Usa lazy.nvim para gestionar plugins y el tema Monokai Pro (filtro: spectrum) por defecto.

Requisitos
----------
- Neovim >= 0.8 (recomendado 0.9+)
- ripgrep (rg), fd, nodejs, python3
- pip install --user pynvim

Instalación rápida
------------------
1. Clonar o copiar dotfiles a ~/.config/nvim (el script scripts/50-dotfiles.sh ofrece un paso para crear init.lua si falta).
2. Abrir Neovim: lazy.nvim hará el bootstrap y descargará plugins automáticamente.
3. Ejecutar :Mason y/o :Lazy sync para asegurar que servidores y plugins están instalados.

Bootstrap manual (si necesitás hacerlo a mano)
--------------------------------------------
Si preferís no esperar a que lazy.nvim haga el bootstrap al abrir nvim, podés ejecutar manualmente desde la terminal:

  git clone https://github.com/folke/lazy.nvim.git --branch=stable $(nvim --headless "echo stdpath('data')..'/lazy/lazy.nvim'" | tr -d '\n')

Luego abrí nvim y ejecutá :Lazy to ver el panel de plugins.

Funcionalidades clave
---------------------
- LSP gestionado por Mason + lspconfig (pyright, tsserver, lua_ls disponibles por defecto)
- Autocompletado con nvim-cmp
- Snippets via LuaSnip
- Búsquedas rápidas con Telescope
- Tree-sitter para resaltado y parsing mejorado
- Tema Monokai Pro Spectrum

Atajos principales
------------------
- <leader>ff — Buscar archivo (Telescope)
- <leader>fg — Búsqueda en proyecto (Telescope live_grep)
- <leader>ls — Listar diagnostics
- <leader>rn — Renombrar símbolo (LSP)

Personalización
---------------
Editar los archivos en dotfiles/nvim/lua/ para cambiar opciones, keymaps, plugins o esquema de colores.

Colores y Monokai Pro
---------------------
La configuración activa loctvl842/monokai-pro.nvim con el filtro "spectrum". Si querés otra variante:

  -- en dotfiles/nvim/lua/colorscheme.lua
  require('monokai-pro').setup({ filter = 'spectrum' })
  vim.cmd('colorscheme monokai-pro')

Cambiar filter a 'classic', 'pro', 'spectrum' u 'octagon' según la variante que prefieras.

Integración con scripts
-----------------------
El script scripts/50-dotfiles.sh crea un init.lua mínimo si no existe; sin embargo, para usar la configuración completa copia la carpeta dotfiles/nvim/ a ~/.config/nvim/ o crear un symlink:

  ln -s /path/to/repo/dotfiles/nvim ~/.config/nvim

Notas
-----
- Monokai Pro tiene variantes comerciales; este setup usa la implementación gratuita monokai-pro.nvim. Si tenés una versión comercial, podés ajustar los assets en lua/colorscheme.lua.
- Si los plugins no se instalan al abrir nvim, ejecutá :Lazy sync desde Neovim.

Solución de problemas comunes
-----------------------------
- Plugins no se instalan: asegurate que tu PATH incluye el bin dir de pip --user (ej.: ~/.local/bin) y que Neovim tiene permisos para escribir en $(nvim --headless "echo stdpath('data')" )/lazy.
- Mason no instala servers: abrí :Mason y buscá el server manualmente; algunos requieren dependencias del sistema (ej.: pyright necesita node).
- Python / pynvim: si Neovim no detecta Python, ejecutá python3 -m pip install --user pynvim y reiniciá nvim.
- Problemas con el tema Monokai Pro: si no se aplica, abrí :messages en nvim para ver errores de carga; quizá falten dependencias (termguicolors) o falta ejecutar :Lazy sync.

Contribuciones
--------------
Si querés proponer mejoras a esta configuración, por favor abrí un PR apuntando a pr/fedora44-workstation-tweaks o a feature branches específicas. Incluí en el PR cómo probar la configuración (pasos reproducibles) y si añadís plugins documentá por qué los incluís.
