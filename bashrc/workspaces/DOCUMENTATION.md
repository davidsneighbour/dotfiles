# bashrc/workspaces documentation

This folder provides CLI-first workspace automation for XFCE/Xubuntu. The user-facing overview and migration notes are in [`README.md`](./README.md); this document adds per-file coverage and option notes so the folder is included in the global bashrc documentation set.

Requirements for the command set: Bash, XFCE/xfwm4, `wmctrl`, `xdotool`, `xrandr`, `xprop`, `rofi`, `python3`, and optional Polybar integration. All user-facing commands follow the workspace logging contract in `ws-common.sh`: logs under `~/.logs/workspaces/<command>/YYYYMMDD-HHMMSS.log`; `--verbose` sets `DNB_VERBOSE=1`; `--quiet` disables verbose output.

## Shared files

### `AGENTS.md`

Agent instructions scoped to this folder. It requires `ws_*` command naming, CLI-first design, `--help`, `--verbose`, and `--quiet` for user-facing commands, and config/schema alignment.

### `README.md`

Primary human overview. It lists requirements, the `ws_*` namespace, command options, migration from older command names, and TOML schema usage.

### `ToDo.txt`

Planning notes only; not executable.

### `config.toml`

Workspace titles, launchable programs, rofi action labels, and tile template definitions.

### `config.schema.json`

JSON schema for `config.toml`.

### `ws-common.sh`

Shared workspace helper library. It parses common verbosity flags and initialises log paths for workspace commands.

Common options handled:

* `--verbose` — enable verbose logging.
* `--quiet` — disable verbose logging.

## User-facing and internal commands

### `ws_list_workspaces`

Lists available workspaces, optionally as names only.

Options: `-n`, `--name`, `--verbose`, `--quiet`, `--help`.

### `ws_list_windows`

Lists windows from `wmctrl`, with workspace filtering and sticky-window control.

Options: `--workspace-full`, `--full`, `--workspace N`, `--include-sticky`, `--verbose`, `--quiet`, `--help`.

### `ws_launch_program`

Launches a configured or explicit command on a workspace and can tile it.

Options: `--exec COMMAND`, `--workspace N|NAME`, `--tile TEMPLATE`, `--switch`, `--no-switch`, `--verbose`, `--quiet`, `--help`.

### `ws_move_active_window`

Moves the active window to another workspace.

Options: `--next`, `--prev`, `--to N`, `--follow`, `--verbose`, `--help`.

### `ws_open_on_workspace`

Runs a command on a specified workspace.

Options: `--workspace N`, `--command COMMAND`, `--verbose`, `--help`.

### `ws_tile_window`

Calculates monitor geometry and moves/resizes a target window according to explicit dimensions or a template.

Options: `--width 20-100`, `--height 20-100`, `--horizontal-anchor left|right`, `--horizontal-position 0-100`, `--vertical-anchor top|bottom`, `--vertical-position 0-100`, `--template NAME`, `--template-file PATH`, `--window-id ID`, `--verbose`, `--help`.

### `ws_rofi_actions`

Unified rofi entry point for start/move/tile flows.

Options: `--mode start|move|tile-move|select-tile-workspace-program`, optional `--workspace N|NAME` for supported flows, `--verbose`, `--quiet`, `--help`.

### `ws_menu_window_move`

Rofi menu for moving the active window to a selected workspace.

Options: `--verbose`, `--quiet`, `--help` plus any implementation-specific rofi/config flags shown by the command help.

### `ws_menu_window_tile`

Rofi menu for choosing a tile template and applying it to the active window.

Options: `--verbose`, `--quiet`, `--help` plus template/config flags shown by the command help.

### `ws_menu_window_tile_target`

Rofi menu for selecting a target window and applying tile behaviour.

Documented options from help include:

* `--template-file PATH` — path to TOML template file.
* `--tile-script PATH` — path to `ws_tile_window`.
* `--tile-menu-script PATH` — path to the tile menu script.
* `--verbose`, `--quiet`, `--help` — common command controls.

### `ws_generate_tile_svgs`

Generates SVG previews for tile templates under `tiles/generated/`.

Options: `--verbose`, `--quiet`, `--help` plus config/output flags shown by the command help.

## Generated tile previews

The `tiles/generated/*.svg` files are generated visual previews for tile templates. Current files: `full.svg`, `left-70.svg`, `left-half-spaced.svg`, `left-half.svg`, `quarter-bottom-left.svg`, `quarter-bottom-right.svg`, `quarter-top-left.svg`, `quarter-top-right.svg`, `right-70.svg`, `right-half-spaced.svg`, and `right-half.svg`.
