# bashrc/partials/_completions documentation

Files in this folder provide Bash programmable completion definitions. They are sourced by `partials/completions` when readable.

## Loader behaviour in `partials/completions`

The loader:

* Sources each readable file in `_completions/`.
* Sources `/usr/share/bash-completion/bash_completion` or `/etc/bash_completion` when Bash is not in POSIX mode.
* Sources Google Cloud SDK `path.bash.inc` and `completion.bash.inc` from `${HOME}/.bin/google-cloud-sdk/` when present.
* Sources `/usr/share/autojump/autojump.bash` when present.
* Initialises Grunt completion with `grunt --completion=bash` when `grunt` exists.
* Defines static `complete` rules for commands such as `ssh`, `export`, `alias`, `cd`, archive tools, TeX tools, image/media tools, and Perl.
* Defines `_ssh_hosts_completion`, which completes `ssh` hosts from `${HOME}/.ssh/config` and `${HOME}/.ssh/config.d/*` Host entries, excluding wildcard hosts.

Requirements: Bash completion support. Optional integrations require Google Cloud SDK, autojump, Grunt, and readable SSH config files.

## Completion files

### `bootstrap`

Completion for a `bootstrap` command. It offers project/setup-style flags according to the file's completion candidates.

Requirements: Bash completion and the corresponding `bootstrap` command for runtime use.

### `caniuse`

Completion for `caniuse`.

Requirements: Bash completion and `caniuse-cmd`/`caniuse` where used (commonly installed via npm globally).

### `codex`

Large generated/static completion definition for the `codex` CLI.

Requirements: Bash completion and the `codex` CLI.

### `gh`

Completion for the GitHub CLI (`gh`).

Requirements: Bash completion and `gh`.

### `gohugo`

Completion for Hugo-related commands.

Requirements: Bash completion and Hugo (`hugo`) where used.

### `netlify`

Completion for Netlify CLI.

Requirements: Bash completion and Netlify CLI, typically `npm install --global netlify-cli`.

### `npm`

Completion for npm commands.

Requirements: Bash completion and `npm`.

### `robo`

Completion for Robo task runner commands.

Requirements: Bash completion and the `robo` CLI.

### `wp`

Completion for WP-CLI.

Requirements: Bash completion and `wp` (`wp-cli`).
