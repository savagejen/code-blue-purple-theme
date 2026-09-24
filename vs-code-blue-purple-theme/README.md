# code-blue-purple

A dark blue/purple Visual Studio Code theme with high contrast text, tuned for a deeper, near-black 'midnight' background.

- Background: near-black navy (`#12131c`), with darker chrome (`#0a0b13`) for
  the activity bar, title bar, and status bar.
- Accent: Medium blue-purple (`#5865F2`) for cursor, selection, focus, and
  interactive elements, with pale blue-purple (`#7289DA`) for keywords/links.
- Syntax colors are high contrast: green (`#57F287`) for
  strings, red (`#ED4245`) for errors, yellow (`#FEE75C`) for warnings,
  fuchsia (`#EB459E`) for constants.

## Try it without installing

Open this `vs-code-blue-purple-theme` folder (not the repository root) in
VS Code and press `F5`: it launches an Extension
Development Host with the theme available immediately.

## Install locally

1. Clone this repository:

   ```bash
   git clone https://github.com/savagejen/blue-purple-themes blue-purple-themes
   ```

2. Symlink or copy the folder into your extensions directory. A symlink
   means later edits to the theme show up after a reload. Run these from
   the same folder where you ran `git clone`.

   ```bash
   # Symlink (ln needs an absolute path, hence $PWD)
   ln -s "$PWD/blue-purple-themes/vs-code-blue-purple-theme" ~/.vscode/extensions/code-blue-purple-theme

   # Or copy
   cp -r ./blue-purple-themes/vs-code-blue-purple-theme ~/.vscode/extensions/code-blue-purple-theme
   ```

3. Reload VS Code: open the Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`)
   and run "Developer: Reload Window", or restart VS Code.

4. Open the theme picker (`Ctrl+K Ctrl+T` / `Cmd+K Cmd+T`) and choose
   "code-blue-purple".

## Package as a .vsix

```bash
npm install -g @vscode/vsce
cd ./blue-purple-themes/vs-code-blue-purple-theme
vsce package
```

Then install the resulting `.vsix` via the Extensions view's "Install from
VSIX..." command, or `code --install-extension code-blue-purple-1.0.0.vsix`.
