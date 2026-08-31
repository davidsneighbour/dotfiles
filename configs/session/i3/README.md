<!-- markdownlint-disable-next-line title-case-style -->
# i3 session configuration

A minimal, deliberately small i3 starter configuration. It is linked to
`~/.config/i3` by Dotbot (see `configs/dotbot/config.yaml`).

For the full session architecture (display manager, startup sequence, what
runs under i3 vs XFCE, diagnostics, recovery), see [`SESSION.md`](../../../SESSION.md)
at the repo root. This file only documents what lives in this folder.

## Files

| File | Purpose |
| --- | --- |
| `config` | The i3 configuration itself, linked to `~/.config/i3/config`. |

## Design

* `$mod` is `Mod4` (Super/Windows key).
* `$terminal` is set once (`xfce4-terminal`, the same terminal
  `update-alternatives --display x-terminal-emulator` already resolves to on
  this workstation) and referenced everywhere else — never hardcode a
  terminal binary elsewhere in this file.
* Workspaces are plain numbers (`$ws1`..`$ws9`), no icons or
  application-to-workspace rules yet (see SESSION.md "Known limitations").
* `focus_follows_mouse no` mirrors the absence of an explicit
  focus-follows-mouse override in `configs/system/xfce/xfwm4.xml`
  (xfwm4's own default is click-to-focus).
* Every `exec_always` in the startup section is written so a failure there
  cannot break the rest of i3 (backgrounded, `sh -c '... || true'` where the
  underlying command could reasonably fail). i3 itself, the terminal, and
  the launcher keybindings do not depend on any of them succeeding.

## Rofi

This configuration does **not** ship its own Rofi config. It calls
`rofi -show drun`, which resolves to the existing, shared
`configs/system/rofi/` config — the same one XFCE already binds to bare
`Super_L` in `configs/system/xfce/xfce4-keyboard-shortcuts.xml`. That config
already has `drun` mode, icons, and history enabled, so a second
i3-specific Rofi config would just be duplication.

## Polybar

Polybar is *not* linked from `~/.config/polybar` for i3 — that XDG path is
already taken by the live XFCE bar (`configs/system/polybar`, currently
running under the XFCE session on this host). i3 instead calls
`configs/session/polybar/launch.sh` directly by its repo path from
`exec_always`. See [`../polybar/README.md`](../polybar/README.md).

## Bare `Super` key limitation

i3's `bindsym` grammar matches a modifier *combined with* a keysym, not a
bare modifier on its own. The bare-`Super`-opens-launcher requirement is
implemented as:

```text
bindsym --release Super_L exec --no-startup-id rofi -show drun
```

`--release` means this only fires when `Super_L` is pressed and released
without any other key in between, so it does not fight with the
`$mod+<key>` bindings below it. If this keysym-based binding is ever
unreliable on a given keyboard layout or X11 setup, `$mod+d` is the
documented, unconditionally reliable fallback for the same command.

## Validating changes

```bash
i3 -C -c configs/session/i3/config
```

Reload a running i3 session with `Super+Shift+c`, or `i3-msg reload`.
Restart it in place with `Super+Shift+r`, or `i3-msg restart`.
