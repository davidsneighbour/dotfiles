# Workspace CLI (XFCE/Xubuntu 25.10)

This folder provides CLI-first workspace automation for XFCE on Xubuntu 25.10 with `wmctrl`, `xdotool`, `xrandr`, `rofi`, and optional Polybar usage.

## Requirements

* XFCE (xfwm4) on Xubuntu 25.10
* `wmctrl`, `xdotool`, `xrandr`, `xprop`, `rofi`, `python3`
* Bash

## Logging and verbosity

* `--verbose` enables verbose logging (`DNB_VERBOSE=1`).
* `--quiet` disables verbose logging.
* Logs are written to `~/.logs/workspaces/<command>/YYYYMMDD-HHMMSS.log`.

## Command namespace (`ws_*`)

### `ws_list_workspaces`

* `-n, --name`
* `--verbose`
* `--quiet`
* `--help`

### `ws_list_windows`

* `--workspace-full`
* `--full`
* `--workspace <N>`
* `--include-sticky`
* `--verbose`
* `--quiet`
* `--help`

### `ws_launch_program`

* `--exec <command>`
* `--workspace <N|NAME>`
* `--tile <template>`
* `--switch`
* `--no-switch`
* `--verbose`
* `--quiet`
* `--help`

### `ws_move_active_window`

* `--next`
* `--prev`
* `--to <N>`
* `--follow`
* `--verbose`
* `--help`

### `ws_open_on_workspace`

* `--workspace <N>`
* `--command <cmd>`
* `--verbose`
* `--help`

### `ws_tile_window`

* `--width <20-100>`
* `--height <20-100>`
* `--horizontal-anchor <left|right>`
* `--horizontal-position <0-100>`
* `--vertical-anchor <top|bottom>`
* `--vertical-position <0-100>`
* `--template <name>`
* `--template-file <path>`
* `--window-id <id>`
* `--verbose`
* `--help`

### `ws_rofi_actions`

Unified rofi entry point:

* `--mode start`
  * rofi prompt to start a program
  * optional `--workspace <N|NAME>`
* `--mode move`
  * select workspace and move active window
* `--mode tile-move`
  * select tile template and apply to active window
* `--mode select-tile-workspace-program`
  * select workspace, then select running program/window and apply tile flow
* Also supports: `--verbose`, `--quiet`, `--help`

## Internal ws_ helpers

* `ws_menu_window_move`
* `ws_menu_window_tile`
* `ws_menu_window_tile_target`
* `ws_generate_tile_svgs`

## Migration (old > new)

* `dnb_workspaces` > `ws_list_workspaces`
* `dnb_windows` > `ws_list_windows`
* `wm-launch.sh` > `ws_launch_program`
* `wm-open-on-workspace.sh` > `ws_open_on_workspace`
* `wm-tile-window.sh` > `ws_tile_window`
* `wm-wmanagement.sh` > `ws_move_active_window`
* `menu-window-move.sh` > `ws_menu_window_move`
* `menu-window-tile.sh` > `ws_menu_window_tile`
* `menu-window-tile-target.sh` > `ws_menu_window_tile_target`
* `generate-tile-svgs.sh` > `ws_generate_tile_svgs`

## One-line setup procedure example

Open two programs tiled on workspace 6 and switch to workspace 6:

```bash
ws_launch_program --workspace 6 --tile left-half --exec "program1" && ws_launch_program --workspace 6 --tile right-half --exec "program2" && wmctrl -s 5
```

Alternative order (switch first):

```bash
wmctrl -s 5 && ws_launch_program --workspace 6 --tile left-half --exec "program1" && ws_launch_program --workspace 6 --tile right-half --exec "program2"
```

## TOML schema

* Config file: `bashrc/workspaces/config.toml`
* Schema file: `bashrc/workspaces/config.schema.json`

Use with Taplo or schema-aware editors by mapping `config.toml` to `config.schema.json`.
