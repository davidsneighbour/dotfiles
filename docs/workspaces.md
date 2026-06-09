# Workspace Configuration

This repository currently uses **two workspace definitions**.

When you add, remove, or reorder a workspace, keep these sources aligned in the same change.

## 1) Workspace source of truth for names/icons

File:

* `bashrc/workspaces/config.toml`

Add or remove a `[[workspace]]` block.

Example:

```toml
[[workspace]]
title = "Bots"
icon = ""
```

Icon reference for Lucide Nerd Font:

* `file:///home/patrick/.fonts/Lucide/unicode.html`

## 2) Polybar icon mapping

File:

* `configs/system/polybar/configs/07-module-workspaces.ini`

Update `icon-N = <WorkspaceName>;<Icon>` entries:

* Keep indexes continuous (`icon-0`, `icon-1`, ...)
* Keep order aligned with `config.toml`
* Add/remove/reindex entries when workspace list changes

Example (with "Bots" inserted after "Notes"):

```ini
icon-4 = Notes;
icon-5 = Bots;
icon-6 = Dotfiles;
icon-7 = Comms;
icon-8 = Cookies;
```

## 3) XFCE workspace creation at Polybar startup (derived automatically)

File:

* `configs/system/polybar/start.sh`

The startup script now reads workspace titles directly from:

* `bashrc/workspaces/config.toml` (`[[workspace]]` -> `title`)

and derives:

* `--count` from the number of configured workspace titles
* `--names` from the ordered list of workspace titles

You do **not** need to manually edit `--count`/`--names` in `start.sh` anymore.

## 4) Temporary workspaces (runtime only)

The sources above define **permanent** workspaces. To add a throwaway workspace at runtime, use:

* `bashrc/workspaces/ws_add_workspace`

It appends one workspace to the live xfwm4 state and prints the new 1-based index to stdout. It never edits `config.toml`. The next restart re-applies the permanent set and drops the temporary workspace.

Interactive use opens a rofi input box:

```bash
ws_add_workspace
```

The rofi dispatcher exposes the same flow:

```bash
ws_rofi_actions --mode add
```

### Scripted use: launch a program on a fresh workspace

Capture the printed index and pass it to `ws_launch_program`. Reference the temporary workspace by index, because `ws_launch_program --workspace NAME` resolves names from `config.toml` and does not see temporary names.

```bash
#!/bin/bash
set -euo pipefail

ws_num="$(ws_add_workspace "Obsidian")"
ws_launch_program --workspace "${ws_num}" --switch --exec "obsidian"
```

### Icons on temporary workspaces

Polybar maps icons by workspace name in `configs/system/polybar/configs/07-module-workspaces.ini`, and that map loads at Polybar start. A temporary name is absent from the map, so Polybar shows `icon-default` for it.

There are two ways to get an icon:

1. Embed a Nerd Font glyph in the name. The glyph shows in the active-workspace label via the `%name%` token. Pick a glyph from the Lucide reference at `file:///home/patrick/.fonts/Lucide/unicode.html`.

   ```bash
   # Replace <glyph> with a Nerd Font icon from the Lucide reference.
   ws_num="$(ws_add_workspace "<glyph> Obsidian")"
   ws_launch_program --workspace "${ws_num}" --switch --exec "obsidian"
   ```

2. Make the workspace permanent for a fully mapped icon. Add a `[[workspace]]` block plus a matching `icon-N` entry, as described in sections 1 and 2, then launch by name:

   ```bash
   ws_launch_program --workspace Obsidian --switch --exec "obsidian"
   ```

   Choose this when a program should always live on its own labelled workspace.

## Quick verification checklist

After changing workspaces:

1. The number of `icon-*` entries equals the number of `[[workspace]]` titles.
2. `icon-*` names exactly match `config.toml` titles and order.

If any of these drift, workspace labels/icons become inconsistent between XFCE and Polybar.
