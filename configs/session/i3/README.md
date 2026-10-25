<!-- markdownlint-disable-next-line title-case-style -->
<!-- markdownlint-disable-next-line dnb-title-case-style -->
# i3 session configuration

The i3 configuration of the desktop session. It is linked to
`~/.config/i3` by Dotbot (see `configs/dotbot/config.yaml`).

For the full session architecture (display manager, startup sequence,
diagnostics, recovery), see [`SESSION.md`](../../../SESSION.md)
at the repo root. This file only documents what lives in this folder.

## Files

| File | Purpose |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `config` | The i3 configuration itself, linked to `~/.config/i3/config`. |
| `configs/workspaces.conf` | Generated workspace variable include, derived from `workspaces/workspaces.yaml`. |
| `configs/rules.conf` | `for_window`/`assign` window rules — see "Window rules" below. |
| `rofi.rasi` | Small standalone Rofi override used by the launcher bindings — see "Rofi" below. |
| `layouts/` | Saved workspace layouts (JSON, tracked in git) — see "Workspace layouts" below. |
| `workspaces/layouts.py` | Saves, applies, deletes, and edits workspace layouts — see "Workspace layouts" below. |
| `window-inspector.sh` | Click a window, see its WM_CLASS/role/title/PID/geometry in a floating terminal — see "Window rules" below. Bound to `Ctrl+Shift+Alt+I`. |

## Startup

`configs/session-starts.conf` holds every command that starts with the session (colour scheme, GNOME Keyring, polkit agent, background, Polybar, Enpass, Barrier, Discord, xss-lock, wallpaper, Google Drive mounts, and the system checkup). Every line is non-fatal. See "Startup sequence" in [`SESSION.md`](../../../SESSION.md) for the full table.

## Design

* `$mod` is `Mod4` (Super/Windows key).
* `$terminal` is set once (`terminator`) and referenced everywhere else — never hardcode a
  terminal binary elsewhere in this file.
* Static workspaces are configured in `workspaces/workspaces.yaml`. Their `name`
  values are for maintenance only (they appear as a trailing comment in the
  generated `configs/workspaces.conf`); i3 receives numbered icon workspace names
  such as
  `2:` from `configs/workspaces.conf`. User-facing surfaces show the icon
  only. Run
  `workspaces/workspaces.py generate-i3 --write` and
  `workspaces/workspaces.py generate-polybar --write` after changing the YAML.
* Dynamic application workspaces are also configured in `workspaces/workspaces.yaml`.
  `Ctrl+Shift+W` opens the VS Code workspace picker and launches the
  selected project in a temporary workspace whose visible indicator is the
  nearest `.github/config.toml` `[workspace] icon` value when it exists, or
  the configured Code icon otherwise. For `.code-workspace` files, folder
  entries are checked too. i3 removes that workspace from its live list once
  the last window in it closes.
* Workspace icons by window class are configured in `workspaces/workspaces.yaml`'s `window_icons:` section: a `fallback` icon plus class/instance `rules`. Find a window's class with `window-inspector.sh`. Two features use it:
  * `Ctrl+Shift+Alt+N` moves the currently focused managed window into a fresh temporary workspace, using these rules to choose the workspace icon. Scratchpad and session-infrastructure windows are refused by the same switchable-window filter the Alt+Tab switcher uses.
  * Bare `Super` (and `Super+Shift+D`) starts the program selected in Rofi on a new dynamic workspace through `workspaces.py launch-command`. When the command runs the same executable as a `dynamic:` entry, that entry's icon is used at once. Otherwise the workspace starts with the fallback icon, and `workspaces.py set-workspace-icon` renames it from these rules when the first window appears (it waits up to 15 seconds). `Super+D` starts the program on the current workspace.
* The Alt+Tab window switcher reads the same YAML and shows workspace icons
  instead of raw i3 workspace names. It hides panel/dock windows such as
  the i3 Polybar instance, because they are session infrastructure rather
  than useful focus targets.
  The Alt+Tab switcher recognises both `Code` and `com.microsoft.VSCode` window classes. Its first column shows the VS Code project name from the window title, or `Code` when no project name is available.
* `Ctrl+Shift+Alt+F` shows the canonical, singleton Files workspace (a
  two-pane Thunar environment: LEFT is user-controlled, RIGHT is where
  `explore`/`xdg-open`/`gio open` directory requests land). Unlike the code
  dynamic workspaces above, there is at most one Files workspace at a time,
  reserved at i3 workspace number 90. Its ownership deliberately stays
  outside `workspaces.yaml`/`workspaces.py` — see
  [`../filemanager/README.md`](../filemanager/README.md) for the full
  architecture; this file only documents the one keybinding
  (`configs/applications.conf`) that invokes the controller.
* `focus_follows_mouse no` — focus changes on click only.
* Every `exec_always` in the startup section is written so a failure there
  cannot break the rest of i3 (backgrounded, `sh -c '... || true'` where the
  underlying command could reasonably fail). i3 itself, the terminal, and
  the launcher keybindings do not depend on any of them succeeding.

## Add an icon for a program

Programs started on a new workspace (bare `Super`, `Super+Shift+D`, or `Ctrl+Shift+Alt+N`) get their workspace icon from `window_icons.rules` in [`workspaces/workspaces.yaml`](workspaces/workspaces.yaml). A program without a rule gets the `fallback` icon.

1. Find the window class. Press `Ctrl+Shift+Alt+I` (`window-inspector.sh`), click the program's window, and copy the `class` value, for example `firefox`. Matching ignores upper and lower case. For a program whose windows share a class with another program, use `instance` instead of `class`.
2. Choose a glyph from one of the icon fonts that Polybar loads (see `configs/session/polybar/configs/01-fonts.ini`) and note its codepoint, for example `U+E0E8`.
3. Add a rule under `window_icons.rules`. Write the icon as a `\uXXXX` escape in double quotes (or paste the glyph itself). `slug` is an optional note for maintainers:

   ```yaml
   window_icons:
     rules:
       - class: firefox
         slug: web
         icon: "\uE0E8"
   ```

4. Check that the codepoint is correct. Editors and terminals often change private-use glyphs when you paste them:

   ```bash
   python3 -c "
   import yaml
   d = yaml.safe_load(open('configs/session/i3/workspaces/workspaces.yaml'))
   print([(r['class'], hex(ord(r['icon']))) for r in d['window_icons']['rules'] if 'class' in r])
   "
   ```

You do not need to reload i3. `workspaces.py` reads `workspaces.yaml` each time it runs, so the rule applies from the next launch. The first rule that matches wins.

## Workspace layouts

`workspaces/layouts.py` saves the focused workspace as a layout and starts saved layouts again on a new dynamic workspace (10+). Layout files are in [`layouts/`](layouts/), one `<label-slug>.json` file for each layout. They are tracked in git, so commit a layout when you want to keep it.

| Binding | Command | Action |
| -------------- | ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `Ctrl+Super+S` | `layouts.py save` | Ask for a label in Rofi, save the focused workspace, then open the file in `subl`. Asks before it replaces a layout with the same label. |
| `Ctrl+Super+L` | `layouts.py apply` | Pick a layout in Rofi. Make a new dynamic workspace, put the placeholders there (`append_layout`), and start the `launch` commands. |
| `Ctrl+Super+D` | `layouts.py delete` | Pick a layout in Rofi, confirm (`No` is the default), and delete its file. |
| `Ctrl+Super+E` | `layouts.py edit` | Pick a layout in Rofi and open its file in `subl`. |

Each command also works without Rofi: `--label` for `save`, `--layout <label>` for the others, and `--yes` to skip confirmation. Run `layouts.py --help` for all flags.

File format:

* `label` — the name shown in Rofi.
* `icon` — the workspace icon. `save` takes it from `window_icons.rules` for the first window. An empty value gives `window_icons.fallback`. Icons are written as `\uXXXX` escapes.
* `launch` — one entry for each window: `command` (an argv list, no shell) and an optional `cwd`. `save` reads the command from the window's process (`_NET_WM_PID`, then `/proc/<pid>/cmdline`). The `window` field is only a note. If `save` cannot find the process, `command` is empty and a `note` tells you to add it.
* `layout` — i3 containers for `append_layout`. Windows are placeholders with `swallows` rules (exact `class` and `instance` regexes). i3 puts each new window into the first placeholder that it matches. To match more loosely, edit the regexes (for example remove `instance`).

Limits:

* The saved command is the command of the window's process. Check it after a save. For example, a terminal saves the terminal command, not the shell or program that ran in it.
* A single-instance program that only raises an existing window does not fill its placeholder. Add a flag such as `--new-window` to its command if the program has one.
* A placeholder that is never filled stays on the workspace. Focus it and close it with `Super+Shift+Q`.

## Rofi

This configuration ships a small, standalone Rofi override,
[`rofi.rasi`](./rofi.rasi), rather than a full forked config. It sets the
functional properties that rofi does not enable by default — `matching: "fuzzy"`, explicit `case-sensitive: false`,
`show-icons: true`, an explicit `width`/`location` — while reusing the
existing `configs/session/rofi/theme.rasi` visuals via `@theme "theme"`
(confirmed with `rofi -config rofi.rasi -dump-theme`), so nothing is
visually duplicated and there is no second theme to keep in sync.
`configs/session/rofi/` is i3-only: it is Dotbot-linked to `~/.config/rofi`
and holds the base config, theme, power menu, and the Alt+Tab
window-switcher and VS Code workspace-picker scripts.

## Window rules

`configs/rules.conf` holds this config's `for_window`/`assign` rules,
included separately from `keybindings.conf`/`applications.conf`. See
"Window rules" in [`SESSION.md`](../../../SESSION.md) for the full list.
The report terminal of [`window-inspector.sh`](./window-inspector.sh) is
matched on `WM_WINDOW_ROLE` (set via `terminator --role=window-inspector`,
not title or class, so it never matches a normal terminator window).

`window-inspector.sh` (`Ctrl+Shift+Alt+I`) runs `xdotool selectwindow` to
let you click any window, then prints its `WM_CLASS`, `WM_WINDOW_ROLE`,
title, PID, geometry, desktop (via `xdotool`, `xprop`, and `wmctrl`) — plus
a ready-to-paste `[class="..." instance="..."]` match snippet — into that
floating terminal. It is a read-only diagnostic: it never moves, closes, or
otherwise changes the window it inspects.

## Polybar

Polybar is not linked from `~/.config/polybar`. i3 calls
`configs/session/polybar/launch.sh` directly by its repo path from
`exec_always`. See [`../polybar/README.md`](../polybar/README.md).

## Bare `Super` key limitation

i3's `bindsym` grammar matches a modifier *combined with* a keysym, not a
bare modifier on its own. The bare-`Super`-opens-launcher binding is
implemented as:

```text
bindsym --release Super_L exec --no-startup-id $rofi_new_workspace
```

`--release` means this only fires when `Super_L` is pressed and released
without any other key in between, so it does not fight with the
`$mod+<key>` bindings below it. If this keysym-based binding is ever
unreliable on a given keyboard layout or X11 setup, `$mod+Shift+d` is the
documented, unconditionally reliable fallback for the same command.
`$mod+d` opens the same launcher, but starts the program on the current
workspace.

## Validating changes

```bash
i3 -C -c configs/session/i3/config
```

Reload a running i3 session with `Super+Shift+c`, or `i3-msg reload`.
Restart it in place with `Super+Shift+r`, or `i3-msg restart`.

For a broader "is everything installed and running" check, run the session checks of the [system checkup](../../../tools/system-checkup/README.md) (read-only, safe to run from any session): `~/.dotfiles/tools/system-checkup/system-checkup --verbose`.

## Colour scheme

`configs/session-starts.conf` maintains the dark preference through the shared [session colour-scheme layer](../colour-scheme/README.md). Enpass startup and the assistant binding use its per-tool compatibility config. The Enpass override changes only the app environment.
