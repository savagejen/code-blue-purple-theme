# Jenerated Themes for Slack

Slack sidebar themes that match the VS Code themes.
[jenerate.py](../../jenerate.py) writes one `<slug>.txt` file for each palette
you generate, for example `blue-purple.txt`. Each file holds the theme string
you give Slack. [blue-purple.txt](blue-purple.txt) is included; to add other
palettes, see [Getting started](../../README.md#getting-started).

The files are generated from `slack-theme.txt.tmpl` by
[jenerate.py](../../jenerate.py). To change colors, see
[Changing colors](../../README.md#changing-colors).

## Apply a theme

### Option 1: paste it into a message

1. Copy the string from the theme's `.txt` file.
2. Paste it into any message box in Slack, such as a DM to yourself, and
   send it.
3. Slack shows a **Switch sidebar theme** button under the message. Click it.

### Option 2: set it in Preferences

1. Open **Preferences** (`Ctrl+,` / `Cmd+,`) and go to **Themes**.
2. Choose **Create a custom theme** (or **Custom theme**).
3. Paste the string into the theme field, or enter the colors one at a
   time using the table below.

Slack themes apply per workspace, so repeat this for each workspace.

## Colors

The string is 10 comma-separated hex values, in the order Slack expects. This
table shows which palette color fills each one:

| # | Slack setting    | Palette color |
|---|------------------|---------------|
| 1 | Column BG        | `bg_sidebar`  |
| 2 | Menu BG Hover    | `bg_hover`    |
| 3 | Active Item      | `accent`      |
| 4 | Active Item Text | `text_bright` |
| 5 | Hover Item       | `bg_hover`    |
| 6 | Text Color       | `text`        |
| 7 | Active Presence  | `green`       |
| 8 | Mention Badge    | `red`         |
| 9 | Top Nav BG       | `bg_chrome`   |
| 10| Top Nav Text     | `text`        |
