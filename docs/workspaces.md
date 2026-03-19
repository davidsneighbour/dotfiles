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

## Quick verification checklist

After changing workspaces:

1. The number of `icon-*` entries equals the number of `[[workspace]]` titles.
2. `icon-*` names exactly match `config.toml` titles and order.

If any of these drift, workspace labels/icons become inconsistent between XFCE and Polybar.
