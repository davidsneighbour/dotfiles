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
  restart-devilspie2.sh
  window-debug.sh
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
    set_window_workspace(2)
end
```

`set_window_workspace()` is 1-based in Devilspie2, so `set_window_workspace(2)`
means workspace 2 even though X11/XFCE internals may expose workspace indices
from 0. If a rule lands one workspace too far to the right, test the adjacent
value. There is no `set_workspace()` function in this Devilspie2 build (it
changes the *active* workspace, which is `change_workspace()`) — using it by
mistake fails silently, since the script keeps running after a Lua error on an
undefined global.

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

Devilspie2 starts from XDG autostart, the same way `polybar.desktop` and
`guake.desktop` do, via:

```text
configs/system/autostart/locutus/devilspie2.desktop -> ~/.config/autostart/devilspie2.desktop
```

(`~/.config/autostart` is itself a symlink to `configs/system/autostart/${HOSTNAME}`,
set up by dotbot.)

This previously ran as a `systemd --user` service instead, but that service
reliably failed on every login with `cannot open display:` (trailing space in the
original journalctl output) — `systemd --user`
does not inherit `DISPLAY`/`XAUTHORITY` from the X11 session the way XFCE's own
autostart mechanism does, and nothing in this setup imported them. XDG
autostart avoids the problem entirely, at the cost of the automatic
restart-on-config-change and restart-on-crash behaviour the systemd path/service
pair used to provide.

Devilspie2 loads its Lua rules once at startup and does not hot-reload them, so
after editing a file under `~/.config/devilspie2` (i.e. `config/` in this
repository), reload it with:

```bash
configs/system/devilspie2/scripts/restart-devilspie2.sh
```

Bind that command to an XFCE keyboard shortcut under
`Settings -> Keyboard -> Application Shortcuts` if you want a reload hotkey.

## Manual intervention

The repository can provide the config and helper scripts. The following steps
still need to happen on the target desktop session:

* Install the `devilspie2`, `x11-utils`, and `x11-apps` packages if they are not
  already present.
* Log out and back in (or run `configs/system/devilspie2/scripts/restart-devilspie2.sh`
  once) so Devilspie2 picks up the new `~/.config/autostart/devilspie2.desktop`
  entry for the current session.
* Add an optional XFCE keyboard shortcut for `window-debug.sh` and for
  `configs/system/devilspie2/scripts/restart-devilspie2.sh`.
