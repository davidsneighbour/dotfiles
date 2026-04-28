# `actions.sh` helper

`bashrc/helpers/actions/actions.sh` is a unified helper command for interactive workstation actions.

It consolidates:

* TOML-driven command execution (`menu`),
* autostart profile management (`autostart-enable`, `autostart-disable`),
* Dotbot setup discovery and execution (`dotbot-list`, `dotbot-run`).

This helper is invoked through a compatibility wrapper at `bashrc/helpers/actions.sh`.

---

## Command overview

```bash
actions.sh [--verbose] [--dry-run] <command> [command-options]
```

### Global options

* `--verbose`: Enables debug logging.
* `--dry-run`: Prints planned changes without mutating files.
* `--help`: Prints top-level help.

### Commands

* `menu`: Run the interactive TOML menu.
* `autostart-enable`: Symlink selected desktop entries into the host autostart folder.
* `autostart-disable`: Remove selected host autostart symlinks.
* `dotbot-list`: List available Dotbot profiles discovered from `configs/dotbot/config*.yaml`.
* `dotbot-run`: Run Dotbot using a selected or explicit profile.

---

## Logging

Logs are written under:

* `~/.logs/actions/`

with filenames following:

* `actions-YYYYMMDD-HHMMSS.log`

Example:

* `~/.logs/actions/actions-20260422-201355.log`

---

## `menu` command (TOML-driven actions)

### What it does

`menu` reads `configs/actions/actions.toml`, displays:

1. Scope picker,
2. Activity picker,
3. command preview and expanded command,
4. confirmation prompt,

and then executes the selected activity.

### Usage

```bash
actions.sh menu [--config FILE]
```

### Options

* `--config FILE`: Use a custom TOML file instead of `configs/actions/actions.toml`.

### Requirements

* `gum`
* `python3` with `tomllib` (Python 3.11+) or `tomli`

---

## Autostart management

### `autostart-enable`

Enables one or more entries from `<autostarts>/available` by creating symlinks in `<autostarts>/<host>/`.

```bash
actions.sh autostart-enable [--dir DIR] [--dir-autostarts DIR] [--host HOST] [--prompt TEXT]
```

### `autostart-disable`

Disables one or more entries by removing symlinks from `<autostarts>/<host>/`.

```bash
actions.sh autostart-disable [--host HOST] [--dir-autostarts DIR] [--prompt TEXT]
```

### Defaults

* Base autostarts directory: `configs/system/autostart`
* Available entries: `configs/system/autostart/available`
* Host folder: `configs/system/autostart/${HOSTNAME}`

---

## Dotbot integration

### Profile source

Dotbot profiles are discovered from YAML files under:

* `configs/dotbot/config*.yaml`

Profile name mapping:

* `config.yaml` -> `default`
* `config.protected.yaml` -> `protected`
* `config.workstation.yaml` -> `workstation`

### List profiles

```bash
actions.sh dotbot-list [--configs-dir DIR]
```

The list includes:

* profile label,
* file path,
* description extracted from the first `- description:` entry in each YAML.

### Run profiles

```bash
actions.sh dotbot-run [--configs-dir DIR] [--profile NAME]
```

Behavior:

* If `--profile` is omitted and `gum` exists, an interactive profile picker is shown.
* If `--profile default` is selected, the helper runs `bashrc/helpers/dotbot` with no profile argument.
* Any non-default profile runs `bashrc/helpers/dotbot <profile>`.

---

## Backward compatibility wrappers

The following wrappers now delegate into the unified helper:

* `bashrc/helpers/actions` -> `actions/actions.sh`

---

## How to extend functionality

Use this process to add a new command safely and consistently.

1. **Choose the execution model**
   * If logic is standalone and does not mutate current shell state, keep it as a helper command in `bashrc/helpers/actions/actions.sh`.
2. **Add a command handler function**
   * Implement `handle_<new-command>()` in `actions.sh`.
   * Parse flags with explicit `case` branches.
   * Provide `--help` text for the command.
3. **Register command in dispatcher**
   * Add a case branch in `main()`.
4. **Wire logging and dry-run behavior**
   * Use `log_msg` / `log_error` for visibility.
   * Respect `DRY_RUN` for filesystem or external command changes.
5. **Document command behavior**
   * Update this README with usage, options, and examples.
6. **Validate quality**
   * Run `shellcheck` on modified helper files.
   * Run command-level `--help` checks.

If the feature is better expressed as data-driven behavior, prefer extending `configs/actions/actions.toml` instead of adding more hardcoded code paths.

---

## Example workflows

### Run menu actions with explicit config

```bash
actions menu --config ./configs/actions/actions.toml
```

### Enable autostarts for another host

```bash
actions autostart-enable --host workstation-02
```

### Dry-run autostart cleanup

```bash
actions --dry-run autostart-disable --host workstation-02
```

### List and run Dotbot profile

```bash
actions dotbot-list
actions dotbot-run --profile protected
```
