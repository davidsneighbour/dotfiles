# AGENTS.md (bashrc/workspaces)

Scope: this directory tree.

## Extension rules

* Keep commands CLI-first. Do not add TUI dependencies.
* Prefer adding/maintaining commands in the `ws_*` namespace.
* Keep backwards compatibility by using wrappers if renaming commands.
* Every user-facing command must support:
  * `--help`
  * `--verbose`
  * `--quiet`
* Respect global verbosity contract via `DNB_VERBOSE`.
* Use `bashrc/workspaces/ws-common.sh` for logging setup when possible.
* Keep logs under `~/.logs/workspaces/<command>/YYYYMMDD-HHMMSS.log`.
* Do not remove existing comments.
* Prefer explicit named flags; avoid positional-only APIs.

## Config and schema

* Keep `config.toml` and `config.schema.json` aligned.
* Tile templates must include width/height/anchor/position fields.
* Workspace titles are required.
