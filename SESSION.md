<!-- markdownlint-disable-next-line title-case-style -->
# SESSION.md

Authoritative technical reference for how the graphical desktop session on
this workstation is assembled and started. This is operational
documentation for agents and future maintainers, not a user-facing guide —
see `README.md` for that.

Read this file (and `AGENTS.md`) before changing anything that affects i3,
Polybar, Rofi, X11/Xorg, LightDM/session selection, startup scripts,
environment setup, wallpaper/background, notifications, compositor,
monitors, input sharing, workspace behaviour, window assignment, screen
locking, suspend/logout controls, or related session services. **Any such
change must update this file in the same change.**

## Display manager and available sessions

* Display manager: **LightDM** (`/etc/lightdm/`), Debian/Ubuntu defaults
  (`session-wrapper=/etc/X11/Xsession`, GTK greeter).
* Available X sessions (`/usr/share/xsessions/`), confirmed present on this
  host: `xfce.desktop`, `xubuntu.desktop`, `i3.desktop`,
  `i3-with-shmlog.desktop`, `lightdm-xsession.desktop`. Neither
  `i3.desktop` nor the XFCE session files were created or modified by this
  work — i3 was already an installed, selectable LightDM session; only its
  configuration was missing.
* Current default/last-selected session (`~/.dmrc`): **`xfce`**. This was
  not changed. XFCE remains the session a fresh login lands on unless the
  user explicitly picks "i3" at the LightDM greeter.
* `i3.desktop`'s `Exec=i3` starts i3 with no special environment; i3 looks
  for its config at `~/.config/i3/config` by convention, which is why the
  Dotbot link below exists.

## Repository paths to runtime paths

```text
Repository                                Runtime
----------                                -------
configs/session/i3/config              -> ~/.config/i3/config   (Dotbot link)
configs/session/polybar/               -> (not symlinked; referenced by
                                            repo path directly from i3's
                                            exec_always — see "Polybar" below)
configs/system/polybar/                -> ~/.config/polybar     (Dotbot link, XFCE bar, unchanged)
configs/system/rofi/                   -> ~/.config/rofi        (Dotbot link, shared by XFCE and i3)
configs/system/xfce/*.xml              -> ~/.config/xfce4/xfconf/xfce-perchannel-xml/*.xml (Dotbot link, XFCE-only)
configs/system/autostart/locutus/      -> ~/.config/autostart   (Dotbot link, host-specific XDG autostart pool)
configs/system/devilspie2/config       -> ~/.config/devilspie2  (Dotbot link, XFCE-only, see "Known limitations")
```

Dotbot config: `configs/dotbot/config.yaml`, run via the `dotfiles` wrapper
(`bashrc/helpers/dotfiles`; see `configs/dotbot/README.md`).

## Session architecture

```text
LightDM
│
├── Xubuntu / XFCE  (default session, ~/.dmrc)
│   ├── xfwm4 (window manager)
│   ├── xfce4-panel
│   ├── Polybar (configs/system/polybar/, autostarted via
│   │   configs/system/autostart/locutus/polybar.desktop, OnlyShowIn=XFCE)
│   ├── Devilspie2 (configs/system/devilspie2/, autostarted via
│   │   .../devilspie2.desktop, OnlyShowIn=XFCE)
│   └── Rofi (configs/system/rofi/, launched ad hoc via XFCE keyboard
│       shortcuts — bare Super, Ctrl+Shift+W, Alt+Tab/Super+Tab window
│       switcher)
│
└── i3  (this work; selectable at the LightDM greeter, not the default)
    │
    └── Xorg (same X server mechanism as XFCE; no separate X11 setup needed)
        │
        ├── i3 (configs/session/i3/config)
        │   ├── keybindings (see "Keybinding architecture")
        │   ├── workspaces 1-9 (plain numbers, no icons/rules yet)
        │   └── window rules (none yet — see "Known limitations")
        │
        ├── Rofi (SHARED with XFCE — configs/system/rofi/, unchanged,
        │   invoked as `rofi -show drun`)
        ├── Polybar (i3-ONLY copy — configs/session/polybar/, launched by
        │   configs/session/polybar/launch.sh via i3 exec_always)
        ├── background (xsetroot solid colour, then best-effort
        │   bashrc/helpers/theme/set-default-wallpaper.sh)
        └── (no compositor, no notification daemon, no monitor rules —
            intentionally out of scope, see "Known limitations")
```

## Startup sequence (i3 session)

1. LightDM starts `i3` (`Exec=i3` from `/usr/share/xsessions/i3.desktop`)
   after the user selects it at the greeter.
2. Xorg initialises the graphical session (shared mechanism with XFCE, no
   i3-specific Xorg configuration exists or is needed).
3. i3 reads `~/.config/i3/config`, which Dotbot has symlinked to
   `configs/session/i3/config`.
4. i3 runs its `exec_always` lines in the order they appear in the config:
   1. `xsetroot -solid '#0B0D0F'` — sets a guaranteed root-window
      background colour. **Non-fatal**: `xsetroot` is a tiny, essentially
      infallible tool; if it were somehow missing, i3 continues normally
      (exec_always failures are not fatal to i3 itself).
   2. `bashrc/helpers/theme/set-default-wallpaper.sh` (wrapped in
      `sh -c '... || true'`) — best-effort: looks for
      `config/theme/wallpaper.{jpg,png}` in the repo (currently absent on
      this host) and, if found, overrides the solid colour via `feh`
      (auto-detected backend for a non-XFCE/GNOME/KDE/Sway/Hyprland
      session). **Non-fatal** by construction.
   3. `configs/session/polybar/launch.sh` (wrapped in
      `sh -c '... || true'`) — kills any existing user Polybar instance,
      waits up to ~5s, starts `bar/i3bar` from
      `configs/session/polybar/config.ini`, logs to
      `~/.logs/polybar-i3/bar-YYYYMMDD.log`. **Non-fatal**: the script
      itself never exits in a way i3 acts on, and internally logs+returns
      rather than throwing if `polybar` or the config file is missing.
5. XDG autostart (`~/.config/autostart`, i.e.
   `configs/system/autostart/locutus/`) also runs under i3, same as any
   session. Entries explicitly scoped `OnlyShowIn=XFCE;`
   (`polybar.desktop`, `devilspie2.desktop`, `Obsidian.desktop`) do **not**
   fire under i3. See "Known limitations" for entries that are *not*
   scoped and therefore *do* also run under i3.
6. Nothing else is started automatically. No compositor, no notification
   daemon, no monitor/xrandr commands, no wallpaper-manager daemon.

For every automatically started i3-session component:

| Component | Started by | Command | `exec` vs `exec_always` | Failure mode |
| --- | --- | --- | --- | --- |
| Root background colour | i3 | `xsetroot -solid '#0B0D0F'` | `exec_always` | Non-fatal; i3 unaffected. |
| Wallpaper (optional) | i3 | `bashrc/helpers/theme/set-default-wallpaper.sh` | `exec_always` (`sh -c ... \|\| true`) | Non-fatal; no-ops if no wallpaper file exists. |
| Polybar | i3 | `configs/session/polybar/launch.sh` | `exec_always` (`sh -c ... \|\| true`) | Non-fatal; i3 remains usable with no bar if Polybar/its config is missing. |
| Rofi | user keypress (`Super_L` release, or `$mod+d`) | `rofi -show drun` | `bindsym ... exec` | Non-fatal; a launcher failure does not affect the rest of the session. |
| Terminal | user keypress (`$mod+Return`) | `xfce4-terminal` | `bindsym ... exec` | Non-fatal. |

`exec_always` (not `exec`) is used for background/Polybar/wallpaper so that
`i3-msg restart` (`$mod+Shift+r`) re-runs them — this is what keeps the
Polybar launcher's own kill-old-instance-first logic doing its job on every
restart rather than leaving `Super+Shift+r` with no bar at all.

## Keybinding architecture

Defined entirely in `configs/session/i3/config`. `$mod` is `Mod4`
(Super/Windows key). Full table:

| Binding | Action |
| --- | --- |
| `Super` (bare, release) | Open Rofi (`drun`) — see "Bare Super key limitation" below |
| `Super+D` | Open Rofi (`drun`) — explicit, always-reliable fallback for the above |
| `Super+Enter` | Open terminal (`$terminal`, currently `xfce4-terminal`) |
| `Super+Shift+Q` | Close focused window |
| `Super+Shift+C` | Reload i3 config |
| `Super+Shift+R` | Restart i3 in place |
| `Super+Shift+E` | Exit i3, with an `i3-nagbar` confirmation prompt |
| `Super+1`..`Super+9` | Switch to workspace 1-9 |
| `Super+Shift+1`..`Super+Shift+9` | Move focused window to workspace 1-9 |
| `Super+Arrow` | Move focus |
| `Super+Shift+Arrow` | Move focused window |
| `Super+F` | Toggle fullscreen |
| `Super+Space` | Toggle floating |
| `Super+R` | Enter resize mode (`Arrow` keys resize, `Enter`/`Escape` to leave) |

### Bare `Super` key limitation

i3's `bindsym` grammar binds a modifier combined with a keysym, not a bare
modifier alone. This is implemented as:

```text
bindsym --release Super_L exec --no-startup-id rofi -show drun
```

`--release` scopes it to "`Super_L` pressed and released with nothing else
pressed in between," so it does not fight with `$mod+<key>` bindings. If
this is ever unreliable on a given keyboard/X11 combination, `Super+D` is
the documented fallback bound to the exact same command.

## Rofi

* Config: `configs/system/rofi/` — **shared, unchanged**. Already used by
  the live XFCE session (bare `Super_L` in
  `configs/system/xfce/xfce4-keyboard-shortcuts.xml`, plus the window
  switcher and workspace scripts in that same folder).
  `drun` mode, icons, and history are already enabled there; i3 gains
  nothing from forking a second config.
* i3 calls it as `rofi -show drun`, identical to what XFCE already runs.
* Validated non-interactively (parses without opening a window):
  `rofi -config configs/system/rofi/config.rasi -dump-config`.

## Polybar

* Two independent Polybar setups exist side by side in the repository:
  * `configs/system/polybar/` — the XFCE bar. Live, currently running
    under the XFCE session on this host. **Not touched by this work.**
  * `configs/session/polybar/` — new, i3-only. A single bar (`bar/i3bar`):
    left = i3 workspaces (`internal/i3`), centre = focused window title
    (`internal/xwindow`), right = CPU, memory, root filesystem, network
    (interface `eno1` — host-specific), volume (`internal/pulseaudio`),
    date, tray (`internal/tray`).
* Launched by `configs/session/polybar/launch.sh` (see that folder's
  README for the file-by-file breakdown and what was deliberately *not*
  carried over from the XFCE bar).
* **Both bars share the OS process name `polybar`.** `launch.sh` uses
  `pkill -u "$UID" -x polybar` to avoid leaving duplicate bars behind on
  `i3-msg restart`. This is safe **only** because i3 and XFCE are
  alternate, mutually exclusive LightDM sessions on one X display — they
  are never running at the same time. If that assumption ever changes
  (e.g. nested X servers, Xephyr testing, a second concurrent seat), this
  script would kill the other session's bar too — treat that as a hard
  constraint on how this script may be reused.
* Validated non-interactively (parses without opening a window):
  `polybar -c configs/session/polybar/config.ini --list-monitors` and
  `polybar -c configs/session/polybar/config.ini -d modules-right i3bar`.

## Background

* `xsetroot -solid '#0B0D0F'` runs unconditionally on every i3 start/restart
  — guarantees the desktop is visibly "on," independent of any wallpaper
  file existing. Colour matches Polybar's Dracula Pro `dnb-background`.
* `bashrc/helpers/theme/set-default-wallpaper.sh` then runs best-effort; it
  looks for `config/theme/wallpaper.{jpg,png}` in the repo. **Neither file
  exists on this host right now** — this is a known, documented gap, not a
  bug. Add either file to enable a real wallpaper under i3 (and XFCE/GNOME/
  KDE/Sway/Hyprland, via the same script's auto-detection).
* No compositor is configured (Picom or otherwise) — out of scope per the
  starter spec; see "Known limitations."

## Environment variables relevant to the session

* `$mod` / `$terminal` / `$ws1`..`$ws9` — i3-config-local variables, not
  shell/session environment variables (set via `set $var value` inside
  `configs/session/i3/config`).
* `XDG_CURRENT_DESKTOP` / `DESKTOP_SESSION` are set to `i3` by
  `/usr/share/xsessions/i3.desktop`'s `DesktopNames=i3`. This is what makes
  XDG-autostart `OnlyShowIn=XFCE;` entries correctly skip the i3 session,
  and what makes `bashrc/helpers/theme/set-wallpaper.sh --mode auto`
  correctly fall through to its `feh` backend under i3.
* No i3-specific environment file (`~/.xprofile`, `~/.xinitrc`) exists or
  was added; LightDM's standard `/etc/X11/Xsession` handling is used
  unmodified for both sessions.

## Shared components (used by both XFCE and i3)

* Rofi (`configs/system/rofi/`) — see "Rofi" above.
* The `feh`/`xsetroot` wallpaper tooling
  (`bashrc/helpers/theme/set-wallpaper.sh`) — generic, environment-aware,
  not modified.
* Xorg itself, fonts, icon themes, `~/.gitconfig` and other non-desktop
  Dotbot links — unaffected by this work.

## Components that must only run under i3

* `configs/session/polybar/` and its `launch.sh`.
* The i3 config itself (`configs/session/i3/config`) and everything it
  `exec`/`exec_always`s.

## Components that must only run under XFCE (unchanged by this work)

* `configs/system/polybar/` (XFCE bar) and `configs/system/polybar/start.sh`
  — waits for `xfwm4`, so it would hang harmlessly if it were ever started
  outside XFCE; it never is, because its autostart entry is
  `OnlyShowIn=XFCE;`.
* `configs/system/devilspie2/` — `OnlyShowIn=XFCE;`, unaffected.
* `configs/system/xfce/*.xml` (xfwm4 window-manager and keyboard-shortcut
  settings) — untouched.

## Dependencies

Required, all confirmed already installed on this host:

```text
i3       (4.25.1)     apt: i3-wm
polybar  (3.7.2, +i3 feature) apt: polybar
rofi     (2.0.0)      apt: rofi
```

Helpers used by the startup chain, all confirmed present:

```text
xsetroot   apt: x11-xserver-utils
feh        apt: feh   (only used if a wallpaper file is ever added)
pactl      apt: pulseaudio-utils  (used by Polybar's pulseaudio module)
shellcheck (dev-only, used to lint launch.sh; via linuxbrew on this host)
```

Explicitly **not** used, despite being mentioned as possibilities in the
starter spec: `nitrogen`, `playerctl` — neither is installed on this host
and neither is required by anything in this configuration.

## Log locations

```text
~/.logs/polybar/           XFCE Polybar (configs/system/polybar/start.sh) — unchanged
~/.logs/polybar-i3/        i3 Polybar (configs/session/polybar/launch.sh) — new
~/.xsession-errors         General X session stderr, both sessions
```

i3 itself does not write a dedicated log file by default; runtime config
errors surface via `i3-nagbar` popups and/or `~/.xsession-errors`.

## Diagnostic commands

```bash
i3 -C -c configs/session/i3/config      # validate the i3 config (safe, no live session needed)
i3-msg reload                           # reload config in a running i3
i3-msg restart                          # restart i3 in place (same as Super+Shift+R)
pgrep -a polybar                        # see which bar(s) are running and with which config
polybar --version                       # confirm feature flags (+i3 is required)
rofi -version
rofi -config configs/system/rofi/config.rasi -dump-config   # validate Rofi config, no window opens
tail -f ~/.logs/polybar-i3/bar-$(date +%Y%m%d).log           # i3 Polybar's own log
cat ~/.xsession-errors | tail -100                            # general X session errors
```

A read-only diagnostic helper covering "is i3/Polybar/Rofi installed and
running" was considered but not built in this pass — see
"Known limitations."

## Known limitations / next improvements

Deliberately not implemented in this starter pass (do not implement without
a separate, explicit request — see the spec's scope-control section):

* **Unscoped host autostart entries also run under i3.**
  `configs/system/autostart/locutus/` has several `.desktop` files with no
  `OnlyShowIn`/`NotShowIn` at all (`Barrier.desktop`, `dnb_enpass.desktop`,
  `dnb_discord.desktop`, `onboard-autostart.desktop`,
  `gnome-keyring-pkcs11.desktop`, `dropbox.desktop`,
  `indicator-messages.desktop`, `startup.sh.desktop`,
  `gnome-keyring-secrets.desktop`, `Flameshot.desktop`,
  `org.gnome.SettingsDaemon.DiskUtilityNotify.desktop`). These will also
  launch under the new i3 session. Some of that may be intentional
  (keyring unlocking, for instance, arguably should be session-wide); some
  of it may be exactly the kind of thing that produces "an apparently
  empty desktop" if one of them errors loudly or grabs focus before i3's
  own startup finishes. Recommend auditing this list deliberately in a
  follow-up rather than as a side effect of this change.
* No compositor (e.g. Picom) — windows will not have shadows/transparency;
  add only if a specific problem needs it.
* No notification daemon — `notify-send` calls will silently do nothing
  under i3 right now.
* No monitor-specific (`xrandr`) configuration — this host currently has a
  single monitor (`DP-1`, 1920x1080, confirmed via
  `polybar --list-monitors`); multi-monitor behaviour is untested.
* No application-to-workspace assignment rules.
* Devilspie2 → i3 native window rules: Devilspie2
  (`configs/system/devilspie2/`) still only runs under XFCE
  (`OnlyShowIn=XFCE;`); i3 has no equivalent window-placement rules yet.
  i3's own `for_window`/`assign` directives could eventually replace the
  Lua rules in `configs/system/devilspie2/config/` for the i3 session, but
  that is a deliberate follow-up, not part of this starter.
* No screen lock / suspend keybindings.
* No media/volume key bindings beyond the Polybar volume module display
  (no `pactl set-sink-volume` bindings, no `playerctl` — not installed).
* No custom Polybar modules beyond the ones listed above (no
  `msgvault`/`issues`/`github`/tray-app modules like the XFCE bar has).
* No host-specific i3 config split (this file and the i3 config are
  currently locutus-specific in exactly one place: the Polybar network
  module's `interface = eno1`).
* No read-only "is everything installed and running" diagnostic script —
  the diagnostic commands above are documented but not wrapped in a single
  helper.

## Recovery procedure (XFCE fallback)

The XFCE/Xubuntu session is untouched and remains the LightDM default
(`~/.dmrc: Session=xfce`). If the i3 session fails to start or misbehaves:

1. Log out of i3 (`Super+Shift+E`, confirm in the `i3-nagbar` prompt), or
   use LightDM's session-switch mechanism if i3 is unresponsive.
2. At the LightDM greeter, select **Xubuntu** or **XFCE**.
3. Log in normally — this session and its Polybar/Devilspie2/Rofi setup are
   completely independent of the i3 files above and were not modified by
   this work.
4. Inspect/repair `configs/session/i3/config` and
   `configs/session/polybar/` from within the working XFCE session.
5. Validate before logging back into i3:

```bash
i3 -C -c configs/session/i3/config
rofi -config configs/system/rofi/config.rasi -dump-config
polybar -c configs/session/polybar/config.ini --list-monitors
```

## Agent maintenance requirement

Any future change to i3, Polybar, Rofi, X11/Xorg, LightDM/session
selection, startup scripts, environment setup, wallpaper/background,
notifications, compositor, monitors, input sharing, workspace behaviour,
window assignment, screen locking, suspend/logout controls, or related
session services must update this file in the same change. Agents starting
work on the desktop/session configuration should read `AGENTS.md` and this
file, plus any applicable `.vscode/instructions/`, folder `README.md`, and
`INDEX.md` files, before making changes.
