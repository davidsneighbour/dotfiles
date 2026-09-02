# `_actions/` documentation

This file documents every file currently present in `bashrc/helpers/_actions`.

Parent index: [`../INDEX.md`](../INDEX.md).

## Existing markdown references

* [`README.md`](./README.md)

## Files

### `_actions/README.md`

Existing user documentation for the actions helper; keep aligned with actions.sh.

Documentation status: this is an existing Markdown document. The implementation-specific documentation below references it rather than duplicating all prose.

### `_actions/actions.sh`

Unified Bash helper for actions and Dotbot profile discovery/execution.

CLI option notes:

* --verbose — enables debug output.
* --dry-run — prints planned filesystem/command changes without executing them.
* --help — prints top-level help.
* menu --config FILE — uses a custom actions TOML file.
* dotbot-list --configs-dir DIR — directory holding Dotbot config files.
* dotbot-run --configs-dir DIR — directory holding Dotbot config files.
* dotbot-run --profile NAME — Dotbot profile label to run.

Functions/methods defined:

* `source_core_libs`
* `init_logging`
* `log_msg`
* `log_debug`
* `log_error`
* `print_help`
* `require_cmd`
* `menu_py_toml`
* `colorize_expanded`
* `menu_choose_scope`
* `menu_choose_activity`
* `menu_extract_id`
* `menu_run_activity`
* `handle_menu`
* `extract_dotbot_description`
* `list_dotbot_profiles`
* `handle_dotbot_list`
* `handle_dotbot_run`
* `main`

Requirements:

* bash, gum, python3 with tomllib or tomli for menu parsing.
* Dotbot commands require dotbot and configs/dotbot.
