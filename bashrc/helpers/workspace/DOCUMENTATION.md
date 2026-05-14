# `workspace/` documentation

This file documents the functionality present in `bashrc/helpers/workspace`.
Parent index: [`bashrc/helpers/INDEX.md`](../INDEX.md).

Requirements:

* XFCE/xfwm4 on X11.

## Files

### `workspace/wm-detect.sh`

Detects the current X11 window manager through EWMH properties.

CLI option notes:

* `--verbose` — debug details.
* `--validate WM` — require detected name to match.
* `--help` — show help.

Functions/methods defined:

* `print_help`
* `get_wm_name`

Requirements:

* `bash`, `xprop`, `awk`, `tr`.

### `workspace/ws-name.sh`

Sets XFCE workspace names by positional number/name pairs.

CLI option notes:

* Positional pairs: NUMBER NAME — set 1-based XFCE workspace NUMBER to NAME. No named flags are implemented.

Requirements:

* `bash` and `xfconf-query`.

### `workspace/ws-setup.sh`

Configures XFCE workspace count/names and optionally starts or moves applications by workspace.

CLI option notes:

* `--count N` — set workspace count.
* `--names A,B,C` — comma-separated workspace names.
* `--start IDX:CMD` — start command on 0-based workspace; repeatable.
* `--move IDX:REGEX` — move first matching window; repeatable.
* `--verbose` — extra output.
* `--help` — show help.

Functions/methods defined:

* `log`
* `die`
* `have_cmd`
* `print_help`
* `parse_args`
* `is_int`
* `xfconf_get_count`
* `xfconf_set_count`
* `xfconf_get_names_raw`
* `xfconf_get_names_list`
* `xfconf_set_names_from_array`
* `split_csv_to_array`
* `ensure_names_length`
* `wmctrl_current_desktop`
* `wmctrl_switch_desktop`
* `start_on_workspace`
* `move_first_matching_window_to_workspace`
* `main`

Requirements:

* `bash`, `xfconf-query`, `wmctrl`, `awk`, `sed`.
