<!-- markdownlint-disable-next-line title-case-style -->
# Scratch terminal

A persistent, summonable dropdown-style terminal for the i3 session,
implemented with i3's native scratchpad rather than a separate tool such as
Guake or Tilda. See `SESSION.md` for how this fits into the rest of the
session architecture.

## Purpose

`$mod+Return` still opens ordinary, disposable Terminator windows. This
feature adds a second, singleton Terminator instance that:

* persists for the whole i3 session (its shell, scrollback, running
  commands, and SSH sessions survive being hidden);
* stays out of the way in i3's scratchpad until summoned;
* is never a normal tiled/workspace window and never appears in Polybar's
  workspace list.

## Shortcut

`Ctrl+Shift+Alt+T`, bound in
`configs/session/i3/configs/applications.conf` to
`scratch-terminal --toggle`.

* Pressing it when the terminal does not exist yet creates it, shows it on
  the focused workspace, and focuses it.
* Pressing it while the terminal is visible on the focused workspace hides
  it back into the scratchpad (the shell keeps running).
* Pressing it while the terminal is hidden, or visible on a *different*
  workspace, shows it on the currently focused workspace instead.

It does **not** automatically follow workspace changes — switching
workspaces leaves it wherever it was; press the shortcut again to summon it
onto the new workspace.

## Lifecycle

Created lazily, on the first `--toggle`/`--show` — not started from
`session-starts.conf`. This avoids an idle Terminator process (and its
memory/CPU footprint) during sessions where the scratch terminal is never
used, at the cost of a small one-time launch delay on first use. Once
created, the same process and window persist until `i3-msg restart`/logout,
or an explicit `--restart`.

## Scratchpad and identification

The managed window is distinguished from ordinary Terminator windows by a
custom `WM_WINDOW_ROLE` (`terminator --role=scratch-terminal`), the same
mechanism `window-inspector.sh` uses for its own report terminal (see
`configs/session/i3/window-inspector.sh` and
`configs/session/i3/configs/rules.conf`). A `for_window` rule in
`rules.conf` matches on that role only:

```text
for_window [window_role="scratch-terminal"] mark scratch-terminal, floating enable, move scratchpad
```

This marks it `scratch-terminal`, floats it, and sends it to the scratchpad
the moment it maps — before the controller does anything else. Every
subsequent operation (show, hide, resize, focus, kill) targets
`[con_mark="scratch-terminal"]`, never window class/title, so it always
addresses this one window and never an ordinary Terminator instance.

## Appearance

Launched with `--profile scratch`, a Terminator profile defined only in
`configs/session/terminator/config`'s `[profiles] [[scratch]]` block (that
file is Dotbot-linked to `~/.config/terminator/config` — see
`configs/dotbot/config.yaml`). It matches the `[[default]]` profile's
palette/font but sets a transparent background:

```text
background_type = transparent
background_darkness = 0.85
```

`background_darkness` is the background's alpha (0 = fully transparent,
1 = fully opaque); rendering requires a running compositor, which
`session-starts.conf` already starts (`picom`). Ordinary `$mod+Return`
Terminator windows and `window-inspector.sh`'s report terminal are
unaffected — neither passes `--profile`, so both keep using
`[[default]]`. Adjust `background_darkness` in that one file to change the
opacity; it applies only to this window.

## Geometry

No dimensions are hardcoded. On every show, the controller reads the
*currently focused* workspace's `rect` from `i3-msg -t get_workspaces`
(i3 already excludes Polybar's reserved dock-bar strut from this rect, so
no separate `xrandr`/EWMH strut lookup is needed) and computes:

```text
width  = 50% of that rect's width
height = that rect's height
x      = that rect's x + 50% of that rect's width
y      = that rect's y
```

then applies it with `resize set` + `move position`. Because this is
recalculated on every show rather than cached, it stays correct across
resolution changes, monitor switches, and outputs with non-zero x/y
origins (multi-monitor layouts).

A freshly mapped Terminator/GTK window can still be negotiating its own
natural size (from VTE's default terminal grid) at the moment the first
`resize set` lands, and silently revert just the size a moment later
(position observed to stay correct). Right after creating the window
(first `--toggle`/`--show` of a session, or after `--restart`), the
geometry is therefore applied twice with a short pause in between — an
already-settled window being toggled back into view never re-triggers
that negotiation, so it only needs the single pass.

## Commands

```text
scratch-terminal --toggle    Show on the focused workspace (creating it first
                              if needed), or hide if already shown here.
scratch-terminal --show      Show on the focused workspace, creating it first
                              if needed. Always recalculates geometry.
                              Idempotent — never hides an already-visible
                              terminal.
scratch-terminal --hide      Move into the scratchpad if visible. Does not
                              kill the process. No-op if it does not exist.
scratch-terminal --restart   Kill and relaunch the managed terminal only,
                              then show it. Never touches ordinary
                              Terminator windows.
scratch-terminal --help      Show usage.
```

All commands accept `--verbose` for extra logging, written to
`~/.logs/terminal/`.

## Failure handling

* Missing `terminator`, `i3-msg`, or `jq`, or i3 not running: fails fast
  with an actionable message, logged via the shared `dnb_log` helpers.
* If the window does not appear after launch (crash, slow start), the
  controller times out and reports an error rather than hanging or
  silently doing nothing.
* Every operation targets the `scratch-terminal` mark, which i3 guarantees
  is held by at most one container — there is never a risk of an ordinary
  Terminator window being moved, resized, or killed by this controller.
