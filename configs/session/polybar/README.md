# Polybar (i3 session)

A minimal single-bar Polybar setup for the i3 starter session. It is a
trimmed, i3-specific copy of `configs/system/polybar/` (the bar that runs
under the XFCE session) — kept as a **separate copy**, not a shared config,
so nothing here can ever affect the live XFCE bar.

For the full session architecture, see [`SESSION.md`](../../../SESSION.md)
at the repo root.

## Files

| Path | Purpose |
| --- | --- |
| `config.ini` | The bar definition (`bar/i3bar`): left = configured i3 workspaces, centre = focused window title, right = CPU/memory/root filesystem/network/volume/date/tray. |
| `launch.sh` | Starts the bar. Kills any previous instance for this user first, logs to `~/.logs/polybar-i3/`, never fails in a way i3 would notice. Run `launch.sh --help` for details. |
| `configs/01-colours.ini` | Copied unchanged from `configs/system/polybar/configs/` (Dracula Pro palette). |
| `configs/01-fonts.ini` | Copied unchanged. |
| `configs/01-settings.ini` | Copied unchanged. |
| `configs/07-module-i3.ini` | Generated official `internal/i3` workspace module. Static workspaces are rendered as icons; dynamic Code workspaces use a fuzzy icon rule. |
| `configs/07-module-xwindow.ini` | Copied unchanged. `internal/xwindow` is generic EWMH, not XFCE-specific. |
| `configs/07-module-cpu.ini` | New. `internal/cpu`. |
| `configs/07-module-memory.ini` | New. `internal/memory`. |
| `configs/07-module-filesystem.ini` | New. `internal/fs`, `/` only. |
| `configs/07-module-network.ini` | New. `internal/network`, interface `eno1` — **host-specific**, see the comment in that file. |
| `configs/07-module-pulseaudio.ini` | Copied unchanged (same sink as the XFCE bar). |
| `configs/07-module-date.ini` | Copied from the XFCE bar, simplified: dropped a click-to-open-calendar action that had an unescaped-URL syntax polybar flags as an error (`polybar -c config.ini -d ... i3bar`). |
| `configs/07-module-tray.ini` | Copied unchanged. Uses the current module-based tray mechanism (`type = internal/tray` in `modules-right`), matching what the XFCE bar already does — no bar-level `tray-position`, which is the deprecated approach. |

## Deliberately not carried over from the XFCE bar

`configs/system/polybar/` also has `polywins` (xfwm-window-title script),
`msgvault`, `issues`, `github`, `powermenu`, Telegram/Signal tray modules,
`xkeyboard`, `privacy`, `temperature`, and `polypomo`. None of these are
required by the starter spec, several are XFCE/session-specific
(`polywins` shells out to xfwm tooling), and pulling all of them in would
turn a "minimal starter bar" into a second copy of the full XFCE bar. They
can be added deliberately later — see SESSION.md "Known limitations /
next improvements".

## Why a separate copy instead of one shared config

The old XFCE workspace setup helpers are not used here. Static and dynamic
workspace definitions live in `configs/session/workspaces.yaml`. i3 reads a
generated include derived from that file. Polybar also reads a generated
official `internal/i3` module derived from that YAML.

## Both bars share the `polybar` process name

`launch.sh` matches processes with `pgrep -x polybar` / `pkill -x polybar`,
the same as the XFCE launcher does. This is only safe because i3 and XFCE
are alternate, mutually exclusive LightDM sessions on this workstation —
never running at the same time on the same display. See SESSION.md.

## Validating changes

Safe (does not open any window, does not touch a live bar):

```bash
polybar -c configs/session/polybar/config.ini --list-monitors
polybar -c configs/session/polybar/config.ini -d modules-right i3bar
```

`launch.sh` is `shellcheck`-clean. Only start the bar for real inside an
actual i3 session — starting it from an XFCE session, or any session
sharing this X display, would draw a second bar over the live one.
