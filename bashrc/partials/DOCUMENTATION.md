# bashrc/partials documentation

`bashrc/partials` contains shell definitions that are sourced by `bashrc/bashrc` during interactive Bash startup. These files intentionally modify the current shell by defining aliases, functions, completions, exports, and prompt behaviour.

The implementation is authoritative. This document records the files that are loaded, what they define, and the external commands required for the definitions to be useful.

## Loader files

### `aliases`

Sources every readable file in `_aliases/` through `dnb_auto_source`, then defines general aliases.

Documented in more detail: [`_aliases/DOCUMENTATION.md`](./_aliases/DOCUMENTATION.md).

Notable aliases and requirements:

* `reload` — sources `~/.bashrc`; requires Bash.
* `cd` — aliases to the `change_directory` Bash function; requires `_functions/change_directory` to be loaded.
* `d` — prints `date +%Y%m%d%H%M`; requires GNU/coreutils `date`.
* `grep`, `fgrep`, `egrep`, `igrep`, `rgrep` — colour or recursive grep shortcuts; require `grep`.
* `l`, `la`, `lla`, `lt`, `ll`, `lu`, `lal`, `dir`, `ldir` — `eza` listing shortcuts; require `eza`.
* `alert` — desktop notification for the previous command; requires `notify-send`, `history`, `tail`, and `sed`.
* `less` — uses `less -iMF`; requires `less`.
* `h` — `history` shortcut; built into Bash.
* `r` — `fc -s` repeat shortcut; built into Bash.
* `ftail`, `syslog`, `tail` — tailing helpers; require `tail`, with `syslog` also requiring `ccze` and `tail` requiring `grc`.
* `scp` — disables strict host checking and compression for `scp`; requires OpenSSH `scp`.
* `fullps` — wide process listing; requires `ps`.
* `functions` — prints declared function names; requires Bash `declare`.
* `jobls`, `jobll`, `jobstart`, `jobhold`, `jobice`, `jobkill`, `joboffhold`, `joboffice`, `jobhist`, `jobdepends`, `jobsu`, `jobterm` — AutoSys aliases; require AutoSys commands such as `autorep`, `sendevent`, `jobrunhist`, and `job_depends`.
* `countfiles` — counts visible and hidden entries with `lsd`; requires `lsd` and `wc`.
* `subl` — opens Sublime Text with `subl -a`; requires Sublime Text CLI.
* `lasttag` — prints the most recent Git tag reachable through `git rev-list`; requires `git`.
* Uppercase HTTP method aliases `GET`, `HEAD`, `POST`, `PUT`, `DELETE`, `TRACE`, `OPTIONS` — use `lwp-request`; require Perl libwww tools.
* `sudo` — keeps aliases available after `sudo`; requires `sudo`.
* `npm-check-updates` — runs `ncu --format group --interactive`; requires global `npm-check-updates` (`npm install --global npm-check-updates`).
* `git-orphan` — creates an orphan branch named `NEWBRANCH` and removes tracked files; requires `git`.
* `vlc-pause`, `vlc-next`, `vlc-prev`, `vlc-play`, `vlc-stop` — control VLC over D-Bus; require `dbus-send` and VLC exposing `org.mpris.MediaPlayer2.vlc`.
* `cal` — maps to `ncal`; requires `ncal`.
* `check-network` — scans the local network with `sudo arp-scan --localnet --numeric --quiet --ignoredups`; requires `arp-scan` and `sudo`.
* `pi-shutdown`, `pi-reboot` — run shutdown commands over SSH against `${PI_SERVER}`; require `ssh` and sudo rights on the Raspberry Pi.
* `py-activate` — creates and activates `.env`; requires Python venv support (`python -m venv`).

Exports:

* `LS_COLORS` — colour mapping for GNU tools.
* `PI_SERVER` — defaults Raspberry Pi aliases to `raspberrypi.local`.

### `functions`

Sources every readable file in `_functions/` through `dnb_auto_source`.

Documented in more detail: [`_functions/DOCUMENTATION.md`](./_functions/DOCUMENTATION.md).

### `exports`

Exports interactive environment defaults:

* Colour-related variables: `GCC_COLORS`, `TERM`, `GREP_OPTIONS`, `GREP_COLOR`, `CLICOLOR`, `LSCOLORS`, and `COLOR_*` escape sequences.
* Editor defaults: `VISUAL=/usr/bin/vim.basic` and `EDITOR=/usr/bin/vim.basic`; require that Vim binary to exist for editor integrations.
* Homebrew behaviour: `HOMEBREW_NO_ENV_HINTS=1` and `HOMEBREW_NO_ANALYTICS=1`.
* Dotfiles setup state: `DOTFILES_SETUPDIR=${DOTFILES_PATH}/setup` and `DOTFILES_GUM=true|false` depending on whether `gum` is installed.
* Actor identity: `HUMAN=true` and `LLM=false` by default, unless `LLM=true` or `HUMAN=false` is already exported before startup.
* Vale styles path: `VALE_STYLES_PATH=${HOME}/.config/vale/styles`; requires Vale only when Vale is used.

### `completions`

Loads completion definitions from `_completions/`, bash-completion system files, Google Cloud SDK completion files, autojump completion, and selected static `complete` rules.

Documented in more detail: [`_completions/DOCUMENTATION.md`](./_completions/DOCUMENTATION.md).

### `prompt`

Configures colour support for prompt-adjacent tools. It checks `tput`, enables colour aliases for `ls`, `dir`, `vdir`, `grep`, `fgrep`, and `egrep` when `dircolors` is available, and exports `GCC_COLORS`.

Requirements: Bash, `tput`, `dircolors`, and GNU colour-capable coreutils/grep for the aliases to be effective.

## Program initialisation partials

Program startup snippets live in `_programs/` and are documented in [`_programs/DOCUMENTATION.md`](./_programs/DOCUMENTATION.md). They are not explicitly sourced by the current `bashrc/bashrc` loader because the loader sources named files in `partials/`, not arbitrary files in `_programs/`.
