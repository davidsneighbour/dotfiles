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
| `configs/workspaces.conf` | Generated workspace variable include, derived from `workspaces/workspaces.yaml`. |
| `rofi.rasi` | Small standalone Rofi override used by the launcher bindings — see "Rofi" below. |
| `check.sh` | Read-only diagnostic: reports whether i3/Polybar/Rofi are installed and running. Run `check.sh --help` for details. Never modifies the desktop. |

## Design

* `$mod` is `Mod4` (Super/Windows key).
* `$terminal` is set once (`xfce4-terminal`, the same terminal
  `update-alternatives --display x-terminal-emulator` already resolves to on
  this workstation) and referenced everywhere else — never hardcode a
  terminal binary elsewhere in this file.
* Static workspaces are configured in `workspaces/workspaces.yaml`. Their labels are
  for maintenance only; i3 receives numbered icon workspace names such as
  `2:` from `configs/workspaces.conf`. User-facing surfaces show the icon
  only. Run
  `workspaces/workspaces.py generate-i3 --write` and
  `workspaces/workspaces.py generate-polybar --write` after changing the YAML.
* Dynamic application workspaces are also configured in `workspaces/workspaces.yaml`.
  `Ctrl+Shift+W` opens the VS Code workspace picker and launches the
  selected project in a temporary `code` workspace. i3 removes that
  workspace from its live list once the last window in it closes.
* The Alt+Tab window switcher reads the same YAML and shows workspace icons
  instead of raw i3 workspace names. It hides panel/dock windows such as
  the i3 Polybar instance, because they are session infrastructure rather
  than useful focus targets.
* `focus_follows_mouse no` mirrors xfwm4's own default (click-to-focus);
  dotfiles no longer manages XFCE's xfconf settings at all (see SESSION.md),
  but this stayed the intended i3 behaviour regardless.
* Every `exec_always` in the startup section is written so a failure there
  cannot break the rest of i3 (backgrounded, `sh -c '... || true'` where the
  underlying command could reasonably fail). i3 itself, the terminal, and
  the launcher keybindings do not depend on any of them succeeding.

## Rofi

This configuration ships a small, standalone Rofi override,
[`rofi.rasi`](./rofi.rasi), rather than a full forked config. It sets the
functional properties the starter spec calls for that rofi does not enable
by default — `matching: "fuzzy"`, explicit `case-sensitive: false`,
`show-icons: true`, an explicit `width`/`location` — while reusing the
existing `configs/session/rofi/theme.rasi` visuals via `@theme "theme"`
(confirmed with `rofi -config rofi.rasi -dump-theme`), so nothing is
visually duplicated and there is no second theme to keep in sync.
`configs/session/rofi/` is i3-only: it is Dotbot-linked to `~/.config/rofi`
and holds the base config, theme, and the Alt+Tab window-switcher and
VS Code workspace-picker scripts. XFCE no longer has any Rofi bindings of
its own — its bare `Super_L` and `Ctrl+Shift+W` shortcuts were removed when
Rofi moved here, and dotfiles no longer manages XFCE's keyboard-shortcuts
xfconf file at all (see SESSION.md).

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
bindsym --release Super_L exec --no-startup-id $rofi
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

For a broader "is everything installed and running" check, run
[`check.sh`](./check.sh) (read-only, safe to run from any session).
