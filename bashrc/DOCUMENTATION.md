# bashrc documentation

This document is the top-level map for everything under `bashrc`. The implementation remains authoritative; where a feature already has adjacent Markdown documentation, this file links to it and only adds enough context to explain how it fits into Bash startup.

For an alphabetical list of every file and detected function/alias/method, see [`INDEX.md`](./INDEX.md).

## Startup model

### `bashrc`

Primary interactive Bash startup file. It returns immediately for non-interactive shells, resolves `DOTFILES_PATH`, sets `BASHRC_PATH`, loads all Bash libraries from `lib/*/*.bash`, sources `${HOME}/.env` with auto-export enabled, and then sources selected partials: `partials/bash`, `partials/functions`, `partials/exports`, `partials/aliases`, `partials/completions`, and `partials/prompt` when those files exist and are readable.

Runtime behaviour and requirements:

* Requires Bash; it is designed to be sourced, not executed as a standalone command.
* Uses `${HOME}/.dotfiles` when present; otherwise derives the repository path from the file location.
* Requires readable library files for shared `dnb_*` functions.
* Optionally loads `${HOME}/.env`.
* Optionally initialises `zoxide` when installed.
* Adds Bun, configured system paths, Android SDK paths, npm global paths, `/opt/firefox/firefox`, `bashrc/helpers`, and `bashrc/workspaces` to `PATH` when applicable.
* Sets `GPG_TTY`, updates the GPG agent terminal when `gpg-connect-agent` exists, configures umask/history/shell options, enables bash-completion, sets Go/Perl/Pager variables, and configures coloured man pages.

### `.bashrc`

Compatibility entry point with the same role as `bashrc` for deployments that install a dotfile named `.bashrc`. It should be treated as a sourced interactive Bash startup file.

### `.bash_profile`

Login-shell bridge for Bash. It sources the appropriate Bash startup/profile file according to the file contents.

### `.profile`

Login profile for shells/display managers that read `.profile`. It sets up user-session environment according to the file contents and should not be treated as a standalone command.

### `.bash_logout`

Logout hook for Bash login shells. It performs logout-time cleanup according to the file contents.

## Shared Bash library

Folder: [`lib/`](./lib/README.md).

The library defines reusable `dnb_*` functions for sourcing, environment loading, logging, colours, requirement checks, path management, repository config lookup, filesystem helpers, archive creation/extraction, package-list parsing, string conversion, and compatibility aliases. It is loaded before partials so aliases/functions/helpers can use it.

Requirements vary by function and are documented in [`lib/README.md`](./lib/README.md). Notable optional tools include `python3` for TOML parsing, archive tools (`tar`, `zip`, `unzip`), and package managers used by package helpers.

## Partials

Folder documentation: [`partials/DOCUMENTATION.md`](./partials/DOCUMENTATION.md).

Partials are sourced shell definitions:

* [`partials/aliases`](./partials/DOCUMENTATION.md#aliases) and [`partials/_aliases/`](./partials/_aliases/DOCUMENTATION.md) — aliases and alias-like shell functions.
* [`partials/functions`](./partials/DOCUMENTATION.md#functions) and [`partials/_functions/`](./partials/_functions/DOCUMENTATION.md) — interactive Bash functions such as `cdg`, `change_directory`, `codex-local`, `dotfiles`, `glone`, `gh_repos_list`, `searchfor`, and VS Code helpers.
* [`partials/exports`](./partials/DOCUMENTATION.md#exports) — exported environment defaults.
* [`partials/completions`](./partials/DOCUMENTATION.md#completions) and [`partials/_completions/`](./partials/_completions/DOCUMENTATION.md) — programmable completions and completion integrations.
* [`partials/prompt`](./partials/DOCUMENTATION.md#prompt) — prompt-adjacent colour setup.
* [`partials/_programs/`](./partials/_programs/DOCUMENTATION.md) — optional program initialisation snippets; these are documented but not automatically sourced by the current top-level loader unless another loader includes them.

## Helper commands

Folder documentation: [`helpers/DOCUMENTATION.md`](./helpers/DOCUMENTATION.md). Alphabetical helper index: [`helpers/INDEX.md`](./helpers/INDEX.md).

`bashrc/helpers` contains standalone helper commands and grouped helper folders. The top-level Bash startup adds this folder to `PATH`, so extensionless executable helpers can be run as commands. Existing folder-level documentation is preserved and linked from the helper documentation.

Important grouped docs:

* [`helpers/_actions/DOCUMENTATION.md`](./helpers/_actions/DOCUMENTATION.md)
* [`helpers/_lib/DOCUMENTATION.md`](./helpers/_lib/DOCUMENTATION.md)
* [`helpers/api/DOCUMENTATION.md`](./helpers/api/DOCUMENTATION.md)
* [`helpers/bash/DOCUMENTATION.md`](./helpers/bash/DOCUMENTATION.md)
* [`helpers/daily-reports/DOCUMENTATION.md`](./helpers/daily-reports/DOCUMENTATION.md)
* [`helpers/docker/DOCUMENTATION.md`](./helpers/docker/DOCUMENTATION.md)
* [`helpers/docker/examples/DOCUMENTATION.md`](./helpers/docker/examples/DOCUMENTATION.md)
* [`helpers/freshrss/DOCUMENTATION.md`](./helpers/freshrss/DOCUMENTATION.md)
* [`helpers/gh/DOCUMENTATION.md`](./helpers/gh/DOCUMENTATION.md)
* [`helpers/kando/DOCUMENTATION.md`](./helpers/kando/DOCUMENTATION.md)
* [`helpers/logs/DOCUMENTATION.md`](./helpers/logs/DOCUMENTATION.md)
* [`helpers/packages/DOCUMENTATION.md`](./helpers/packages/DOCUMENTATION.md)
* [`helpers/raindrop.io/DOCUMENTATION.md`](./helpers/raindrop.io/DOCUMENTATION.md)
* [`helpers/remarkable/DOCUMENTATION.md`](./helpers/remarkable/DOCUMENTATION.md)
* [`helpers/theme/DOCUMENTATION.md`](./helpers/theme/DOCUMENTATION.md)
* [`helpers/workspace/DOCUMENTATION.md`](./helpers/workspace/DOCUMENTATION.md)

Top-level helper commands and support files are documented in [`helpers/DOCUMENTATION.md`](./helpers/DOCUMENTATION.md), including `dotbot`, `explore`, `github-token`, `interface-restart`, `lpack`, `node-run`, `screencaps.ts`, `set-wallpaper.sh`, `set_max_listeners.cjs`, `synch-devspace.sh`, `update-npm.sh`, and `web-mirror.sh`.

## Workspace commands

Folder documentation: [`workspaces/DOCUMENTATION.md`](./workspaces/DOCUMENTATION.md). Existing overview: [`workspaces/README.md`](./workspaces/README.md).

The top-level Bash startup prepends `bashrc/workspaces` to `PATH`, making the `ws_*` commands available interactively. These commands manage XFCE workspaces, windows, rofi menus, and tile templates.

## Cron jobs

Folder documentation: [`cronjobs/DOCUMENTATION.md`](./cronjobs/DOCUMENTATION.md).

This folder contains scheduled automation for Docker backups, disk-space Discord alerts, repository updates, msgvault sync, and download synchronisation. These are standalone commands/config files, not sourced shell definitions.

## Install snippets

Folder documentation: [`installs/DOCUMENTATION.md`](./installs/DOCUMENTATION.md).

This folder contains workstation provisioning snippets for system packages, Homebrew, Cargo/Rust, Atuin, Chrome, GitHub CLI, Obsidian, Ollama, Signal, Sublime Text, Gum, Homebrew packages, and Cargo packages.

## Documentation coverage note

Every file currently under `bashrc` is listed in [`INDEX.md`](./INDEX.md). Markdown files next to a feature remain the detailed documentation for that feature; this top-level document links to them instead of duplicating their full content.
