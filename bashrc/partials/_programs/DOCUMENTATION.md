# bashrc/partials/_programs documentation

This folder contains program initialisation snippets. They are Bash shell-definition snippets, not standalone commands.

Important implementation note: the current `bashrc/bashrc` file sources explicitly named files in `partials/` (`bash`, `functions`, `exports`, `aliases`, `completions`, and `prompt`). It does not currently source every file in `partials/_programs/`. These snippets document available startup fragments, not active startup behaviour unless another loader sources them.

## `100-brew.sh`

Runs Homebrew's `brew shellenv bash` and evaluates the output.

Requirements: Linuxbrew/Homebrew installed at `/home/linuxbrew/.linuxbrew/bin/brew`.

## `110-nvm.sh`

Exports `NVM_DIR=${HOME}/.nvm`, sources `${NVM_DIR}/nvm.sh` when present, sources NVM Bash completion in interactive shells, and runs `nvm use --silent` in interactive shells when `nvm` is available.

Requirements: `nvm` installed under `${HOME}/.nvm`. Optional completion requires `${NVM_DIR}/bash_completion`.

## `900-gpg-on-console.sh`

In interactive shells, exports `GPG_TTY=$(tty)` and runs `gpg-connect-agent updatestartuptty /bye`.

Requirements: `tty`, GnuPG agent tools, and a running/launchable GPG agent.
