# `theme/` documentation

* [`set-wallpaper.sh`](#set-wallpapersh)

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
