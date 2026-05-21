# DNB config helpers

This file defines the repository rules and usage examples for reading and writing small configuration files from Bash helpers, `bashrc`, launchers, and dotfiles automation.

The public Bash API lives in `bashrc/lib/20-config/dnb-config.bash`.

## Purpose

Use the DNB config helpers when a shell script needs to read or update structured configuration without hard-coding fragile `grep`, `sed`, or `awk` parsing.

Supported use cases include:

* Read repository or machine-local settings from TOML.
* Read YAML settings used by tools or desktop helpers.
* Set small scalar values from CLI scripts.
* Delete deprecated keys during migration scripts.
* Keep stdout clean enough for command substitution and pipelines.

## Public helpers

```bash
dnb_config_get --file PATH SELECTOR
dnb_config_set --file PATH --selector SELECTOR --type TYPE --value VALUE
dnb_config_delete --file PATH --selector SELECTOR
dnb_config_has --file PATH SELECTOR
dnb_config_list_keys --file PATH
```

## Backend rules

* TOML reads use Python 3.11+ `tomllib`.
* YAML and JSON reads use `dasel`.
* All write and delete operations use `dasel`.
* New scripts MUST treat `dasel` as the write backend.
* New scripts MUST NOT parse YAML, TOML, or JSON with `grep`, `sed`, or `awk`.
* New scripts MUST check exit codes instead of comparing stdout against sentinel strings like `false`, `null`, or `unset`.
* New scripts SHOULD keep configuration selectors as simple dotted paths where possible.
* Keys containing literal dots SHOULD be avoided because plain dotted selectors are the standard project convention.

## Exit code contract

| Code | Meaning |
| ---: | ------- |
| 0 | Value found or mutation completed |
| 1 | Missing file, selector, value, or required option |
| 2 | Parser, dependency, or backend error |

Stdout is only for real values. Missing keys do not print fallback values unless `--print-fallback` is explicitly used.

## Reading TOML

Example config:

```toml
[theme]
name = "dracula"
accent = "orange"

[polybar]
enabled = true
font_size = 12

[lpack]
exclude = ["node_modules", "dist", ".git"]
```

Read a scalar value:

```bash
name="$(dnb_config_get --file "config.toml" "theme.name")" || {
  printf 'theme.name is required\n' >&2
  return 1
}

printf 'Theme: %s\n' "${name}"
```

Read a boolean:

```bash
if enabled="$(dnb_config_get --file "config.toml" "polybar.enabled")"; then
  if [[ "${enabled}" == "true" ]]; then
    printf 'Polybar is enabled\n'
  fi
fi
```

Read an array:

```bash
mapfile -t excludes < <(dnb_config_get --file "config.toml" "lpack.exclude") || {
  printf 'No lpack excludes configured\n' >&2
}

for item in "${excludes[@]}"; do
  printf 'Exclude: %s\n' "${item}"
done
```

List TOML keys:

```bash
dnb_config_list_keys --file "config.toml"
```

## Reading YAML

Example config:

```yaml
theme:
  name: dracula
  accent: orange
polybar:
  enabled: true
  font_size: 12
```

Read a value:

```bash
font_size="$(dnb_config_get --file "config.yaml" "polybar.font_size")" || {
  printf 'polybar.font_size is required\n' >&2
  return 1
}

printf 'Font size: %s\n' "${font_size}"
```

Selectors may be plain dotted paths or native dasel selectors:

```bash
dnb_config_get --file "config.yaml" "polybar.font_size"
dnb_config_get --file "config.yaml" ".polybar.font_size"
```

## Writing values

Set a string value:

```bash
dnb_config_set \
  --file "config.toml" \
  --selector "theme.name" \
  --type string \
  --value "dracula"
```

Set a boolean value:

```bash
dnb_config_set \
  --file "config.yaml" \
  --selector "polybar.enabled" \
  --type bool \
  --value true
```

Set a number:

```bash
dnb_config_set \
  --file "config.toml" \
  --selector "polybar.font_size" \
  --type int \
  --value 12
```

Set JSON-compatible structured data when the backend supports it:

```bash
dnb_config_set \
  --file "config.yaml" \
  --selector "lpack.exclude" \
  --type json \
  --value '["node_modules", "dist", ".git"]'
```

## Deleting values

```bash
dnb_config_delete \
  --file "config.toml" \
  --selector "deprecated.option"
```

Use this for migration helpers that remove old keys after moving settings to a new structure.

## Checking whether a key exists

```bash
if dnb_config_has --file "config.toml" "theme.name"; then
  printf 'theme.name exists\n'
else
  printf 'theme.name is missing\n' >&2
fi
```

## Strict non-empty reads

Use `--trim-values` and `--fail-on-empty` for required human-entered strings:

```bash
display_name="$(
  dnb_config_get \
    --file "config.toml" \
    "launcher.name" \
    --trim-values \
    --fail-on-empty
)" || {
  printf 'launcher.name must be set and non-empty\n' >&2
  return 1
}
```

## Explicit fallback mode

Fallback output is allowed only where legacy callers require it. It is lossy because the fallback value may be valid data.

```bash
value="$(dnb_config_get --file "config.toml" "missing.key" --print-fallback false)"
```

New scripts SHOULD avoid this pattern and SHOULD use exit codes instead.

## Recommended helper pattern

```bash
#!/bin/bash
# shellcheck shell=bash

set -euo pipefail

source_config_libs() {
  local base_path="${BASHRC_PATH:-}"

  if [[ -z "${base_path}" ]]; then
    base_path="${HOME}/.dotfiles/bashrc"
  fi

  local file=''
  for file in "${base_path}"/lib/*/*.bash; do
    # shellcheck disable=SC1090
    [[ -f "${file}" && -r "${file}" ]] && source "${file}"
  done
}

main() {
  source_config_libs

  local config_file="${HOME}/.dotfiles/configs/system/config.toml"
  local theme_name=''

  theme_name="$(dnb_config_get --file "${config_file}" "theme.name")" || {
    printf 'theme.name is missing in %s\n' "${config_file}" >&2
    return 1
  }

  printf 'Theme: %s\n' "${theme_name}"
}

main "$@"
```

## When not to use these helpers

Do not use these helpers for large data transformations, schema validation, or comment-preserving rewrites.

For comment-preserving or schema-heavy work, use a dedicated script instead:

* YAML: Node package `yaml`.
* TOML: Python `tomlkit`.
* Strict schema validation: Zod in TypeScript tooling.

## Migration rule

When touching an old helper that manually parses config files:

1. Replace manual parsing with `dnb_config_get`, `dnb_config_set`, or `dnb_config_delete`.
2. Preserve the existing exit-code behaviour where callers rely on it.
3. Add or update documentation with at least one read example and one failure example.
4. Prefer TOML for project-owned config files unless a target tool already requires YAML.
