<!-- markdownlint-disable-next-line title-case-style -->
# SESSION.md

Authoritative technical reference for how the graphical desktop session on this workstation is assembled and started. This is operational documentation for agents and maintainers, not a user-facing guide — see `README.md` for that.

Read this file (and `AGENTS.md`) before changing anything that affects i3, Polybar, Rofi, X11/Xorg, LightDM/session selection, startup scripts, environment setup, wallpaper/background, notifications, compositor, monitors, input sharing, workspace behaviour, window assignment, screen locking, suspend/logout controls, or related session services. **Any such change must update this file in the same change.**

The desktop session is i3. XFCE is installed on the host but is not configured by this repository; all graphical desktop features target i3.

## Display manager and available sessions

* Display manager: **LightDM** (`/etc/lightdm/`), Debian/Ubuntu defaults (`session-wrapper=/etc/X11/Xsession`, GTK greeter).
* Installed X sessions (`/usr/share/xsessions/`): `i3.desktop`, `i3-with-shmlog.desktop`, `xfce.desktop`, `xubuntu.desktop`, and `lightdm-xsession.desktop`. None of them are managed by this repository.
* Default session (`~/.dmrc`): **`i3`**.
* `i3.desktop`'s `Exec=i3` starts i3 with no special environment. i3 reads `~/.config/i3/config`, which Dotbot links into this repository.

## Repository paths to runtime paths

```text
Repository                     Runtime
----------                     -------
configs/session/i3/         -> ~/.config/i3          (Dotbot link)
configs/session/rofi/       -> ~/.config/rofi        (Dotbot link)
configs/session/dunst/      -> ~/.config/dunst       (Dotbot link)
configs/session/terminator/ -> ~/.config/terminator  (Dotbot link)
configs/session/thunar/     -> ~/.config/Thunar      (Dotbot link)
configs/session/launchers/  -> ~/.local/share/applications (Dotbot link)
configs/session/polybar/    -> (not linked; launch.sh is called by repo path from i3)
configs/fonts/              -> ~/.fonts              (Dotbot link; the desktop set is
                                                      configs/session/fonts/, exposed as
                                                      ~/.fonts/dotfiles)
```

Dotbot config: `configs/dotbot/config.yaml`, run via the `dotfiles` wrapper (`bashrc/helpers/dotfiles`; see `configs/dotbot/README.md`). `~/.config/polybar/` is a plain local folder that holds runtime data such as `issues.toml` for the msgvault module; it is not a link into this repository.

## Session architecture

```text
LightDM
└── i3  (default session, ~/.dmrc)
    └── Xorg
        ├── i3 (configs/session/i3/config)
        │   ├── keybindings (see "Keybinding architecture")
        │   ├── numbered icon workspaces 1-9, generated from
        │   │   configs/session/i3/workspaces/workspaces.yaml
        │   └── window rules (configs/session/i3/configs/rules.conf)
        ├── Rofi (configs/session/rofi/, configs/session/i3/rofi.rasi)
        ├── Polybar (configs/session/polybar/, started by launch.sh)
        ├── fonts (configs/session/fonts/, exposed at ~/.fonts/dotfiles)
        ├── background (xsetroot solid colour, then feh wallpaper)
        ├── notifications (dunst, D-Bus-activated — see "Notifications")
        └── screen lock (xss-lock systemd user unit → lock.sh)
```

## Startup sequence

1. LightDM starts `i3` (`Exec=i3` from `/usr/share/xsessions/i3.desktop`).
2. Xorg initialises the graphical session. No i3-specific Xorg configuration exists.
3. i3 reads `~/.config/i3/config` (linked to `configs/session/i3/config`), which includes `configs/session/i3/configs/session-starts.conf`.
4. i3 runs the `exec`/`exec_always` lines of `session-starts.conf` in the order shown in the table below.

i3 has no session manager, so it does not read XDG autostart (`~/.config/autostart`). Everything that must start with the session is in `session-starts.conf`.

| Component | Command | `exec` vs `exec_always` | Failure mode |
| --- | --- | --- | --- |
| Colour scheme | `bashrc/helpers/session-colour-scheme --apply` | `exec_always` | Non-fatal (`\|\| true`). See "Session colour scheme". |
| GNOME Keyring D-Bus components | `gnome-keyring-daemon --start --components=pkcs11,secrets` | `exec_always` | Non-fatal. Registers the Secret Service on the session bus so libsecret apps (for example VS Code) find a keyring. PAM already starts and unlocks the daemon at login. |
| Polkit agent | `/usr/libexec/polkit-mate-authentication-agent-1` | `exec` | Non-fatal. Without it, `pkexec` has no graphical agent. |
| Root background colour | `xsetroot -solid '#0B0D0F'` | `exec_always` | Non-fatal. |
| Polybar | `configs/session/polybar/launch.sh` | `exec_always` | Non-fatal; i3 stays usable without a bar. |
| Enpass | `session-colour-scheme --tool enpass -- --minimize` | `exec` | Non-fatal. Starts once per session so it does not prompt again on every i3 restart. |
| Barrier | `/usr/bin/barrier` | `exec` | Non-fatal. Keyboard and mouse sharing; config at `configs/session/barrier/barrier.conf`. |
| Discord | `/usr/bin/discord --start-minimized` | `exec` | Non-fatal. Starts in the tray. |
| WhatsApp | `~/.local/bin/chrome-app --app whatsapp` | `exec` | Non-fatal. Starts once per login and reuses an existing app window. |
| xss-lock | `systemctl --user start xss-lock.service` (after `import-environment` and `reset-failed`) | `exec_always` | Non-fatal. See "Screen lock". |
| Wallpaper | `feh --bg-fill configs/session/i3/wallpaper.jpg` | `exec_always` | Non-fatal. |
| Google Drive mounts | `configs/session/storage/gdrive-mounts.sh` | `exec` | Non-fatal. See `configs/session/storage/README.md`. |
| System checkup | `sleep 120; tools/system-checkup/system-checkup --quiet` | `exec` | Non-fatal. Also runs from cron every 6 hours. Writes `~/.local/state/system-checkup/report.txt`; the Polybar `system-checkup` module shows an alert icon only when a check failed or the last run is older than 13 hours. See `tools/system-checkup/README.md`. |

`exec_always` is used for the background, wallpaper, Polybar, and xss-lock so that `i3-msg restart` (`$mod+Shift+r`) runs them again. `launch.sh` kills the old bar before it starts a new one, and `systemctl --user start` is a no-op for a running unit, so neither duplicates. `exec` is used for applications that must start only once per session.

User-triggered programs:

| Component | Trigger | Command |
| --- | --- | --- |
| Rofi launcher | bare `Super_L` release, `$mod+Shift+d`, `$mod+d` | `rofi -show drun -config configs/session/i3/rofi.rasi` (see "Rofi") |
| Terminal | `$mod+Return` | `$terminal` (`terminator`) |

## Keybinding architecture

Defined in `configs/session/i3/config` and its includes in `configs/session/i3/configs/` (`keybindings.conf`, `applications.conf`). `$mod` is `Mod4` (Super/Windows key). Before you add or change a binding — especially one that runs `exec` with a script and arguments, or that drives i3 workspaces, marks, or containers — read [`.agents/instructions/session/i3-keybindings.instructions.md`](.agents/instructions/session/i3-keybindings.instructions.md). `i3 -C -c` does not catch every way a binding can be broken. That file documents the error shapes, the rule that program-launch bindings use `Ctrl+Shift+Alt+<key>`, and how to verify a binding. The full table, which **MUST** be kept in sync with any binding change, is [`docs/i3-keybindings.md`](docs/i3-keybindings.md).

### Bare `Super` key limitation

i3's `bindsym` grammar binds a modifier combined with a keysym, not a bare modifier alone. This is implemented as:

```text
bindsym --release Super_L exec --no-startup-id $rofi_new_workspace
```

`--release` scopes it to "`Super_L` pressed and released with nothing else pressed in between", so it does not conflict with `$mod+<key>` bindings. If this is unreliable on a given keyboard or X11 setup, `$mod+Shift+d` runs the same command.

## Window rules

`configs/session/i3/configs/rules.conf` holds the `for_window`/`assign` rules. It is included from `configs/session/i3/config` separately from `keybindings.conf` and `applications.conf`.

| Match | Effect | Purpose |
| --- | --- | --- |
| `window_role="window-inspector"` | float, `700x540`, centred | Report terminal of `window-inspector.sh` |
| `window_role="msgvault-sync"` | float | Manual-sync terminal of the msgvault Polybar module; `tools/msgvault/sync-terminal` sets the size |
| `window_role="scratch-terminal"` | mark `scratch-terminal`, float, move to scratchpad | Scratch terminal (see "Scratch terminal") |
| `class="dnb-clockify-form"` | float, `700x760`, centred, focus | Clockify form (see "Clockify form window") |
| `class="dnb-tasks"` | float, `50ppt x 80ppt`, centred, focus | Tasks app (`Ctrl+Shift+Alt+P`, `configs/session/tasks/tasks-window`) |
| `class="obsidian"` | `assign` to `$ws5` | Obsidian always opens on workspace 5 |
| `class="Enpass" instance="Enpass"` | width `33ppt` | Enpass main window |
| `class="Google-chrome"` with `window_type` `dropdown_menu` or `popup_menu` | float, no border | Chrome dropdown and popup menus |

### Window inspector

`configs/session/i3/window-inspector.sh` (`Ctrl+Shift+Alt+I`) is an admin tool for finding a window's `WM_CLASS`, role, title, PID, and geometry, so it can be targeted by a `for_window`/`assign` rule. It:

1. Runs `xdotool selectwindow` — a crosshair cursor; click any window to pick it.
2. Prints that window's details (`xdotool getwindowname`/`getwindowpid`/`getwindowgeometry`, `xprop WM_CLASS`/`WM_WINDOW_ROLE`/`WM_NAME`/`_NET_WM_PID`, and its `wmctrl -lxp` line), plus a ready-to-paste `[class="..." instance="..."]` match snippet, into a `terminator` window.
3. Starts that terminator with `--role=window-inspector`, which the rule above matches on, so it floats without matching an ordinary terminator window.
4. Never moves, closes, resizes, or otherwise changes the window it inspects.

Validate without opening a window: `bash -n configs/session/i3/window-inspector.sh`, `shellcheck configs/session/i3/window-inspector.sh`, and `i3 -C -c configs/session/i3/config`.

### Clockify form window

The Clockify Polybar indicator opens `tools/clockify`'s local form through Chrome app mode, using the dedicated user profile at `~/.config/dnb-clockify/chrome-profile` and the stable window class `dnb-clockify-form`. The rule floats that class, resizes it to `700x760`, and centres it on the current workspace. No workspace assignment is used, so the form stays on the workspace where it was opened.

### Scratchpad mark convention

Every `for_window` rule that sends a window straight to i3's scratchpad (`move scratchpad`) **must** mark it with a `scratch-` prefixed name (for example `scratch-terminal`). `configs/session/i3/workspaces/workspaces.py`'s `is_switchable_window()` hides any window with a `scratch-` prefixed mark from the Rofi Alt+Tab window switcher, so scratchpad windows never clutter that list even while shown on a normal workspace. `scratchpad_state` cannot be used for this, because i3 resets it to `none` once a scratchpad window is shown. A scratchpad rule without this prefix leaks into the Alt+Tab list.

### Scratch terminal

A singleton, Guake-style dropdown terminal built from native i3 scratchpad behaviour. Full architecture, geometry rationale, and command reference: [`configs/session/terminal/README.md`](configs/session/terminal/README.md).

* **Match criterion**: `window_role="scratch-terminal"`, set by `terminator --role=scratch-terminal` when `configs/session/terminal/scratch-terminal` starts it. Ordinary Terminator windows from `$mod+Return` have no role and never match.
* **Mark**: `scratch-terminal`. Every controller operation (show, hide, resize, focus, kill on `--restart`) targets this mark, never class or title.
* **Keybinding**: `Ctrl+Shift+Alt+T`, bound to `scratch-terminal --toggle`. The controller creates the window on first use and recomputes the right-half-of-output geometry on every show.
* **Appearance**: started with `--profile scratch`, a Terminator profile in `configs/session/terminator/config` (`[profiles] [[scratch]]`). It has an opaque background with the same colours and font as `[[default]]`; the session runs no compositor, so transparency would have no effect.
* **Geometry**: recalculated on every show from the focused workspace's `rect` (`i3-msg -t get_workspaces`), which already excludes Polybar's reserved strut. No dimensions are hardcoded.
* **Lifecycle**: created on the first `--toggle`/`--show`, not at session start. The same Terminator process (shell state, scrollback, running commands, SSH sessions) persists until `i3-msg restart`, logout, or an explicit `--restart`.
* It does not follow workspace changes; press `Ctrl+Shift+Alt+T` again to bring it to the focused workspace.

Validate: `bash -n configs/session/terminal/scratch-terminal`, `shellcheck configs/session/terminal/scratch-terminal`, and `i3 -C -c configs/session/i3/config`.

<!-- markdownlint-disable-next-line title-case-style -->
<!-- markdownlint-disable-next-line dnb-title-case-style -->
## Canonical Files workspace

A singleton, two-pane Thunar workspace (LEFT user-controlled, RIGHT always the target of external directory-open requests — `explore`, `xdg-open`, `gio open`, "open in file manager" from any XDG-aware application). `Ctrl+Shift+Alt+F` shows it and creates it on first use. It is reserved at i3 workspace number 90 and identified only by the i3 container marks `file-manager-left` and `file-manager-right`, read from the live i3 tree with no cache or state file. `configs/session/filemanager/file-manager` is the only place that creates, repairs, or retargets it; the i3 config only binds the key. A user-level desktop entry (`configs/session/launchers/dnb-file-manager.desktop`) and `xdg-mime default` (set by `configs/dotbot/config.yaml`'s `shell:` section) route `inode/directory` to the controller. Full architecture, invariants, and recovery: [`configs/session/filemanager/README.md`](configs/session/filemanager/README.md).

## Rofi

* `configs/session/rofi/` — Dotbot-linked to `~/.config/rofi`. Holds the base `config.rasi`, `theme.rasi`, `config.alt-tab-switcher.rasi`, the power menu (`power/powermenu.sh`, `$mod+Shift+e`), and these scripts:
  * `window-switcher.sh` — Alt+Tab window switcher, bound to `Mod1+Tab` in `configs/session/i3/configs/applications.conf` (i3 has no native Alt+Tab). It shows windows across all workspaces. It calls `configs/session/i3/workspaces/workspaces.py` to read the i3 tree, map workspace names through `configs/session/i3/workspaces/workspaces.yaml`, and show workspace icons instead of raw names such as `2:` or `10:`. Panel and dock windows (such as Polybar) and windows with a `scratch-` prefixed mark are hidden (see "Scratchpad mark convention"). VS Code windows with the `Code` or `com.microsoft.VSCode` class show the project name from their title in the first column, with `Code` as the fallback.
  * `workspaces.sh` — VS Code workspace picker, bound to `Ctrl+Shift+W`. With `--dynamic-workspace code`, it creates a temporary i3 workspace, switches to it, and starts the selected Code target there. If the target path, one of the folders in a `.code-workspace` file, or one of their parent directories has a `.github/config.toml` with `[workspace] icon = "..."`, that icon becomes the workspace indicator; otherwise the configured Code icon is used. i3 removes the workspace when its last window closes.
* `configs/session/i3/workspaces/workspaces.py promote-focused` — bound to `Ctrl+Shift+Alt+N`. It reads the focused window from `i3-msg -t get_tree`, rejects scratchpad and session-infrastructure windows with the same filter as Alt+Tab, selects an icon from `workspaces.yaml`'s `window_icons.rules` (falling back to `window_icons.fallback`), moves that container to a fresh dynamic workspace, and switches to it. The optional `slug` values are maintainer metadata; the visible workspace name stays `number:icon`.
* `configs/session/i3/workspaces/layouts.py` — workspace layouts, bound to `Ctrl+Super+S`/`L`/`D`/`E` (save, load, delete, edit) in `keybindings.conf`. `save` converts the focused workspace into `append_layout` placeholders (class/instance `swallows`) and records each window's command from `_NET_WM_PID` and `/proc/<pid>/cmdline`. `apply` creates the next dynamic workspace (10+), runs `append_layout` there, and starts the recorded commands. Files are in `configs/session/i3/layouts/`, tracked in git. Rofi `-dmenu` with `configs/session/i3/rofi.rasi` provides the prompts; `subl` opens the files; results and errors go to `notify-send`. See "Workspace layouts" in `configs/session/i3/README.md`.
* `workspaces.py launch --application <name>` is also called directly, with no Rofi picker, by single-purpose launchers such as `configs/session/launchers/chatgpt.desktop`. See [`.agents/instructions/session/dynamic-workspace-launcher.instructions.md`](.agents/instructions/session/dynamic-workspace-launcher.instructions.md) for how to add another one.
* The application launcher (drun) uses `configs/session/i3/rofi.rasi`, a small override that sets `matching: "fuzzy"`, `case-sensitive: false`, `show-icons: true`, and an explicit `width`/`location`. It reuses the base visuals through `@theme "theme"`, which resolves to `configs/session/rofi/theme.rasi`, so there is only one theme.
* Invoked as `rofi -show drun -config <repo>/configs/session/i3/rofi.rasi` plus a per-binding prompt set with `-display-drun`:
  * Bare `Super` and `Super+Shift+D` (`$rofi_new_workspace`), prompt "start program in new workspace": `-run-command` and `-run-shell-command` pass the selected command to `workspaces.py launch-command`. That creates the next dynamic workspace (10+), switches to it, and starts the program there. The icon is the icon of a `dynamic:` entry that runs the same executable, else `window_icons.fallback`, which `workspaces.py set-workspace-icon` replaces with the matching `window_icons.rules` icon once the first window appears (it polls for up to 15 seconds). Programs start without startup notification, so a slow program opens on whichever workspace is focused when its window appears. A single-instance program that only raises an existing window leaves the new workspace empty, and i3 removes it when you leave it.
  * `Super+D` (`$rofi_current_workspace`), prompt "start program in current workspace": starts the program on the current workspace.
  * i3 does not expand a `$variable` inside another `set` value, so both variables contain the full rofi command.
* Validate without opening a window: `rofi -config configs/session/i3/rofi.rasi -dump-config` and `-dump-theme`.

## Polybar

* `configs/session/polybar/config.ini` defines a single bar, `bar/i3bar`:
  * left: `powermenu`, `system-checkup`, `clockify` (with the hidden `clockify-refresh` helper), `msgvault`, `i3` (icon-rendered workspaces)
  * centre: `title` (focused window title)
  * right: `tray`, `pulseaudio`, `date`
* Started by `configs/session/polybar/launch.sh`, which logs to `~/.logs/polybar-i3/bar-YYYYMMDD.log`. See [`configs/session/polybar/README.md`](configs/session/polybar/README.md) for the file-by-file breakdown.
* `launch.sh` runs `pkill -u "$UID" -x polybar` before it starts the bar, so `i3-msg restart` never leaves duplicate bars. This kills every Polybar process of the user on every display; do not run a second Polybar instance (for example in Xephyr) at the same time.
* Safe non-rendering checks: `polybar -c configs/session/polybar/config.ini --list-monitors`, `polybar -c configs/session/polybar/config.ini -d modules-left i3bar`, and `polybar -c configs/session/polybar/config.ini -d modules-right i3bar`. The `-d` commands only dump configured values and exit. Use `configs/session/polybar/launch.sh` inside the i3 session to start or restart the real bar.

## Background

* `xsetroot -solid '#0B0D0F'` runs on every i3 start and restart, so the desktop is never blank even without a wallpaper file. The colour matches Polybar's Dracula Pro `dnb-background`.
* `feh --bg-fill configs/session/i3/wallpaper.jpg` then sets the repo-committed wallpaper image.

## Notifications

* dunst (`apt: dunst`) is the notification daemon. i3 does not start it: the first `notify-send` call makes D-Bus activate the systemd user unit `dunst.service` (`/usr/lib/systemd/user/dunst.service`, `Type=dbus`, `BusName=org.freedesktop.Notifications`), which then keeps running.
* The installed `xfce4-notifyd` package also provides a D-Bus service file for the same name (`/usr/share/dbus-1/services/org.xfce.xfce4-notifyd.Notifications.service`). The dotfiles do not pin which of the two D-Bus activates. On this host dunst is the owner; check with `busctl --user status org.freedesktop.Notifications` (look at `Comm=`).
* dunst reads `configs/session/dunst/dunstrc` (Dotbot-linked to `~/.config/dunst`; Dracula colours). Mouse bindings are the dunst defaults: left-click closes a notification, middle-click runs its action and closes it, right-click closes all notifications. Apply changes with `dunstctl reload`; dunst logs config warnings to `journalctl --user -u dunst`.
* `configs/session/storage/gdrive-mounts.sh` depends on the middle-click action: its "Re-authorise" notification starts the Google Drive sign-in (see `configs/session/storage/README.md`).

## Screen lock

* `xss-lock` runs as the systemd user unit `configs/session/systemd/xss-lock.service` (`Restart=on-failure`). `session-starts.conf` starts it with `exec_always`, so every i3 restart starts it again if it died; `systemctl --user start` is a no-op when it is already running.
* The unit is `WantedBy=graphical-session.target`, not `default.target`. With `Linger=yes` the user manager starts at boot, before any X login, so a `default.target` unit cannot connect to a display, fails five times in ten seconds, and systemd then refuses further starts until `reset-failed`. Nothing activates `graphical-session.target` under i3, so only `session-starts.conf` starts the unit. That line imports `DISPLAY`, `XAUTHORITY`, and `XDG_SESSION_ID` and runs `systemctl --user reset-failed xss-lock.service` before the start.
* Because of `Linger=yes` (`loginctl show-user patrick`), `systemd --user` is a persistent manager outside the graphical seat0 session. `xss-lock`'s default cgroup-based session lookup therefore fails for this unit (`NoSessionForPID`), which would break `--transfer-sleep-lock`. The unit passes `xss-lock -s "${XDG_SESSION_ID}"` explicitly (matching upstream's example at `/usr/share/doc/xss-lock/xss-lock.service`); `XDG_SESSION_ID` is imported in the same shell immediately before the start. Check with `loginctl session-status <id>`: it shows the `xss-lock` sleep inhibitor (`delay`, "Lock screen first").
* `lock.sh` resolves its own directory and runs `i3lock --nofork -i configs/session/i3/lockscreen.png` with a full path, so it works regardless of i3's `exec` environment. If the installed `i3lock` supports the i3lock-color options, `lock.sh` also applies the Dracula-style colours, clock, indicator, and media-key pass-through flags; plain i3lock gets the image-only command. `--nofork` is required: xss-lock tracks lock and unlock by waiting for the locker process to exit (see `man i3lock`, "RECOMMENDED USAGE").
* `lock.sh` does **not** `exec` into `i3lock`: it runs it as a child process and, after the user unlocks, runs `configs/session/polybar/launch.sh` before it exits with `i3lock`'s exit status. This restores the bar when Polybar fails to reappear after an unlock; when the bar was fine, the restart has no visible effect. xss-lock only needs the locker process to exit eventually, so this does not change its behaviour.
* `xss-lock` reacts to two triggers: `loginctl lock-session` (bound to `Super+L`) and systemd-logind's sleep signal, which `--transfer-sleep-lock` uses to hold suspend (lid close, power button, `systemctl suspend`) until the screen is locked.
* The Rofi power menu's `lock` entry (`configs/session/rofi/power/powermenu.sh`) does not go through `xss-lock`/`loginctl`: it uses `betterlockscreen` if installed, then `configs/session/i3/lock.sh`, then a plain `i3lock` with no image.
* Validate without opening a window: `bash -n configs/session/i3/lock.sh`, `shellcheck configs/session/i3/lock.sh`, and `i3 -C -c configs/session/i3/config`.

## Environment variables relevant to the session

* `$mod`, `$terminal`, and `$ws1`..`$ws9` are i3-config variables (`set $var value` in `configs/session/i3/config` and its includes), not shell or session environment variables.
* No session environment file (`~/.xprofile`, `~/.xinitrc`) exists; LightDM's standard `/etc/X11/Xsession` handling is used unmodified.

The storage search service in `tools/storage/` starts through its own cron profile, not through i3. Its `openerEnvironment` configuration supplies `DISPLAY`, `XAUTHORITY`, and `DBUS_SESSION_BUS_ADDRESS` only to the `xdg-open` child used by its Open folder and Open file actions, so a service started before login can open results in the desktop after login. It does not change the i3 environment. See [tools/storage/README.md](tools/storage/README.md).

## Components that need i3

These components depend on i3 and do nothing useful in another session:

* `configs/session/i3/` — the i3 config and everything it starts.
* `configs/session/rofi/` and `configs/session/i3/rofi.rasi`.
* `configs/session/polybar/` and its `launch.sh`.
* `configs/session/i3/lock.sh` and the `xss-lock` unit.
* `configs/session/terminal/scratch-terminal` — uses i3 IPC directly and fails fast if i3 is not running.
* `configs/session/filemanager/file-manager` — when i3 is not the running window manager, it falls back to a plain, unmanaged Thunar window, so `explore` and XDG directory opens still work. See that subsystem's README.

## Dependencies

Required:

```text
i3        (4.25.1)            apt: i3-wm
polybar   (3.7.2, +i3 feature) apt: polybar
rofi      (2.0.0)             apt: rofi
i3lock                        apt: i3lock
xss-lock  (0.4.0)             apt: xss-lock
```

Helpers used by the session:

```text
xsetroot    apt: x11-xserver-utils
feh         apt: feh             (wallpaper on every start/restart)
pactl       apt: pulseaudio-utils (Polybar pulseaudio module)
terminator  apt: terminator      ($terminal; window-inspector and scratch terminal)
xdotool     apt: xdotool         (window-inspector click-to-select and window queries)
xprop       apt: x11-utils       (window-inspector WM_CLASS/role; layouts.py _NET_WM_PID lookup)
wmctrl      apt: wmctrl          (window-inspector desktop/PID listing)
dunst       apt: dunst           (notification daemon, D-Bus-activated)
notify-send apt: libnotify-bin   (layouts.py results and errors)
subl        Sublime Text         (layouts.py save/edit opens layout files)
shellcheck  dev-only             (lints the session scripts)
```

## Log locations

```text
~/.logs/polybar-i3/   Polybar (configs/session/polybar/launch.sh)
~/.xsession-errors    General X session stderr
```

i3 itself does not write a dedicated log file by default; config errors show as `i3-nagbar` popups and in `~/.xsession-errors`.

## Diagnostic commands

```bash
i3 -C -c configs/session/i3/config      # validate the i3 config (safe, no live session needed)
i3-msg reload                           # reload config in a running i3
i3-msg restart                          # restart i3 in place (same as Super+Shift+R)
pgrep -a polybar                        # see which bar is running and with which config
polybar --version                       # confirm feature flags (+i3 is required)
rofi -version
rofi -config configs/session/i3/rofi.rasi -dump-config   # validate the Rofi override, no window opens
tail -f ~/.logs/polybar-i3/bar-$(date +%Y%m%d).log           # Polybar log
tail -100 ~/.xsession-errors                                  # general X session errors
tools/system-checkup/system-checkup --verbose                 # read-only: all checks, incl. the 3x-session-* checks
busctl --user status org.freedesktop.Notifications | grep -E '^(PID|Comm)='  # which notification daemon is active
```

The `30-session-commands`, `31-session-config`, `32-session-links`, and `33-session-running` checks of the system checkup (`tools/system-checkup/README.md`) bundle the command, config, link, and process checks above. They are read-only and never modify the desktop. Cron and the i3 login run them; Polybar shows an alert icon when one fails. `npm run test:shell` runs `31-session-config` against the working tree.

## Known limitations

Do not implement these without a separate, explicit request:

* No compositor — windows have no shadows and no RGBA transparency.
* No monitor-specific (`xrandr`) configuration. The host has a single monitor (`DP-1`, 1920x1080); multi-monitor behaviour is untested.
* Static application placement is limited to the rules in "Window rules". Use i3's own `for_window`/`assign` for new placement rules, not shell-managed placement; `window-inspector.sh` finds the match criteria.
* No keybinding that triggers suspend itself. Only screen lock is bound (`Super+L`); the screen locks automatically before any suspend (see "Screen lock").
* No media or volume key bindings (no `pactl set-sink-volume` bindings, no `playerctl`).
* No host-specific i3 config split.

## Recovery procedure

If the i3 session fails to start or misbehaves:

1. Log out (`Super+Shift+E` opens the power menu), or use LightDM's session switch if i3 is unresponsive.
2. At the LightDM greeter, select **Xubuntu** or **XFCE**. These sessions use XFCE's own unmanaged defaults and do not depend on any file in this repository.
3. Inspect and repair `configs/session/i3/` and `configs/session/polybar/`.
4. Validate before logging back into i3:

```bash
i3 -C -c configs/session/i3/config
rofi -config configs/session/i3/rofi.rasi -dump-config
polybar -c configs/session/polybar/config.ini --list-monitors
tools/system-checkup/system-checkup --check 31-session-config
```

## Session colour scheme

The i3 startup include runs `bashrc/helpers/session-colour-scheme --apply` with `exec_always` to maintain the `prefer-dark` preference. Failures are visible on stderr and non-fatal to i3. Session identity stays unchanged. Per-tool literal environment configs live in `configs/session/colour-scheme/tools/`; Enpass alone receives `XDG_CURRENT_DESKTOP=GNOME`. Its startup (`--minimize`), assistant binding (`Ctrl+Shift+Alt+E`, `showassistant`), and user desktop entry all use this helper. The Enpass window rule is independent of colour-scheme handling. See [the design and extension guide](configs/session/colour-scheme/README.md).

## Mailbox monitor manual login

`bashrc/helpers/mailbox-monitor/run-mailbox-monitor.sh --login` opens Chromium from an interactive desktop terminal for Pair login and 2FA. The monitor forwards `DISPLAY` and `XAUTHORITY` to Chromium within its restricted child environment. Scheduled mailbox checks remain headless and reuse the saved session; they do not require an i3 login.

## Agent maintenance requirement

Any change to i3, Polybar, Rofi, X11/Xorg, LightDM/session selection, startup scripts, environment setup, wallpaper/background, notifications, compositor, monitors, input sharing, workspace behaviour, window assignment, screen locking, suspend/logout controls, or related session services must update this file in the same change. Agents starting work on the desktop session should read `AGENTS.md` and this file, plus any applicable `.agents/instructions/`, folder `README.md`, and `INDEX.md` files, before making changes.

## Dedicated web apps

Dotbot links `bashrc/helpers/chrome-app` to `~/.local/bin/chrome-app` and the app definitions to `~/.config/chrome-apps/apps/`. The WhatsApp desktop launcher uses `chrome-app --app whatsapp`, with class `dnb-whatsapp` and its canonical profile at `~/.local/share/chrome-apps/whatsapp/` in the standard XDG environment. It starts once per i3 login, can also be opened on demand, and has no i3 workspace assignment. See [Chrome apps](configs/session/chrome-apps/README.md) for installation and inspection.

The WhatsApp launcher icon is supplied by the DNB theme and linked into the local hicolor fallback theme by Dotbot. `window_icons.rules` in `configs/session/i3/workspaces/workspaces.yaml` maps `dnb-whatsapp` to the Lucide messages-square glyph (`U+E40D`) for dynamic workspaces.

WhatsApp enables `APP_SINGLE_INSTANCE="true"` in its Chrome app definition. Repeated launches activate the first existing `dnb-whatsapp` window through `wmctrl -ia`, switching to its workspace. The Rofi workspace launcher may briefly create an empty workspace, which i3 removes when focus returns to WhatsApp. Existing duplicate windows are not closed automatically.
