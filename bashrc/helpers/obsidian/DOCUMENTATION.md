# `obsidian/` documentation

This file documents the functionality present in `bashrc/helpers/obsidian`.
Parent index: [`bashrc/helpers/INDEX.md`](../INDEX.md).

## Files

### `obsidian/start-memory.sh`

Opens the Obsidian memory vault folder and the memory repository in VS Code on the notes workspace.

CLI option notes:

* `--verbose` — print launch commands and workspace helper logs.
* `--help` — show help.

Functions/methods defined:

* `usage`
* `die`
* `logv`
* `need_cmd`
* `quote_shell_word`
* `url_encode`
* `launch_on_memory_workspace`
* `main`

Requirements:

* `bash`, `wmctrl`, `obsidian`, `code`.
