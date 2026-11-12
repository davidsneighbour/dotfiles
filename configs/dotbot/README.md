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
| `config.ai.yaml` | AI tool configuration links, and the restore and links of the tracked third-party agent skills (see [configs/agents](../agents/README.md#third-party-skills)). |
| `config.dracula.yaml` | Dracula theme setup. |
| `config.host-dionysus.yaml` | Host-specific setup for `dionysus`. |
| `config.host-hal2025.yaml` | Host-specific setup for `hal2025`. |
| `config.host-hal2026.yaml` | Host-specific setup for `hal2026`. |
| `config.host-locutus.yaml` | Host-specific setup for `locutus`, including the `~/.nvm/default-packages` link that makes nvm install the global npm toolset. |
| `config.protected.yaml` | Protected/private configuration links. |
| `includes.yaml` | Optional extra config chains loaded by the wrapper. |

The `skillz` helper generates the AI skill symlink profile at `cache/dotbot/config.ai-skills.yaml` before it runs Dotbot. That cache file is derived from `SKILL_SOURCES` in [bashrc/helpers/skillz](../../bashrc/helpers/skillz), is ignored by Git, and must not be edited by hand. Each source is a `<type>:<root>` entry: `collections` scans the skillwerk layout (`collections/<collection>/skills/<skill>`), and `tree` links every deepest directory with a `SKILL.md` up to three folder levels below the root (`<skill>`, `<collection>/<skill>`, or `<topic>/<collection>/<skill>`). Skill names must be unique across all sources; the same skill reached through two paths (for example a symlinked collection) is linked once.

`skillz` leaves the links of the third-party skill manager alone. These are links into `configs/agents/.agents/skills/`, created by [`configs/agents/install-skills.sh`](../agents/install-skills.sh). `skillz` stops with an error if one of its skills has the same name as a restored third-party skill. It reports all name conflicts of a run together before it stops.

## Running profiles

The AI profile links both `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` to the shared personal instructions in [`configs/agents/global-agents-instructions.md`](../agents/global-agents-instructions.md).

Run the default profile:

```bash
dotfiles
```

Run a named profile:

```bash
dotfiles host-locutus
dotfiles --config host-locutus
dotfiles --config config.host-locutus.yaml
dotfiles /absolute/path/to/config.yaml
```

Choose a profile interactively:

```bash
dotfiles --list
```

The wrapper resolves `host-locutus` to `config.host-locutus.yaml`. Absolute paths are used as written. The default profile is always `config.yaml`.

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
This repository keeps its cron plugin locally for managed cron entries:

```yaml
- plugins:
    - configs/dotbot/plugins/crontab.py
```

Plugin paths are resolved by Dotbot from the repository root because the wrapper
runs Dotbot with `--base-directory` set to the dotfiles repository.

Cron entries default to `state: present`. Assign a stable `id` when a job command can change, so reapplying a runtime-path update replaces the old job rather than adding another one. Entries without an ID retain their existing command-and-comment identity. Use `state: absent` with the original command and comment to remove that managed job while preserving other entries. Run `npm run test:dotbot-crontab` to verify removal and repeated installation without touching the installed crontab.

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

## Scheduled runtime

The `host-locutus` Git catalogue jobs refresh the installed LTS runtime through `scripts/node-cron.sh --refresh --exec` before running Node. This prevents startup races and removes version-specific runtime paths. The `node-cron-lts-weekly` job runs `scripts/node-cron.sh --update` on Sundays at 04:45 in the cron daemon’s local timezone. Reapply this profile to replace the two managed jobs and install the weekly LTS update. See [Node runtime maintenance](../../docs/node-runtime.md) for the stable symlink, offline refresh, and explicit `--lts` update operation.

The hourly log cleanup jobs in `host-locutus` and `host-dionysus` use the same offline runtime refresh and create the cron log directory before redirecting output. Reapply the relevant host profile to replace the old direct script call with the stable `cleanup-logs-hourly` job. The profiles explicitly remove the old managed entry to prevent duplicate runs.

## Local npm CLI links

The `host-locutus` profile has one `shell` entry per local npm CLI repository. The initial entry links `dmarc` from `${HOME}/github.com/davidsneighbour/dmarcery`. It prints the active Node version and npm global prefix before running `npm link` inside the repository. Missing repositories and failed commands make the task fail visibly.

Select the required runtime first, then apply the host profile:

```bash
nvm use 24
dotfiles host-locutus
```

This runs all host-profile tasks, including local CLI linking. It uses Node and npm inherited through `PATH`; it does not load nvm, switch versions, or apply the package's `.nvmrc`. Repeat after installing or switching to a Node version that needs these commands. The dmarcery package currently requires Node 24 or later.

To add another package, copy one shell entry in `config.host-locutus.yaml`, change its description and repository path, and retain the runtime reporting and `&&` failure handling. Use the repository path, not the executable name: npm reads command names from the package's `bin` field. Keep package preparation (dependencies and any required build) in that repository's documented workflow. For dmarcery, `dmarc` points to `dist/cli.js`, so its build must exist before the command can be used.

Reapplying the profile reruns `npm link` for the selected npm prefix. npm can run package lifecycle scripts; this is an explicit setup operation, with npm's normal behaviour and failure reporting. It does not run on shell startup or on `nvm use`, and it does not replace the host's `default-packages` list. Do not add `sudo`, `--force`, or automatic runtime switching to these entries.

Completion is registered separately in `bashrc/partials/_completions/commands.sh`; linking makes the executable available to that completion engine.
