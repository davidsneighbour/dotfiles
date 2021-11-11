# themer - theme installation instructions

## atom-syntax

Use the `apm link` command to install the generated theme package to Atom:

    apm link 'atom-syntax/themer-dark-syntax'

Then open/reload Atom and select the desired theme in the list of available syntax themes.

## atom-ui

Use the `apm link` command to install the generated theme package to Atom:

    apm link 'atom-ui/themer-dark-ui'

Then open/reload Atom and select the desired theme in the list of available UI themes.

## chrome

1. Launch Chrome and go to `chrome://extensions`.
2. Check the "Developer mode" checkbox at the top.
3. Click the "Load unpacked extension..." button and choose the desired theme directory (`chrome/Themer Dark`).

(To reset or remove the theme, visit `chrome://settings` and click "Reset to Default" in the "Appearance" section.)

## css

Import the generated theme file into your stylesheet via `@import()`, or into your HTML markup via `<link>`.

`hex.css` provides the theme colors in hex format; `rgb.css` and `hsl.css` in RGB and HSL formats respectively along with individual channel values for further manipulation if desired.

Generated files:

* `css/hex.css`
* `css/rgb.css`
* `css/hsl.css`

## slack

Copy the contents of `slack/themer-slack-dark.txt` and paste into the custom theme input in Slack's preferences.

## sublime-text

1. Copy (or symlink) the generated theme files (`sublime-text/themer-sublime-text-dark.tmTheme`) to the `User/` packages folder (you can see where this folder is located by choosing the "Browse Packages..." menu option in Sublime Text).
2. Choose the theme from the list of available color themes.

## xresources

Copy the contents of 'xresources/themer-dark.Xresources' into your .Xresources configuration file, or load it with `xrdb`.

## vim

Copy or symlink `vim/ThemerVim.vim` to `~/.vim/colors/`.

Then set the colorscheme in `.vimrc`:

    " The background option must be set before running this command.
    colo ThemerVim

## wallpaper-block-wave

Files generated:

* `wallpaper-block-wave/themer-wallpaper-block-wave-dark-2880x1800.png`
* `wallpaper-block-wave/themer-wallpaper-block-wave-dark-750x1334.png`

## wallpaper-burst

Files generated:

* `wallpaper-burst/themer-wallpaper-burst-dark-2880x1800.png`
* `wallpaper-burst/themer-wallpaper-burst-dark-750x1334.png`

## wallpaper-circuits

Files generated:

* `wallpaper-circuits/themer-wallpaper-circuits-dark-2880x1800.png`
* `wallpaper-circuits/themer-wallpaper-circuits-dark-750x1334.png`

## wallpaper-diamonds

Files generated:

* `wallpaper-diamonds/themer-wallpaper-diamonds-dark-2880x1800.png`
* `wallpaper-diamonds/themer-wallpaper-diamonds-dark-750x1334.png`

## wallpaper-dot-grid

Files generated:

* `wallpaper-dot-grid/themer-wallpaper-dot-grid-dark-2880x1800-1.png`
* `wallpaper-dot-grid/themer-wallpaper-dot-grid-dark-2880x1800-2.png`
* `wallpaper-dot-grid/themer-wallpaper-dot-grid-dark-750x1334-1.png`
* `wallpaper-dot-grid/themer-wallpaper-dot-grid-dark-750x1334-2.png`

## wallpaper-octagon

Files generated:

* `wallpaper-octagon/themer-wallpaper-octagon-dark-2880x1800.png`
* `wallpaper-octagon/themer-wallpaper-octagon-dark-750x1334.png`

## wallpaper-shirts

Files generated:

* `wallpaper-shirts/themer-wallpaper-shirts-dark-2880-1800.png`
* `wallpaper-shirts/themer-wallpaper-shirts-dark-750-1334.png`

## wallpaper-triangles

Files generated:

* `wallpaper-triangles/themer-wallpaper-triangles-dark-2880x1800.png`
* `wallpaper-triangles/themer-wallpaper-triangles-dark-750x1334.png`

## wallpaper-trianglify

Files generated:

* `wallpaper-trianglify/themer-wallpaper-trianglify-dark-2880x1800-0.75-1.png`
* `wallpaper-trianglify/themer-wallpaper-trianglify-dark-750x1334-0.75-1.png`
* `wallpaper-trianglify/themer-wallpaper-trianglify-dark-2880x1800-0.75-2.png`
* `wallpaper-trianglify/themer-wallpaper-trianglify-dark-750x1334-0.75-2.png`