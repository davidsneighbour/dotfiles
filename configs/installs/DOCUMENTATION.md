# Bashrc/installs documentation

This folder contains installation scripts for a Linux Mint/Ubuntu-style workstation, run directly (e.g. `bash configs/installs/10-system.sh`). Most support `--help`, `--verbose` (traces each command via `set -x`), and `--dry-run` (prints the steps it would take without changing anything); scripts that don't are noted below. Many require `sudo` and network access.

## `10-system.sh`

Adds LibreOffice, Papirus, and OpenShot PPAs, then runs `apt update`, `apt upgrade`, `apt dist-upgrade`, `apt autoremove`, `apt clean`, installs the base workstation package set, installs the `vale` snap, and copies the `git-extras` Bash completion into this repo.

Options: `--verbose`, `--dry-run`, `--help`.

Requirements: Ubuntu-compatible `apt`, `add-apt-repository`, `sudo`, and network access.

## `20-brew.sh`

Installs Homebrew/Linuxbrew non-interactively, then installs `dotbot` (required before running `dotfiles`).

Options: `--verbose`, `--dry-run`, `--help`.

Requirements: Bash, network access, and Homebrew's documented prerequisites.

## `20-cargo.sh`

Installs Rust/Cargo by downloading `https://sh.rustup.rs` to a temp file and
running it explicitly via `bashrc/helpers/fetch-and-run.sh`, instead of
piping curl directly into a shell. Rustup does not publish a checksum for
this installer, so no `--sha256` is passed.

Options: forwards all arguments to `fetch-and-run.sh` (`--verbose`, `--dry-run`, `--help`, `--sha256`, `--interpreter`).

Requirements: Bash, network access, and the Rust installer prerequisites.

## `50-atuin.sh`

Installs Atuin by downloading `https://setup.atuin.sh` to a temp file and
running it explicitly via `bashrc/helpers/fetch-and-run.sh`, instead of
piping curl directly into a shell. Atuin does not publish a checksum for
this installer, so no `--sha256` is passed.

Options: forwards all arguments to `fetch-and-run.sh` (`--verbose`, `--dry-run`, `--help`, `--sha256`, `--interpreter`).

Requirements: `curl`, `sh`, TLS/network access.

## `50-chrome.sh`

Downloads the latest Google Chrome stable `.deb` to a temp file and installs it with `dpkg`.

Options: `--verbose`, `--dry-run`, `--help`.

Requirements: `wget`, `dpkg`, `apt`, `sudo`, and network access.

## `50-github.sh`

Configures the GitHub CLI apt repository and installs `gh`.

Options: `--verbose`, `--dry-run`, `--help`.

Requirements: `wget`, `gpg`, `dpkg`, `apt`, `sudo`, and network access.

## `50-obsidian.sh`

Downloads the latest Obsidian `.deb` from GitHub releases and optionally installs it with `dpkg`.

Options:

* `--download-dir=PATH` — directory for the downloaded `.deb`; defaults to the script's `DOWNLOAD_DIR`.
* `--no-install` — download only; do not run `dpkg`.
* `--keep` — keep the downloaded file after successful install.
* `-v` — verbose output.
* `-vv` — more verbose output.
* `-q` — quiet output.
* `--help` — show help.

Requirements: Bash, `curl`, `dpkg` for installation, optional `jq` for release JSON parsing, and optional `GITHUB_TOKEN` for authenticated GitHub API requests.

## `50-ollama.sh`

Installs Ollama by downloading `https://ollama.com/install.sh` to a temp
file and running it explicitly via `bashrc/helpers/fetch-and-run.sh`,
instead of piping curl directly into a shell. Ollama does not publish a
checksum for this installer, so no `--sha256` is passed.

Options: forwards all arguments to `fetch-and-run.sh` (`--verbose`, `--dry-run`, `--help`, `--sha256`, `--interpreter`).

Requirements: Bash, network access, and Ollama installer prerequisites.

## `50-signal.sh`

Adds the Signal Desktop apt key/repository and installs Signal Desktop.

Options: `--verbose`, `--dry-run`, `--help`.

Requirements: `wget`, `gpg`, `apt`, `sudo`, and network access.

## `50-sublime.sh`

Adds the Sublime HQ apt repository and installs Sublime Text and Sublime Merge.

Options: `--verbose`, `--dry-run`, `--help`.

Requirements: `wget`, `apt-get`, `sudo`, and network access.

## `50.gum.sh`

Adds Charm's apt repository key and installs `gum`.

Options: `--verbose`, `--dry-run`, `--help`.

Requirements: `curl`, `gpg`, `apt`, `sudo`, and network access.

## `90-brew-packages.sh`

Taps `dart-lang/dart` and installs the shared Homebrew CLI tool set.

Options: `--verbose`, `--dry-run`, `--help`.

Requirements: Homebrew/Linuxbrew (`brew`) and network access.

## `90-cargo-packages.sh`

Installs eww's apt build dependencies, clones (if missing) and builds eww from source with cargo, and installs the release binary to `~/.local/bin`.

Options: `--verbose`, `--dry-run`, `--help`.

Requirements: `apt`, `sudo`, `git`, Rust/Cargo (`cargo`), and network access.
