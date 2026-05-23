# `theme/` documentation

* [`set-wallpaper.sh`](#set-wallpapersh)
* [Existing Markdown references](#existing-markdown-references)
* [Files](#files)
  * [`theme/color-steps.md`](#themecolor-stepsmd)
  * [`theme/color-steps.todo.md`](#themecolor-stepstodomd)
  * [`theme/color-steps.ts`](#themecolor-stepsts)

This file documents every file currently present in `bashrc/helpers/theme`.

Parent index: [`../INDEX.md`](../INDEX.md).

## `set-wallpaper.sh`

Sets a wallpaper across supported desktop backends.

CLI option notes:

* --wallpaper PATH — required image path.
* --mode auto|xfce|gnome|kde|sway|hyprland|feh — backend to use.
* --style fill|fit|stretch|center|tile — style hint mapped per backend.
* --log-file PATH — log file path.
* --verbose — echo log lines to CLI.
* --help — show help.

Functions/methods defined:

* `print_help`
* `fail_with_help`
* `log_message`
* `resolve_wallpaper_path`
* `have_command`
* `get_feh_style_flag`
* `get_xfce_style_value`
* `set_wallpaper_xfce`
* `set_wallpaper_gnome`
* `set_wallpaper_kde`
* `set_wallpaper_sway`
* `set_wallpaper_hyprland`
* `set_wallpaper_feh`
* `detect_mode`
* `parse_args`
* `validate_config`
* `apply_wallpaper`
* `main`

Requirements:

* bash, realpath or readlink, plus backend command: xfconf-query/xfdesktop, gsettings, qdbus/qdbus6, swaymsg, hyprctl, or feh.

## Existing Markdown references

* [`color-steps.md`](./color-steps.md)
* [`color-steps.todo.md`](./color-steps.todo.md)

## Files

### `theme/color-steps.md`

Existing guide for the CSS colour variable generator.

Documentation status: this is an existing Markdown document. The implementation-specific documentation below references it rather than duplicating all prose.

### `theme/color-steps.todo.md`

Todo notes for future colour generator documentation/features; not implemented behaviour.

Documentation status: this is an existing Markdown document. The implementation-specific documentation below references it rather than duplicating all prose.

### `theme/color-steps.ts`

Generates HSL CSS custom properties for colour ramps.

CLI option notes:

* --count NUMBER — number of colours.
* --mode dark|light|none — correction mode.
* --rotate-channel hue|saturation|lightness — channel to interpolate; implemented even though existing markdown focuses on hue.
* --start-hue NUMBER — starting hue.
* --end-hue NUMBER — ending hue.
* --saturation NUMBER — base saturation.
* --lightness NUMBER — base lightness.
* --variable-prefix STRING — CSS custom property prefix.
* --start-index NUMBER — first variable index.
* --decimals NUMBER — decimal places.
* --no-corrections — disable contrast corrections.
* --help — show help.

Functions/methods defined:

* `fail`
* `clamp`
* `round`
* `parseNumber`
* `parseInteger`
* `parseThemeMode`
* `parseRotateChannel`
* `readRequiredValue`
* `padVariableIndex`
* `isRatioInZone`
* `applyCorrections`
* `interpolate`
* `toHslString`
* `generateRainbowCssVariables`
* `parseCliArgs`
* `isDirectRun`
* `main`

Requirements:

* Node.js with TypeScript execution support.
