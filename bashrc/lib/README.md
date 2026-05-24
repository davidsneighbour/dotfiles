# DNB Bash library

## Purpose

`lib` contains source-safe reusable functions for Bash scripts.

## Rules

* Public reusable functions use the `dnb_*` prefix.
* Internal helpers use the `__dnb_*` prefix.
* Files in `lib` must only define functions and constants.
* Files in `lib` must not execute logic on source.
* Library functions should `return`, not `exit`.
* Standalone command tools belong in `bashrc/helpers`.

## Loader snippet

```bash
: "${BASHRC_PATH:?BASHRC_PATH must be set before loading Bash helper files}"
for FILE in "${BASHRC_PATH}"/lib/*/*.bash; do
  # shellcheck disable=SC1090
  [[ -f "${FILE}" && -r "${FILE}" ]] && source "${FILE}"
done
```

## Public API

* `dnb_auto_source`
* `dnb_is_interactive`
* `dnb_check_requirements`
* `dnb_log_init`
* `dnb_log`
* `dnb_load_env`
* `dnb_path_contains`
* `dnb_path_add_if_missing`
* `dnb_path_sanitise`
* `dnb_config_get`
* `dnb_config_set`
* `dnb_config_delete`
* `dnb_config_has`
* `dnb_config_list_keys`
* `dnb_repo_config_get`
* `dnb_create_directory`
* `dnb_execute_lines`
* `dnb_archive_create`
* `dnb_archive_extract`
* `getopts_long`

Config helper rules and examples are documented in [`../../docs/dnb-config.md`](../../docs/dnb-config.md).

## Add errors and warnings to polybar issue plugin

```bash
dnb_polybar_issue_add --id 1234 --prio 1 --label "issue with gmail" --description "longer description of the issue" --verbose
dnb_polybar_issue_add --id 1234 --label "issue with gmail"
```

* `id` must be unique, items with identical `id` will be updated
* `prio` is by default 1 (error), possible values are 1, 2, 3 (error, warning, note)
* `label` is required and a short notice about the issue
* `description` is markdown description, longtext possible

## Remove errors and warnings from polybar issue plugin

```bash
dnb_polybar_issue_remove --id 1234
```
