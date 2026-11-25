---
name: workspace-window-icon
description: Add a workspace icon for a program to the i3 window_icons rules in this dotfiles repository. Use when the user pastes window-inspector.sh output (the Ctrl+Shift+Alt+I report with WM_CLASS, xprop, wmctrl, and "suggested i3 match" sections) and wants that window or program to get a Lucide workspace icon and name. For VS Code windows, it first offers the per-project icon in .github/config.toml.
---

# Workspace window icon

This skill turns the output of `configs/session/i3/window-inspector.sh` (`Ctrl+Shift+Alt+I`) into one rule under `window_icons.rules` in `configs/session/i3/workspaces/workspaces.yaml`. The rule gives every matching window a Lucide workspace icon, written as a `\uXXXX` escape, and a name (`slug`).

Before you edit, read `SESSION.md` and the section "Add an icon for a program" in `configs/session/i3/README.md`. This skill covers only `window_icons.rules`. For a `dynamic:` launcher or a numbered workspace, follow `.agents/references/dynamic-workspace-launcher.md` instead.

## VS Code windows: ask first

If the class is `Code` or `com.microsoft.VSCode`, stop and ask the user before you continue:

* An icon for one project or one VS Code workspace: use the per-project file below. This is usually easier, and it does not change `workspaces.yaml`.
* An icon for all VS Code windows: continue with this skill. A `Code` rule already exists, so change it in place.

The per-project icon:

* Put it in `.github/config.toml` in the project root, not in `.vscode/`. The dotfiles repository has one, for example.

  ```toml
  [workspace]
  icon = ""
  ```

* The loader accepts the `\uXXXX` escape and the literal glyph, and both give the same icon. Write the escape, as in `workspaces.yaml`, because editors can change a pasted private-use glyph. Use double quotes: in single quotes TOML does not decode the escape, and the workspace shows the six characters ``. Run the helper with `--search TERM` to find the Lucide name and its escape.
* `project_workspace_icon` in `workspaces.py` looks for the file in the opened folder and in its parent folders. For a `.code-workspace` file, it also looks in each folder that the file lists. The first non-empty icon wins. A file with invalid TOML is skipped, with a message on stderr.
* It applies only when the project opens through the VS Code workspace picker (`Ctrl+Shift+W`, `workspaces.sh --dynamic-workspace code`). A VS Code window that you move with `Ctrl+Shift+Alt+N`, or start from the Rofi new-workspace prompt, gets its icon from the `Code` rule in `window_icons.rules`.
* i3 does not need a reload. The icon shows the next time you open the project with `Ctrl+Shift+W`.

## Inputs

* The inspector output. The `WM_CLASS` line in the `xprop` section is the source of truth. If it is missing, the `suggested i3 match` line is used.
* A Lucide icon name, for example `messages-square`. If the user gives none, run `--search` with a word that describes the program, propose one icon, and ask when no candidate clearly fits. Lucide has no brand logos.
* Optional: a name. Use a short lower-case program name, for example `signal`. The default is the window class in kebab-case. Give `--slug` when the class is a reverse-DNS name, for example `com.anthropic.Claude` → `claude`.

## Procedure

1. Save the pasted output to a file in the scratchpad, or pipe it on stdin.
2. Choose the match fields:
   * `--match class` (default): every window of the program. Use this for "all windows of X".
   * `--match both`: the program shares its class with other programs, for example Chrome `--app` windows with class `google-chrome` and an instance from the app URL.
   * `--match instance`: only the instance tells the windows apart.
3. Run the helper from the repository root:

   ```bash
   .agents/skills/workspace-window-icon/scripts/window-icon-rule.py \
     --icon messages-square --slug signal --input <scratchpad>/inspector.txt
   ```

   It resolves the icon name through the tracked Lucide font map (`configs/fonts/System/lucide/info.json`), loads `workspaces.yaml` with the loader and matcher of `workspaces.py`, prints the YAML rule on stdout, and prints a `Status` and an `Action` line on stderr. It never writes files. Run it with `--help` for all options.
4. Do what the `Action` line says:
   * No rule matches: add the rule. Put it near related programs. Put it before any generic rule that it must override, because the first matching rule wins.
   * A rule already uses the same match fields: change that rule in place. Do not add a second rule.
   * An earlier rule matches first: insert the new rule before it, unless that rule is more specific (class and instance) and must keep priority.
   * Already configured: change nothing and tell the user.
5. Keep the format of the file. Write the icon as a double-quoted escape with exactly four upper-case hex digits, for example `icon: ""`. Never paste the glyph or an HTML entity. Keep the one-line comment that names the program and the Lucide icon.
6. Verify:
   * Run the helper again with the same arguments. It must report `already configured`.
   * Run `npm run lint:config`.
   * Runtime: i3 does not need a reload, because `workspaces.py` reads the file each time it runs. The rule applies from the next launch on a new workspace or the next `Ctrl+Shift+Alt+N`. Say that you did not verify the result at runtime, unless you did.
7. Add one sentence about the new icon to `SESSION.md`, next to the other per-program icon notes (for example the Claude and WhatsApp notes). Give the class, the slug, the Lucide name, and the codepoint.
8. Commit as `AGENTS.md` describes, with scope `session`, for example `feat(session): add Signal workspace icon`.

## Errors

* `no WM_CLASS found`: the paste is incomplete. Ask for the full inspector output.
* `no Lucide icon named`: use one of the suggestions or `--search`. If the icon exists upstream but not here, the tracked font is older: run `scripts/update-lucide-font.sh --check` and report it. Do not update the font unless the user asks.
