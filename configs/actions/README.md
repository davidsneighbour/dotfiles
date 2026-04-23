# Actions configuration (`configs/actions/actions.toml`)

This directory contains the configuration used by:

* `actions menu`

The file is intentionally data-driven so common interactive operations can be changed without editing helper code.

---

## File format

The menu expects this TOML shape:

```toml
[scopes.<scope_id>]
label = "Human readable scope label"

[scopes.<scope_id>.activities.<activity_id>]
label = "Human readable activity label"
cmd = "Shell command to execute"
```

### Required keys

For each activity:

* `label` (string): Displayed in the picker.
* `cmd` (string): Command template executed via `bash -c` after confirmation.

For each scope:

* `label` (string): Displayed in scope selection.

---

## Current example

`actions.toml` currently defines:

* `keybindings`
  * `export`
  * `import`
* `cinnamon`
  * `export`
  * `import`

These activities manage `dconf` import/export workflows.

---

## Variable expansion behavior

`cmd` values support shell variable expansion at runtime.

Common examples:

* `${DOTFILES}`
* `${HOME}`

`actions.sh` exports `DOTFILES` automatically to the repository root before activity execution.

Use explicit `${VAR}` syntax for all variables.

---

## How to add a new scope

1. Create the scope section:

```toml
[scopes.network]
label = "Network settings"
```

1. Add one or more activities:

```toml
[scopes.network.activities.export]
label = "Export network snapshot"
cmd = 'nmcli connection show > "${DOTFILES}/etc/network/connections.txt"'
```

1. Save the file and run:

```bash
actions.sh menu --config ./configs/actions/actions.toml
```

---

## How to add a new activity to an existing scope

Add a new block under `scopes.<existing_scope>.activities.<new_activity>` with `label` and `cmd`.

Example:

```toml
[scopes.cinnamon.activities.reset]
label = "Reset Cinnamon settings"
cmd = 'dconf reset -f /org/cinnamon/'
```

---

## Safety guidelines for `cmd`

* Prefer explicit absolute paths where practical.
* Prefer idempotent commands for repeatability.
* Keep destructive commands obvious in labels.
* Test commands manually before adding them to shared config.

Because commands are executed directly, review all config changes as code.
