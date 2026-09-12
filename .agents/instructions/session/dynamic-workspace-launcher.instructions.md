---
name: Dynamic Workspace Launcher
description: Procedure for making a program open into its own freshly created, icon-labelled i3 workspace, reusing the same mechanism as the Ctrl+Shift+W VS Code picker.
applyTo: configs/session/i3/workspaces/**
---

<!-- markdownlint-disable-next-line title-case-style -->
# Dynamic workspace launcher

## Scope

Read this before adding or changing a `dynamic.*` entry in
`configs/session/i3/workspaces/workspaces.yaml`, before touching
`command_launch`/`load_dynamic_applications` in
`configs/session/i3/workspaces/workspaces.py`, or before wiring a new
`.desktop` launcher (`configs/system/launchers/*.desktop`) or i3 `bindsym`
to open a program into its own workspace. Read
[`i3-keybindings.instructions.md`](i3-keybindings.instructions.md) too if
the trigger is a `bindsym`/`exec` line rather than a `.desktop` file.

This mechanism already exists for exactly one case
(`Ctrl+Shift+W` → the VS Code project picker, see `SESSION.md`'s Rofi
section) and is generic: `workspaces.py launch` switches to a new i3
workspace numbered 10+ (see `next_dynamic_workspace_number`), labels it
with an icon, then starts the target program in it. Adding a new launcher
needs exactly two inputs:

1. **What program to launch** — a fixed command (binary or existing
   launcher script), with any fixed arguments it always needs. This is
   `dynamic.<name>.command` in `workspaces.yaml`.
2. **What icon labels the workspace** — a single Nerd Font glyph codepoint
   from the same private-use range already used throughout
   `workspaces.yaml` (e.g. the existing `bots` workspace and the `chatgpt`
   dynamic app both use U+E1BB, a robot glyph). This is
   `dynamic.<name>.icon`.

## Step 1 — resolve the icon to an actual glyph character

Callers often hand you the icon as an HTML decimal entity
(`&#57787;`) or a `\uXXXX` escape. Convert it to a real codepoint first —
do not paste the entity text into YAML:

```bash
python3 -c "print(hex(57787))"   # -> 0xe1bb
```

`workspaces.yaml` accepts either form for the `icon` field of a
double-quoted YAML scalar:

* a literal glyph character (used by `dynamic.code.icon`, and by most of
  the static `workspaces:` list), or
* the literal escape text `""` (used by the `bots` workspace) — YAML
  decodes `\uXXXX` escapes inside double-quoted strings.

Either is fine; match whichever style neighbouring entries in the file
use. After editing, always confirm the codepoint actually landed correctly
— editors and shells mangle private-use glyphs easily:

```bash
python3 -c "
import yaml
d = yaml.safe_load(open('configs/session/i3/workspaces/workspaces.yaml'))
print(hex(ord(d['dynamic']['<name>']['icon'])))
"
```

## Step 2 — add the `dynamic.<name>` entry

In `configs/session/i3/workspaces/workspaces.yaml`, under the existing
`dynamic:` key:

```yaml
dynamic:
  <name>:
    icon: "<glyph>"
    workspace_prefix: <name>
    command:
      - /path/to/program-or-launcher
      - --any-fixed-flag
```

* `command` is a plain argv list — no shell, no quoting tricks. Put every
  fixed argument the program always needs here.
* `workspace_prefix` is currently informational only (`command_launch`
  does not read it) — set it to `<name>` for consistency with the
  existing `code` entry rather than skipping it.
* `--target` (see `command_launch` in `workspaces.py`) is optional. When a
  target is passed, it is appended as the final argv element and can also
  supply a per-project icon override via a `.github/config.toml`
  `[workspace] icon = "..."` (see `project_workspace_icon`); when no
  target is given (a fixed single-purpose launcher, e.g. `chatgpt`), the
  program is started with only its fixed `command` argv, and the
  workspace uses `dynamic.<name>.icon` directly. Don't invent a fake
  target path to work around this — `--target` was made optional
  specifically so fixed launchers don't need one.

## Step 3 — wire up the trigger

Two shapes, pick the one that matches how the program should be started:

* **A `.desktop` launcher** (app-menu entry, no picker) — point `Exec` at
  the workspace launcher directly, no picker script needed:

  ```ini
  Exec=/home/patrick/.dotfiles/configs/session/i3/workspaces/workspaces.py launch --application <name>
  ```

  Keep the rest of the `.desktop` file (`Name`, `Icon`, `StartupWMClass`,
  `Path`, `Categories`) as it already is for that app — only `Exec`
  changes.

* **An i3 `bindsym`** that should offer a picker first (like
  `Ctrl+Shift+W`) — go through `configs/session/rofi/workspaces.sh
  --dynamic-workspace <name>` instead of calling `workspaces.py launch`
  directly, and follow
  [`i3-keybindings.instructions.md`](i3-keybindings.instructions.md)'s
  quoting rules (wrap the whole invocation in `sh -c '...'` once any env
  vars or flags are involved — see Mistake 1 there).

## Step 4 — validate before treating it as done

```bash
python3 -m py_compile configs/session/i3/workspaces/workspaces.py   # only if workspaces.py changed
python3 -c "import yaml; yaml.safe_load(open('configs/session/i3/workspaces/workspaces.yaml'))"
python3 configs/session/i3/workspaces/workspaces.py launch --help
```

Do not actually fire `launch --application <name>` as a side-effecting
test unless you intend to open the real program in a real new workspace —
it has visible effects (creates a new i3 workspace, starts the process).
If you do need to verify the binding itself (the `bindsym`/`.desktop`
path, not just the YAML), follow the runtime verification steps in
[`i3-keybindings.instructions.md`](i3-keybindings.instructions.md)
("How to actually verify a binding").

## Step 5 — update docs

* Add the new dynamic launcher to `SESSION.md`'s Rofi/workspace section
  alongside the existing `code` description.
* If the trigger is a new `bindsym`, update `SESSION.md`'s keybinding
  table too (required by
  [`i3-keybindings.instructions.md`](i3-keybindings.instructions.md)).
