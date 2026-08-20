# `bashrc/partials/_programs` documentation

This folder contains program initialisation snippets. They are Bash shell-definition snippets, not standalone commands.

`bashrc/bashrc` sources every file in this directory (`partials/_programs/*`) near the end of interactive shell startup, after the named `partials/{functions,exports,aliases,completions,prompt,topical}` files.

## `100-brew.sh`

Runs Homebrew's `brew shellenv bash` and evaluates the output.

Requirements: Linuxbrew/Homebrew installed at `/home/linuxbrew/.linuxbrew/bin/brew`.

## `110-nvm.sh`

Exports `NVM_DIR=${HOME}/.nvm`, sources `${NVM_DIR}/nvm.sh` when present, sources NVM Bash completion in interactive shells, and runs `nvm use --silent` in interactive shells when `nvm` is available.

Requirements: `nvm` installed under `${HOME}/.nvm`. Optional completion requires `${NVM_DIR}/bash_completion`.
