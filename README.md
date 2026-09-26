# Jenerated Themes

A small theming engine: pick a color palette, and `jenerate.py` (the
Jenerator) turns it into matching themes for every supported app. You only
get the palettes you ask for, so your apps' theme lists stay short.

The default palette, **Blue Purple**, comes already generated, so you can
install it in any app without running anything.

![VS Code with the Jenerated Blue Purple theme: the Explorer sidebar and a Python file in the editor](Screenshot.png)

## Supported apps

Each app has its own folder with a template and install instructions. They're
grouped the same way as in `./setup.sh`, which can also search for an app by
name. Apps marked (Linux) or (macOS) are only offered on that system.

### Web browsers

- [Chromium browsers (Chrome, Brave, Edge, Opera and more)](app-themes/chromium-theme/)
- [Firefox](app-themes/firefox-theme/)
- [Vivaldi](app-themes/vivaldi-theme/)
- [Zen Browser](app-themes/zen-theme/)

### Communication

- [Element (Matrix chat)](app-themes/element-theme/)
- [Mattermost](app-themes/mattermost-theme/)
- [Slack](app-themes/slack-theme/)

### Editors: code, text and notes

- [Emacs](app-themes/emacs-theme/)
- [GNOME text editors: gedit, GNOME Text Editor and Xed (and Pluma, Meld and more)](app-themes/gtksourceview-theme/) (Linux)
- [Godot](app-themes/godot-theme/)
- [JetBrains apps (IntelliJ IDEA, Android Studio, PyCharm, WebStorm and more)](app-themes/jetbrains-theme/)
- [LibreOffice (Writer, Calc, Impress and more)](app-themes/libreoffice-theme/)
- [Obsidian](app-themes/obsidian-theme/)
- [Qt Creator](app-themes/qtcreator-theme/)
- [RStudio](app-themes/rstudio-theme/)
- [Spyder](app-themes/spyder-theme/)
- [Sublime Text](app-themes/sublime-theme/)
- [Unreal Engine](app-themes/unreal-theme/)
- [Vim and Neovim](app-themes/vim-theme/)
- [VS Code](app-themes/vs-code-theme/)
- [Xcode](app-themes/xcode-theme/) (macOS)

### Terminals and command-line tools

- [fzf (fuzzy finder)](app-themes/fzf-theme/)
- [Ptyxis (Ubuntu terminal)](app-themes/ptyxis-theme/) (Linux)
- [Tilix (terminal)](app-themes/tilix-theme/) (Linux)
- [tmux](app-themes/tmux-theme/)
- [zsh (syntax highlighting and suggestions)](app-themes/zsh-theme/)

### Linux desktops

- [Decky Loader (Steam's Gaming Mode on SteamOS, Bazzite, CachyOS and more)](app-themes/decky-theme/)
- [GTK3 apps (GIMP, Inkscape, Thunar, GParted and more)](app-themes/gtk3-theme/)
- [KDE Plasma (Plasma and KDE apps, Konsole, Kate)](app-themes/kde-theme/)

### Entertainment

- [Jellyfin (media server)](app-themes/jellyfin-theme/)
- [mpv (media player)](app-themes/mpv-theme/)
- [OBS Studio (streaming and recording)](app-themes/obs-theme/)

### Other apps

- [Insomnia (API client)](app-themes/insomnia-theme/)

## Themes

A few premade palettes are included and can be previewed in
[palettes/README.md](palettes/README.md).

## Getting started

The quickest way is the setup script. Clone the repository and run it; it
asks which app and which theme you want, then does the rest (on Linux or
macOS). For most apps it first shows the commands that install the theme,
then offers to run them for you, linking the files (so they follow palette
changes) or copying them. It can also start the [Palette Creator](palette-creator/), for
designing a palette of your own:

```bash
git clone https://github.com/savagejen/jenerated-themes jenerated-themes
cd jenerated-themes
./setup.sh
```

### Setting up by hand

To use the default Blue Purple theme, clone the repository and follow the
install steps in each app's folder. To add other palettes (needs Python 3.11
or later):

1. Clone this repository:

   ```bash
   git clone https://github.com/savagejen/jenerated-themes jenerated-themes
   cd jenerated-themes
   ```

2. See which palettes are available (also listed under [Themes](#themes)):

   ```bash
   ./jenerate.py --list
   ```

3. Generate themes for the palettes you want, by slug. Separate several with
   commas, or run it again later to add more:

   ```bash
   ./jenerate.py sunset
   ./jenerate.py sunset,another-palette
   ```

4. Follow the install steps in each app's folder.

To remove a palette's themes again, run `./jenerate.py --remove sunset`.

## How it works

A palette is a small file in [palettes/](palettes/) that names each color by
its role: the editor background, text, the accent, error red, the terminal's
colors and so on. `jenerate.py` fills those colors into a template for each
app, and writes the themes next to the templates, named after the palette.
Themes you generated earlier are kept.

Generated themes stay out of git, so your copy holds only the palettes you
chose. Don't edit them by hand; change the palette and run `jenerate.py`
again.

## Light and dark palettes

Palettes can be dark or light. `jenerate.py` works out which from the
palette's editor background (`bg`): a palette is light if black text reads
better on it than white. A palette can also say which it is, with
`scheme = "dark"` or `scheme = "light"` after its `slug`. The themes follow:
VS Code and Firefox mark the theme dark or light, JetBrains themes build on
the IDE's dark or light theme, GTK3 themes on Adwaita's dark or light
version, Obsidian and Vim tell the app which it is, Godot uses its own
contrast setting for dark or light, and Chromium picks matching search
logos for the new tab page. The other apps just use the palette's colors.

Two text colors matter most for light palettes: `text_bright` is text on the
accent color (buttons, badges, selected menu items), and `text_strong` is
emphasized text on ordinary backgrounds (the active tab, the selected file).
On a dark palette both are usually white, so `text_strong = "text_bright"`;
on a light palette `text_bright` stays light for the accent, and
`text_strong` is dark, often just `"text"`.

## Changing colors

Edit a palette, for example `palettes/sunset-palette.toml`, then run
`./jenerate.py sunset` to regenerate its themes. Reload the apps that use it
to see the change.

You can also keep a palette outside this repository and pass its path:
`./jenerate.py ~/my-palettes/forest-palette.toml`.

## Adding a palette

The easiest way is the [Palette Creator](palette-creator/): run
`./setup.sh` and choose **Design a new palette**, or run
`./palette-creator/serve.py`. It shows a preview in your browser that
recolors as you edit. Save the palette to `palettes/`, then generate its
themes with `./jenerate.py <slug>`.

To write one by hand, copy an existing palette to
`palettes/<slug>-palette.toml`, change its `name`, `slug` and colors, and run
`./jenerate.py <slug>`. Every color the templates use must be defined; if one
is missing, `jenerate.py` stops and names it.

A few rules keep generated files safe and valid; `jenerate.py` checks them and
explains any that a palette breaks:

- The `slug` is used in file names, so it's lowercase letters, numbers and
  single dashes, like `deep-blue-sea`.
- A palette in `palettes/` must be named `<slug>-palette.toml`. (A palette
  kept elsewhere and passed by path can be named anything.)
- The `name` can't be empty, start or end with spaces, or contain double
  quotes, slashes, backslashes, `<`, `>`, `&` or line breaks. (It's written
  into JSON and XML files, and also names the Obsidian theme's folder.)
- Every color is a quoted string: `"#rrggbb"` or another color's name.
- `scheme` is optional: `"dark"` or `"light"`, for a palette whose editor
  background (`bg`) doesn't make that clear. See
  [Light and dark palettes](#light-and-dark-palettes).

## Contributing

To share a palette, add support for an app, or work on the project itself,
see [CONTRIBUTING.md](CONTRIBUTING.md). It covers how the templates work,
adding palettes and apps, the tests, screenshots, and the license.

## License

[MIT](LICENSE).
