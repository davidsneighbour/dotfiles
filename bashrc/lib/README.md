# DNB Bash library

## Purpose

`_lib` contains source-safe reusable functions for Bash scripts.

## Rules

* Public reusable functions use the `dnb_*` prefix.
* Internal helpers use the `__dnb_*` prefix.
* Files in `_lib` must only define functions and constants.
* Files in `_lib` must not execute logic on source.
* Library functions should `return`, not `exit`.
* Standalone command tools belong in `bashrc/helpers`.
* Deprecated compatibility wrappers live in `_lib/90-compat/`.

## Loader snippet

```bash
for FILE in "${BASHRC_PATH}"/_lib/*/*.bash; do
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
* `dnb_error`
* `dnb_load_env`
* `dnb_path_contains`
* `dnb_path_add_if_missing`
* `dnb_path_sanitise`
* `dnb_config_get`
* `dnb_repo_config_get`
* `dnb_create_directory`
* `dnb_execute_lines`
* `dnb_archive_create`
* `dnb_archive_extract`

## Deprecated

Release-related helpers from the old `_lib` have been deprecated and replaced with warning wrappers. They should be removed from callers and replaced by workflow-specific scripts or standalone helpers.
