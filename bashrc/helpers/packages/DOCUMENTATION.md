# `packages/` documentation

This file documents every file currently present in `bashrc/helpers/packages`.

Parent index: [`../INDEX.md`](../INDEX.md).

## Existing Markdown references

* [`README.md`](./README.md)

## Files

### `packages/README.md`

Existing guide for package archive helper configuration.

Documentation status: this is an existing Markdown document. The implementation-specific documentation below references it rather than duplicating all prose.

### `packages/create.sh`

Creates zip archives from line-oriented `[packages.NAME]` TOML sections.

CLI option notes:

* --package NAME — package section to archive.
* --config FILE — config file; repeatable.
* --output-dir DIR — destination for zip.
* --verbose — enable verbose logging and DNB_VERBOSE.
* --quiet — disable verbose.
* --list — list package names.
* --help — show help.

Functions/methods defined:

* `usage`
* `init_verbose_logging`
* `log_verbose`
* `print_error`
* `die`
* `hostname_lc`
* `default_config_file`
* `add_config_file`
* `load_env_config_files`
* `ensure_config_files`
* `list_packages`
* `package_exists`
* `resolve_package_path`
* `read_and_resolve_package_paths`
* `make_zip_name`
* `parse_args`
* `main`

Requirements:

* bash, zip, hostname, optional envsubst for non-HOME variable expansion.
