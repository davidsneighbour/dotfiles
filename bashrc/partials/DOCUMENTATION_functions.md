# Bashrc/partials/_functions documentation

Files in this folder are Bash functions sourced into the interactive shell by `partials/functions`. They may change shell state and are not standalone helper commands.

## `cdg`

Function: `cdg`.

Uses `bashrc/helpers/gh/cdg` to select or resolve a GitHub repository path, then changes the current shell directory to that path.

Options passed through to the helper:

* `--help` — show helper help.
* `--print-cd-command` — ask the helper for a shell command and `eval` it deliberately so the current shell changes directory.
* Other helper-supported options are delegated to `helpers/gh/cdg`.

Requirements: executable `bashrc/helpers/gh/cdg`, Bash, and the helper's requirements (`gh`, `gum`, GitHub authentication, and repository folders as documented in [`../helpers/gh/DOCUMENTATION.md`](../helpers/gh/DOCUMENTATION.md)).

## `change_directory`

Functions: `_cd_effective_nvmrc`, `_cd_maybe_use_nvm`, `_cd_maybe_show_git_status`, `change_directory`.

`change_directory` replaces `cd` through an alias. It runs `builtin cd`, switches Node with `nvm use --silent` when the effective `.nvmrc` changes, and prints `git status -sb` when the destination is a Git repository with local changes.

CLI/help option:

* `--help` — prints usage and explains the `.nvmrc` lookup order.

Requirements: Bash. Optional behaviour requires `nvm` and `git`.

## `codex`

Function: `codex-local`.

Runs `codex` against a configured Ollama-compatible endpoint after validating connectivity and the configured Codex profile.

Options:

* `--help` — show help.
* `--verbose` — print health-check and execution progress.
* Any other arguments are passed to `codex`.

Environment:

* `OLLAMA_HOST` — optional; defaults to `http://localhost:11434` and must include `http://` or `https://`.
* `CODEX_PROFILE` — optional; defaults to `ollama-launch`.

Requirements: `curl`, `codex`, reachable Ollama/OpenAI-compatible endpoint, and a matching profile in `${HOME}/.codex/config.toml`.

## `dotfiles`

Script: `bashrc/helpers/dotfiles`.

Runs a dotbot config from `configs/dotbot/`. Wraps the brew-installed `dotbot` binary with config-name resolution and optional interactive profile selection via `gum`.

Usage:

```bash
dotfiles [CONFIG_NAME]
dotfiles --config CONFIG_NAME
dotfiles --list
dotfiles --help
```

Options:

* `--config CONFIG_NAME` — run a specific config; `host-locutus` and `config.host-locutus.yaml` are equivalent.
* `--list` — pick a config interactively via `gum`.
* `-h`, `--help` — show help.

Default (no args): runs `configs/dotbot/config.yaml`.

Requirements: `dotbot` (installed via `brew install dotbot`), optionally `gum` for `--list`.

## `gh_repo_list`

Function: `gh_repos_list`.

Lists GitHub repositories using `gh repo list` and emits JSON Lines, JSON, or clone URLs.

Options:

* `--urls-only` — print one clone URL per line.
* `--format FORMAT` — `jsonl` or `json`; default `jsonl`.
* `--url-kind KIND` — URL kind for `--urls-only`: `ssh`, `https`, or `html`; default `ssh`.
* `--include-forks BOOL` — include forked repositories; `true` or `false`; default `true`.
* `--affiliation VALUE` — GitHub affiliation filter; default `owner`.
* `--include-archived true|false` — include archived repositories; default `true` according to the help text.
* `--help` — show help.

Requirements: GitHub CLI (`gh`) authenticated to GitHub and `jq` for output shaping.

## `git`

Functions: `_git_get_root`, `_git_find_commitlint_config`, `_git_has_commitlint_config`, `_git_should_use_cz`, and an overriding `git` function.

The `git` function delegates to the real `git` command except in a repository where a commitlint configuration is present and the command should use Commitizen. In that case it launches `cz` with Node transform-type flags. `git commit --retry` bypasses Commitizen and retries the previous Git commit.

Special option/command behaviour:

* `git commit --retry` — calls the real Git command directly.
* Other Git options and commands pass through to `command git` unless Commitizen should handle the commit.

Requirements: `git`. Commitizen mode additionally requires a commitlint config, `cz`, and Node support for the configured `NODE_OPTIONS`.

## `git-clone`

Function: `glone`.

Clones one repository from `--repo` or multiple repositories from stdin, normalising GitHub URLs and optionally entering or opening the cloned directory.

Options:

* `--repo VALUE` — repository location.
* `--force-https` — clone using HTTPS instead of SSH.
* `--go` — change into the cloned repository; only supported for a single repository.
* `--open` — open the cloned repository in VS Code; only supported for a single repository.
* `--verbose` — enable verbose output.
* `--quiet` — disable verbose output; overrides `--verbose` and `DNB_VERBOSE`.
* `--help` — show help.

Requirements: Bash, `git`, and network access to the repository host.

## `git_branch_creator`

Function: `who_created_branches`.

Fetches remote branches, computes their first commits after a base branch, and prints likely branch creators and latest commit dates.

Options:

* `--base REMOTE/BRANCH` — base branch for merge-base; default `origin/master`.
* `--verbose` — print extra debugging information.
* `--help` — show help.

Requirements: `git` and access to the `origin` remote.

## `github`

Currently contains only shellcheck metadata. It defines no functions.

## `github_feed_releases`

Function: `github_feed_releases`.

Builds a GitHub releases Atom feed URL from a repository argument and opens/prints it according to the function implementation.

Options:

* `--help` or no arguments — show usage.

Requirements: Bash and tools used by the implementation for URL handling/opening.

## `insert_first_line`

Function: `insert_first_line`.

Prepends a line to files under a directory when that line is not already the first line.

Options:

* `--string=TEXT` — required line to insert.
* `--dir=DIR` — directory to scan recursively; defaults to current directory.
* `--help` — show help.

Requirements: Bash and standard file utilities (`find`, `mktemp`, `head`, `cat`, `mv`).

## `keybindings`

Functions: `export_keybindings`, `import_keybindings`, `keybindingsmanager`, `generate_keybindings_page`.

Exports, imports, and renders Cinnamon/GNOME-style keybinding settings.

Options:

* `export_keybindings --help` — show export usage.
* `export_keybindings <filename>` — export keybindings to a file.
* `import_keybindings --help` — show import usage.
* `import_keybindings <filename>` — import keybindings from a file.
* `keybindingsmanager -e|--export <filename>` — export via manager.
* `keybindingsmanager -i|--import <filename>` — import via manager.
* `keybindingsmanager -h|--help` — show manager help.
* `generate_keybindings_page --file <csvfile> --output <htmlfile>` — create an HTML page from CSV.
* `generate_keybindings_page --help` — show render help.

Requirements: Bash, `dconf`/desktop settings tools used by the implementation, and file write permissions. HTML generation expects a readable CSV file.

## `searchfor`

Function: `searchfor`.

Searches a repository tree for a term while excluding noisy folders.

Options:

* `--path PATH` — override the search base path; default `${HOME}/github.com/davidsneighbour`.
* `--help` — show help.
* Positional `SEARCHTERM` — required search term.

Requirements: Bash and `grep`.

## `vscode`

Functions: `vscode_add_mcp`, `vscode_setup`, and an overriding `code` helper when defined by the file.

`vscode_add_mcp` adds or updates `.vscode/mcp.json` with a GitMCP server entry.

Options:

* `--key KEY` — server key to store under `.servers`.
* `--value URL` — server URL; a positional URL is also accepted.
* `--help` — show help.

`vscode_setup` creates/updates `.vscode/mcp.json` and `.github/copilot-instructions.md` for a repository.

Options:

* `--slug SLUG` — repository slug; can also come from `REPOSLUG` or `.env`.
* `--template TEMPLATE` — append one or more AI instruction templates when no slug-specific file exists.
* `--help` — show help.

`code` help:

* `--help` — show `Usage: code [file or directory]`.

Requirements: Bash, `git` for auto-detecting remotes, `jq` for JSON updates, and VS Code/Codium CLI where `code` is used.
