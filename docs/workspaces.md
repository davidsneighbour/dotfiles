# Workspace Configuration

This repository currently uses **three separate workspace definitions**.

When you add, remove, or reorder a workspace, update all three sources in the same change.

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

## 3) XFCE workspace creation at Polybar startup

File:

* `configs/system/polybar/start.sh`

Update the `workspace-setup.sh` invocation:

* `--count` must match the number of workspaces
* `--names` must contain the same ordered names

Example:

```bash
~/.dotfiles/bashrc/helpers/workspace-setup.sh --count 9 --names "Dashboard,Web,Code,Ops,Notes,Bots,Dotfiles,Comms,Cookies"
```

## Quick verification checklist

After changing workspaces:

1. The number of `[[workspace]]` blocks equals `--count`.
2. The number of `icon-*` entries equals `--count`.
3. `--names` order exactly matches `config.toml` titles.
4. `icon-*` names exactly match `config.toml` titles.

If any of these drift, workspace labels/icons become inconsistent between XFCE and Polybar.
