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
  ws-placement.lua
scripts/
  restart-devilspie2.sh
  window-debug.sh
```

`chrome.lua` contains the active Chrome workspace rule. `debug.lua` prints the
window values Devilspie2 sees when `devilspie2 --debug` is running.
`ws-placement.lua` is the generic rule that `bashrc/workspaces/ws_launch_program`
depends on to move a just-launched window onto a specific workspace; see
"ws_launch_program placement" below.

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

## `ws_launch_program` placement

`bashrc/workspaces/ws_launch_program --workspace N` no longer moves the
launched window itself with a `wmctrl`/PID-polling loop. Instead it writes a
one-line state file — the target workspace number — to
`${XDG_RUNTIME_DIR:-/tmp}/ws-launch-placements/<pid>` right after launching the
command, keyed by the launched process's PID.

`config/ws-placement.lua` runs on every new window Devilspie2 sees. Devilspie2
has no `get_window_pid()`, so it reads the PID back off the window via the
standard `_NET_WM_PID` property (`get_window_property("_NET_WM_PID")`) instead,
looks for a matching state file, and if found calls `set_window_workspace()`
and deletes the file — so a request only ever fires once, and a reused PID can
never pick up a stale request. `ws_launch_program` also expires its own state
files after 15 seconds in case the launched program never opens a window.

This means Devilspie2 must be running for `ws_launch_program --workspace` to
have any effect; `ws_launch_program` checks for a running `devilspie2` process
and logs an error (but still launches the program) if it isn't.

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
