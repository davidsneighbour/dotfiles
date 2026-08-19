# Bashrc/installs documentation

This folder contains installation snippets for a Linux Mint/Ubuntu-style workstation. Most files are direct provisioning scripts, not general-purpose CLIs, and many require `sudo` and network access.

## `10-system.sh`

Adds LibreOffice, Papirus, and OpenShot PPAs, then runs `apt update`, `apt upgrade`, `apt dist-upgrade`, `apt autoremove`, and `apt clean`.

Requirements: Ubuntu-compatible `apt`, `add-apt-repository`, `sudo`, and network access.

## `20-brew.sh`

Installs or bootstraps Homebrew/Linuxbrew according to the commands in the file.

Requirements: Bash, network access, and Homebrew's documented prerequisites.

## `20-cargo.sh`

Installs Rust/Cargo by downloading `https://sh.rustup.rs` to a temp file and
running it explicitly via `bashrc/helpers/fetch-and-run.sh`, instead of
piping curl directly into a shell. Rustup does not publish a checksum for
this installer, so no `--sha256` is passed.

Requirements: Bash, network access, and the Rust installer prerequisites.

## `50-atuin.sh`

Installs Atuin by downloading `https://setup.atuin.sh` to a temp file and
running it explicitly via `bashrc/helpers/fetch-and-run.sh`, instead of
piping curl directly into a shell. Atuin does not publish a checksum for
this installer, so no `--sha256` is passed.

Requirements: `curl`, `sh`, TLS/network access.

## `50-chrome.sh`

Installs Google Chrome according to the apt repository/package commands in the file.

Requirements: `wget`/`curl` or apt key tooling as implemented, `apt`, `sudo`, and network access.

## `50-github.sh`

Configures the GitHub CLI apt repository and installs `gh`.

Requirements: `curl`, `gpg`, `dpkg`, `apt`, `sudo`, and network access.

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

Requirements: Bash, network access, and Ollama installer prerequisites.

## `50-signal.sh`

Adds the Signal Desktop apt key/repository and installs Signal Desktop.

Requirements: `wget`, `gpg`, `apt`, `sudo`, and network access.

## `50-sublime.sh`

Installs Sublime Text according to the apt repository/package commands in the file.

Requirements: apt repository tooling, `apt`, `sudo`, and network access.

## `50.gum.sh`

Adds Charm's apt repository key and installs `gum`.

Requirements: `curl`, `gpg`, `apt`, `sudo`, and network access.

## `90-brew-packages.sh`

Installs Homebrew packages listed in the script.

Requirements: Homebrew/Linuxbrew (`brew`) and network access.

## `90-cargo-packages.sh`

Installs Cargo packages listed in the script.

Requirements: Rust/Cargo (`cargo`) and network access.
