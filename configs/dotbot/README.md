# Dotbot configurations

This directory contains the Dotbot profiles used by the `dotfiles` helper
command. Dotbot is installed as a system command through Homebrew and is wrapped
by [bashrc/helpers/dotfiles](../../bashrc/helpers/dotfiles).

Scripts are the source of truth. This README documents how the wrapper expects
the configuration files to be named and composed.

## Files

| File | Purpose |
| --- | --- |
| `config.yaml` | Default workstation setup, run by `dotfiles` with no arguments. |
| `config.ai.yaml` | AI tool configuration links. |
| `config.dracula.yaml` | Dracula theme setup. |
| `config.host-dionysus.yaml` | Host-specific setup for `dionysus`. |
| `config.host-hal2025.yaml` | Host-specific setup for `hal2025`. |
| `config.host-locutus.yaml` | Host-specific setup for `locutus`. |
| `config.protected.yaml` | Protected/private configuration links. |
| `includes.yaml` | Optional extra config chains loaded by the wrapper. |

## Running profiles

Run the default profile:

```bash
dotfiles
```

Run a named profile:

```bash
dotfiles host-locutus
dotfiles --config host-locutus
dotfiles --config config.host-locutus.yaml
```

Choose a profile interactively:

```bash
dotfiles --list
```

The wrapper resolves `host-locutus` to `config.host-locutus.yaml`. The default
profile is always `config.yaml`.

## Config format

Dotbot configuration files are YAML arrays. Each item is a Dotbot directive:

```yaml
---
- defaults:
    link:
      create: true
      relink: true

- link:
    ~/.example: configs/example

- shell:
    - description: Run an idempotent setup command
      command: ./path/to/helper --verbose
      quiet: true
```

Keep commands idempotent. A config must be safe to run more than once on the same
host.

## Plugins

Dotbot plugins are loaded from configuration files with the `plugins` directive.
This repository currently uses `crontab-dotbot` for managed cron entries:

```yaml
- plugins:
    - modules/dotbot-plugins/crontab-dotbot/
```

Plugin paths are resolved by Dotbot from the repository root because the wrapper
runs Dotbot with `--base-directory` set to the dotfiles repository.

## Include chains

Dotbot itself accepts multiple `--config-file` values. The `dotfiles` wrapper
uses that feature to load extra configs declared in `includes.yaml`.

Use this when another repository or local folder owns setup that should run as
part of a dotfiles profile without copying that setup into this repository.

Example:

```yaml
---
host-locutus:
  - ${HOME}/github.com/davidsneighbour/example-project/dotbot.yaml
  - config.ai.yaml
```

In this example, running `dotfiles host-locutus` calls Dotbot with:

```bash
dotbot --config-file configs/dotbot/config.host-locutus.yaml \
  "${HOME}/github.com/davidsneighbour/example-project/dotbot.yaml" \
  configs/dotbot/config.ai.yaml
```

### Include keys

Top-level keys identify the primary config being run. These forms are
equivalent:

```yaml
host-locutus:
config.host-locutus.yaml:
```

Use one key per primary profile.

### Include values

Include values are ordered. The primary config always runs first, then each
included config runs in the order listed.

Supported include paths:

| Path form | Resolution |
| --- | --- |
| `config.ai.yaml` | Relative to `configs/dotbot/`. |
| `relative/path.yaml` | Relative to `configs/dotbot/`. |
| `/absolute/path.yaml` | Used as written. |
| `~/path.yaml` | Expanded from `${HOME}`. |
| `$HOME/path.yaml` | Expanded from `${HOME}`. |
| `${HOME}/path.yaml` | Expanded from `${HOME}`. |

Every included file must exist before Dotbot starts. Missing includes fail the
wrapper before any Dotbot directives run.

## Safety rules

* Keep host-specific automation in `config.host-*.yaml`.
* Keep reusable workstation links and folders in `config.yaml`.
* Keep private or protected links in `config.protected.yaml`.
* Prefer existing helper commands over inline shell logic.
* Use absolute paths for external project includes unless the include lives in
  this directory.
* Do not use includes as hidden control flow. They should only compose complete
  Dotbot config files.

## Validation

Useful checks after changing this directory or the wrapper:

```bash
bash -n bashrc/helpers/dotfiles
npm run test:shell
npm run check
npm run lint:config
npm run lint:shell
```
