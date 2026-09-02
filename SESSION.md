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
| xss-lock | i3 | `xss-lock --transfer-sleep-lock -- configs/session/i3lock/lock.sh` | `exec` (once per session, see "Screen lock") | Non-fatal to i3; if `xss-lock` is missing, `Super+L`/suspend simply do not lock the screen. |
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
| `Super+W` | Open Rofi VS Code workspace picker (`configs/system/rofi/workspaces.sh --newwindow`) |
| `Super+Enter` | Open terminal (`$terminal`, currently `xfce4-terminal`) |
| `Super+Shift+Q` | Close focused window |
| `Super+Shift+C` | Reload i3 config |
| `Super+Shift+R` | Restart i3 in place |
| `Super+Shift+E` | Exit i3, with an `i3-nagbar` confirmation prompt |
| `Super+L` | Lock the screen (`loginctl lock-session`, caught by `xss-lock`) |
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

* `configs/system/rofi/` — **shared, unchanged**. Already used by the live
  XFCE session (bare `Super_L` in
  `configs/system/xfce/xfce4-keyboard-shortcuts.xml`, plus the window
  switcher and workspace scripts in that same folder).
* i3 does not use that config directly. It calls
  `configs/session/i3/rofi.rasi` — a small, standalone override (per the
  starter spec's own requirement for one) that sets `matching: "fuzzy"`,
  `case-sensitive: false`, `show-icons: true`, and an explicit
  `width`/`location`, none of which the shared config turns on (rofi's
  default matching is substring, not fuzzy — the shared config never
  needed fuzzy matching for XFCE's usage, so it never set it). The
  override reuses the shared config's *visuals* via `@theme "theme"`
  (rofi's own theme search path resolves this to
  `configs/system/rofi/theme.rasi`, confirmed with
  `rofi -config configs/session/i3/rofi.rasi -dump-theme`), so there is no
  second theme to keep in sync — only the functional settings are
  i3-specific.
* Invoked as `rofi -show drun -config <repo>/configs/session/i3/rofi.rasi`
  (the i3 config's `$rofi` variable).
* Validated non-interactively (parses without opening a window):
  `rofi -config configs/session/i3/rofi.rasi -dump-config` and `-dump-theme`.

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

## Screen lock

* `xss-lock` is started once per session (`exec`, not `exec_always` — see
  "Session startup" — in `configs/session/i3/configs/session-starts.conf`)
  as `xss-lock --transfer-sleep-lock -- configs/session/i3lock/lock.sh`.
  `lock.sh` resolves its own directory and runs `i3lock --nofork -i
  configs/session/i3lock/lockscreen.png` with a full path, so it works
  regardless of i3's `exec` environment (same rationale as the
  `Super+Shift+e` powermenu binding). If the installed `i3lock` binary
  supports the i3lock-colour option set, `lock.sh` also applies the
  Dracula-style colours, clock, indicator, and media-key pass-through flags
  adapted from `configs/session/i3lock/lock2.sh`; vanilla i3lock falls back
  to the image-only lock command. `--nofork` is required: xss-lock tracks
  lock/unlock by waiting for the locker process to exit, and i3lock
  daemonises (forks, parent exits immediately) unless told not to — see
  `man i3lock`, "RECOMMENDED USAGE".
* `xss-lock` is the single thing that decides how the screen gets locked.
  It reacts to two triggers: `loginctl lock-session` (what `Super+L` calls
  — see "Keybinding architecture") and systemd-logind's sleep signal, which
  `--transfer-sleep-lock` uses to hold suspend (lid close, power button,
  `systemctl suspend`) until the screen is actually locked, not just until
  a suspend keybinding is pressed (there is none — see "Known
  limitations").
* The Rofi power menu's `lock` entry
  (`configs/session/rofi/power/powermenu.sh`) does not go through
  `xss-lock`/`loginctl`: it prefers `betterlockscreen` if installed, then
  falls back to calling `configs/session/i3lock/lock.sh` directly (same
  lockscreen image as `Super+L`), then to a plain `i3lock` with no image if
  neither is present. This keeps the power menu working under XFCE too,
  where `xss-lock` is never started (see "Components that must only run
  under i3").
* Validated non-interactively (parses, does not open a window):
  `bash -n configs/session/i3lock/lock.sh`, `shellcheck
  configs/session/i3lock/lock.sh`, and `i3 -C -c configs/session/i3/config`.

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
* `configs/session/i3lock/lock.sh` and the `xss-lock` daemon that runs it
  (started via `session-starts.conf`, triggered by `Super+L` and by
  suspend).
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
i3lock                 apt: i3lock (part of the base i3 install on this host)
xss-lock (0.4.0)       apt: xss-lock
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
rofi -config configs/session/i3/rofi.rasi -dump-config   # validate the i3 Rofi override, no window opens
tail -f ~/.logs/polybar-i3/bar-$(date +%Y%m%d).log           # i3 Polybar's own log
cat ~/.xsession-errors | tail -100                            # general X session errors
configs/session/i3/check.sh                                   # read-only: installed/running summary
```

`configs/session/i3/check.sh` bundles the executable/config/process/log
checks above into one read-only report — it never modifies the desktop.

## Known limitations / next improvements

Deliberately not implemented in this starter pass (do not implement without
a separate, explicit request — see the spec's scope-control section):

* **Host autostart entries do NOT run under i3 — i3 has no session
  manager.** `configs/system/autostart/locutus/` (symlinked to
  `~/.config/autostart/`) has several `.desktop` files, some with no
  `OnlyShowIn`/`NotShowIn` at all (`Barrier.desktop`, `dnb_discord.desktop`,
  `onboard-autostart.desktop`, `dropbox.desktop`,
  `indicator-messages.desktop`, `startup.sh.desktop`, `Flameshot.desktop`,
  `org.gnome.SettingsDaemon.DiskUtilityNotify.desktop`). Only
  `xfce4-session` reads that directory; i3 only runs what its own config
  file's `exec`/`exec_always` lines say, so none of these launch under the
  i3 session unless explicitly added there. `gnome-keyring-pkcs11.desktop`/
  `gnome-keyring-secrets.desktop` and Enpass are the ones with an i3
  equivalent so far — see the `gnome-keyring-daemon` and `enpass` lines in
  `configs/session/i3/config` ("Session startup"). The gnome-keyring pair
  was added because VS Code and other libsecret-using apps could not find a
  keyring under i3 otherwise; Enpass's `dnb_enpass.desktop` XFCE autostart
  entry was removed from `configs/system/autostart/locutus/` in favour of
  the i3 `exec` line, since it no longer needs to also fire under XFCE on
  this host. Auditing the rest of this list (does Barrier/Dropbox/Discord
  etc. need an i3 `exec` too?) is a deliberate follow-up, not part of this
  starter.
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
* No keybinding that triggers suspend itself (e.g. `systemctl suspend`) —
  only screen lock is bound (`Super+L`, see "Keybinding architecture"). The
  screen locks automatically before *any* suspend trigger (lid close, power
  button, a manual `systemctl suspend`), via `xss-lock` — see "Screen
  lock".
* No media/volume key bindings beyond the Polybar volume module display
  (no `pactl set-sink-volume` bindings, no `playerctl` — not installed).
* No custom Polybar modules beyond the ones listed above (no
  `msgvault`/`issues`/`github`/tray-app modules like the XFCE bar has).
* No host-specific i3 config split (this file and the i3 config are
  currently locutus-specific in exactly one place: the Polybar network
  module's `interface = eno1`).

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
rofi -config configs/session/i3/rofi.rasi -dump-config
polybar -c configs/session/polybar/config.ini --list-monitors
configs/session/i3/check.sh
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
