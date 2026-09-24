# Jenerated Themes for VS Code

A VS Code extension with one color theme for each palette you generate with
[jenerate.py](../jenerate.py). It comes with the default, Blue Purple. Each theme is named "Jenerated" plus the
palette's name, for example "Jenerated Blue Purple".

The theme files in `themes/` (`jenerated-<slug>-color-theme.json`) are
generated from `themes/color-theme.json.tmpl`, and `package.json` from
`package.json.tmpl`. To change colors, see
[Changing colors](../README.md#changing-colors).

## Try it without installing

Open this `vs-code-theme` folder (not the repository root) in
VS Code and press `F5`: it launches an Extension
Development Host with the themes available immediately.

## Install locally

1. Clone this repository. Blue Purple is included; to add other palettes,
   see [Getting started](../README.md#getting-started).

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   ```

2. Symlink or copy the folder into your extensions directory. A symlink
   means themes you generate or remove later show up after a reload; with
   a copy, you copy the folder again. Run these from
   the same folder where you ran `git clone`.

   ```bash
   # Symlink (ln needs an absolute path, hence $PWD)
   ln -s "$PWD/jenerated-themes/vs-code-theme" ~/.vscode/extensions/jenerated-themes

   # Or copy
   cp -r ./jenerated-themes/vs-code-theme ~/.vscode/extensions/jenerated-themes
   ```

3. Reload VS Code: open the Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`)
   and run "Developer: Reload Window", or restart VS Code.

4. Open the theme picker (`Ctrl+K Ctrl+T` / `Cmd+K Cmd+T`) and choose a
   Jenerated theme, for example "Jenerated Blue Purple".

## Package as a .vsix

```bash
npm install -g @vscode/vsce
cd ./jenerated-themes/vs-code-theme
vsce package
```

Then install the resulting `.vsix` via the Extensions view's "Install from
VSIX..." command, or `code --install-extension jenerated-themes-1.0.0.vsix`.
