# Setup notes

* [Installation](#installation)
* [Update](#update)
* [Automatic functionality after setup](#automatic-functionality-after-setup)
  * [Installed programs and systems](#installed-programs-and-systems)
  * [Shortcuts/Keybindings](#shortcutskeybindings)
    * [Import/Export Shortcuts](#importexport-shortcuts)
    * [Custom Shortcuts that are set up (work in progress)](#custom-shortcuts-that-are-set-up-work-in-progress)
* [Installation notes for programs](#installation-notes-for-programs)
  * [Development tools](#development-tools)
  * [Communication tools](#communication-tools)
    * [Discord](#discord)
    * [Signal](#signal)
    * [Telegram](#telegram)
  * [Productivity tools](#productivity-tools)
    * [Dropbox](#dropbox)
    * [Todoist](#todoist)

## Installation

> [!NOTE]
> Steps 1–5 are bootstrapping prerequisites that must be completed before `dotfiles` can manage
> the environment. Once Homebrew and dotbot are installed and the repo is cloned, everything else
> is driven by `dotfiles [CONFIG_NAME]`.

* Set up the GitHub folder:

  ```bash
  mkdir -p ~/github.com/davidsneighbour
  ```

* Install [git](https://git-scm.com/downloads) if not already installed:

   ```bash
   sudo apt install git
   ```

* Clone this repository **with submodules** (SSH key must be set up first):

   ```bash
   git clone --recurse-submodules git@github.com:davidsneighbour/dotfiles.git ~/github.com/davidsneighbour/dotfiles
   cd ~/github.com/davidsneighbour/dotfiles
   ```

* Install [Homebrew](https://brew.sh) (Linuxbrew):

   ```bash
   bash configs/installs/20-brew.sh
   eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
   ```

* Install dotbot via Homebrew — **required before running `dotfiles`**:

   ```bash
   brew install dotbot
   ```

* Install Node.js dependencies:

   ```bash
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
   source ~/.bashrc
   nvm install 24
   nvm use 24
   npm install
   ```

* Run `dotfiles` to set up symlinks, tools, and host-specific config.
  The `dotfiles` command lives in `bashrc/helpers/dotfiles` and is added to PATH automatically
  once the bashrc symlink is in place. During the very first run, invoke it directly:

   ```bash
   bash bashrc/helpers/dotfiles
   ```

  For named configs (host-specific, AI tooling, protected symlinks, etc.):

   ```bash
   bash bashrc/helpers/dotfiles ai
   bash bashrc/helpers/dotfiles protected
   bash bashrc/helpers/dotfiles host-locutus
   ```

  After the initial run the symlink `~/.dotfiles → ~/github.com/davidsneighbour/dotfiles` and the
  sourced bashrc are in place, so subsequent runs use the short form:

   ```bash
   dotfiles
   dotfiles ai
   dotfiles protected
   ```

## Shell actor environment variables

The interactive Bash setup defines a mutually exclusive actor identity with two exported variables:

* `HUMAN` (default: `true`)
* `LLM` (default: `false`)

Rules enforced during Bash startup:

* If `LLM=true` is already set before loading Bash config, then `HUMAN=false`.
* If `HUMAN=false` is already set before loading Bash config, then `LLM=true`.
* If neither mode is explicitly set, Bash defaults to `HUMAN=true` and `LLM=false`.

For automation agents and LLM-based tooling: export `LLM=true` before sourcing `~/.bashrc` or before running commands that rely on this Bash configuration.

## Update

Run consecutive updates:

```bash
git pull
./dotbot.sh
./dotbot.sh protected
git submodule update --recursive --remote --merge --force
```

Updating dotbot submodules is a bit tricky and might not work all times. Running into issues don't waste time on solving it and run the following commands to reset the submodule and pull the latest changes:

```bash
cd broken-submodule-path
git merge --abort
git pull
git checkout main
```

## Automatic functionality after setup

### Installed programs and systems

* [nvm](https://github.com/nvm-sh/nvm), [Node.js](https://nodejs.org/en/), and [npm](https://www.npmjs.com/)
* [git](https://git-scm.com/)
* [Flatpak](https://flatpak.org/)

### Shortcuts/Keybindings

#### Import/Export shortcuts

~~Dotfiles set up adds a cronjob that exports the keybindings at 6pm daily to `etc/keybindings.csv`. This file is imported when running dotbot.sh.~~

#### Custom shortcuts that are set up (work in progress)

| key binding | function |
| ---: | --- |
| SUPER+A | open Alan |
| SUPER+W | open VSCode workspace selection, keep single window |
| SUPER+E | open VSCode workspace selection, add new window |
| SUPER+N | open Netflix |
| SUPER+C | open Chrome user profile selection (or browser) |
| SUPER+T | open Terminal |
| SUPER+F | open file manager in Home directory |
| SUPER+SHIFT+S | open Sublime Text |
| SUPER+Q | open Todoist |

## Installation notes for programs

### Development tools

### Communication tools

#### Discord

Install flatpak version instead of the snap or deb version. The deb version requires manual installation of a downloaded *.deb file to update the app.

#### Signal

#### Telegram

### Productivity tools

#### Dropbox

#### Todoist

> [!WARNING]
> Don't try to get fancy. Use Chrome and set up as Chrome app. Their "app" works only on Gnome.
