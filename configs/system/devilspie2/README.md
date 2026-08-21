# Devilspie2

Devilspie2 applies small Lua rules to X11 windows as they appear. In this setup,
the rule directory is managed from this repository:

```text
configs/system/devilspie2/config -> ~/.config/devilspie2
```

The symlink means files such as `config/chrome.lua` are the source of truth and
are loaded by Devilspie2 through `~/.config/devilspie2`.

## Files

```text
config/
  chrome.lua
  debug.lua
scripts/
  install-session-autostart.sh
  window-debug.sh
systemd/user/
  devilspie2.path
  devilspie2-restart.service
  devilspie2.service
```

`chrome.lua` contains the active Chrome workspace rule. `debug.lua` prints the
window values Devilspie2 sees when `devilspie2 --debug` is running.

## Install

Install the package through the system package manager:

```bash
sudo apt install devilspie2
```

Reference links:

* [https://github.com/dsalt/devilspie2/releases](https://github.com/dsalt/devilspie2/releases)
* [https://packages.debian.org/search?keywords=devilspie2](https://packages.debian.org/search?keywords=devilspie2)

## Rules

Rules are Lua files. A basic Chrome rule looks like this:

```lua
if get_window_class() == "Google-chrome" then
    set_workspace(2)
end
```

`set_workspace()` is normally 1-based in Devilspie2, so `set_workspace(2)` means
workspace 2 even though X11/XFCE internals may expose workspace indices from 0.
If a rule lands one workspace too far to the right, test the adjacent value.

Prefer stable window identity values over titles. For Chrome, the class or class
group is usually more reliable than the window name, because titles change with
the active tab.

## Debugging windows

Use the repository helper to inspect an X11 window:

```bash
configs/system/devilspie2/scripts/window-debug.sh
```

The command asks you to click one window, writes useful `xprop` and `xwininfo`
output to a temporary file, and opens that file in an editor.

Useful options:

```bash
configs/system/devilspie2/scripts/window-debug.sh --print
configs/system/devilspie2/scripts/window-debug.sh --editor subl
configs/system/devilspie2/scripts/window-debug.sh --output /tmp/window-debug.txt
```

For an XFCE shortcut, bind this command under
`Settings -> Keyboard -> Application Shortcuts`:

```bash
/home/patrick/github.com/davidsneighbour/dotfiles/configs/system/devilspie2/scripts/window-debug.sh
```

The most useful `xprop` values map to Devilspie2 like this:

```text
xprop value               Devilspie2 function
------------------------------------------------
WM_CLASS first value      get_class_instance_name()
WM_CLASS second value     get_class_group_name()
WM_CLASS / class          get_window_class()
WM_NAME / _NET_WM_NAME    get_window_name()
WM_WINDOW_ROLE            get_window_role()
```

To see what Devilspie2 itself sees, run:

```bash
devilspie2 --debug
```

Then open a new target window. The `config/debug.lua` file prints basic window
values in the debug output.

## Session autostart

For XFCE, run Devilspie2 from `systemd --user` at session login. This gives
startup, restart-on-failure, journal logs, and an automatic restart when rule
files change.

Install and enable the user units with:

```bash
configs/system/devilspie2/scripts/install-session-autostart.sh
```

The installer copies these files into `~/.config/systemd/user/`:

```text
systemd/user/devilspie2.service
systemd/user/devilspie2.path
systemd/user/devilspie2-restart.service
```

It then runs:

```bash
systemctl --user daemon-reload
systemctl --user enable --now devilspie2.service
systemctl --user enable --now devilspie2.path
```

Manual management commands:

```bash
systemctl --user status devilspie2.service
systemctl --user restart devilspie2.service
journalctl --user -u devilspie2.service -f
systemctl --user status devilspie2.path
```

For a keyboard shortcut to reload rules, bind:

```bash
systemctl --user restart devilspie2.service
```

`devilspie2.path` watches `~/.config/devilspie2`, which is the symlinked config
directory. Watching the directory copes better with editors that save files via
atomic replacement.

## Manual intervention

The repository can provide the config, helper scripts, and unit files. The
following steps still need to happen on the target desktop session:

* Install the `devilspie2`, `x11-utils`, and `x11-apps` packages if they are not
  already present.
* Run `scripts/install-session-autostart.sh` from inside the logged-in XFCE/X11
  session so `systemctl --user` talks to the right user manager.
* Add optional XFCE keyboard shortcuts for `window-debug.sh` and
  `systemctl --user restart devilspie2.service`.
