# Rofi window switcher

The `window-switcher.sh` script provides a `rofi`-based Alt+Tab window switcher replacement.

It supports two window scopes:

* all open windows across all workspaces
* windows on the current workspace only

The script uses `rofi`'s built-in window modes:

* `window` for all windows
* `windowcd` for windows on the current desktop only

The script relies on `rofi`'s X11 window-switching support. It is not designed for Wayland sessions.

## Usage

```plaintext
Usage: window-switcher.sh [--scope all|workspace] [--help]

Show a rofi-based window switcher.

Options:
  --scope all          Show windows from all workspaces.
  --scope workspace    Show windows only from the current workspace.
  --help               Show this help message.

Examples:
  window-switcher.sh --scope all
  window-switcher.sh --scope workspace

Notes:
  * Default scope is: all
  * Requires: rofi
```

## Keyboard behaviour

The switcher is intended to be controlled from the keyboard with the following recommended baseline:

XFCE's keyboard shortcut menu does not expand shell variables in command fields. Use the literal absolute path there, replacing `<username>` with the local account name:

```bash
/home/<username>/.dotfiles/configs/system/rofi/window-switcher.sh --scope all
```

* `Alt+Tab`

  * command: `${DOTFILES_PATH}/configs/system/rofi/window-switcher.sh --scope all`
  * purpose: switch across all workspaces

* `Super+Tab`

  * command: `${DOTFILES_PATH}/configs/system/rofi/window-switcher.sh --scope workspace`
  * purpose: switch only inside the current workspace

Recommended navigation bindings inside `rofi`:

* `Alt+Tab` or `Down` to move down
* `Alt+Shift+Tab` or `Up` to move up
* `Alt+Escape` or `Escape` to cancel

The exact bindings are passed to `rofi` through options such as:

```bash
-kb-row-down
-kb-row-up
-kb-cancel
```
