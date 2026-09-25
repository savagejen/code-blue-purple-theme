# Jenerated Themes for Vim and Neovim

Colorschemes for [Vim](https://www.vim.org) (8 or later) and
[Neovim](https://neovim.io) that match the VS Code themes: the same syntax
colors, and the same 16 colors in the built-in terminal as the Ptyxis and
Tilix themes. [jenerate.py](../../jenerate.py) writes one colorscheme for each
palette you generate, named `jenerated-<slug>`, in `colors/`, for example
`colors/jenerated-blue-purple.vim`. Blue Purple is included; to add other
palettes, see [Getting started](../../README.md#getting-started).

The colorschemes use the palette's exact colors in GUI Vim, and in terminals
with `termguicolors` set. Without it, they fall back to the terminal's 16
colors, which the matching [Ptyxis](../ptyxis-theme/) or
[Tilix](../tilix-theme/) theme sets to the same palette. They only have a dark
version.

The colorschemes are generated from `colorscheme.vim.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Install

The easiest way is `./setup.sh` from the repository root: choose Vim. To
install by hand:

1. Clone this repository.

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   ```

2. This folder is a Vim package, so link it into Vim's (or Neovim's) package
   folder. Every palette you generate later is then available too. Run these
   from the same folder where you ran `git clone`:

   ```bash
   # Vim
   mkdir -p ~/.vim/pack/jenerated/start
   ln -s "$PWD/jenerated-themes/app-themes/vim-theme" ~/.vim/pack/jenerated/start/jenerated-themes

   # Neovim
   mkdir -p ~/.local/share/nvim/site/pack/jenerated/start
   ln -s "$PWD/jenerated-themes/app-themes/vim-theme" ~/.local/share/nvim/site/pack/jenerated/start/jenerated-themes
   ```

3. Try it with `:colorscheme jenerated-blue-purple`. To keep it, add this to
   `~/.vimrc`:

   ```vim
   set termguicolors
   colorscheme jenerated-blue-purple
   ```

   or, for Neovim, to `~/.config/nvim/init.lua`:

   ```lua
   vim.opt.termguicolors = true
   vim.cmd.colorscheme("jenerated-blue-purple")
   ```

   Leave out `termguicolors` if your terminal doesn't support true color.
