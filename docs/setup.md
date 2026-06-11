# Setup notes

* [Installation](#installation)
* [Shell actor environment variables](#shell-actor-environment-variables)
* [Update](#update)
* [Automatic functionality after setup](#automatic-functionality-after-setup)
  * [Installed programs and systems](#installed-programs-and-systems)
  * [Shortcuts/Keybindings](#shortcutskeybindings)
    * [Custom shortcuts that are set up (work in progress)](#custom-shortcuts-that-are-set-up-work-in-progress)
* [Installation notes for programs](#installation-notes-for-programs)
  * [Communication tools](#communication-tools)
    * [Discord](#discord)
  * [Productivity tools](#productivity-tools)
    * [Todoist](#todoist)

## Installation

* Setup GitHub folder

  ```bash
  mkdir -p ~/github.com/davidsneighbour
  ```

* Install nvm and set to use required Node.js version (currently 24, see `.nvmrc`, for the latest script [check the repository](https://github.com/nvm-sh/nvm#install--update-script)).

   ```bash
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
   source ~/.bashrc
   nvm install 24
   nvm use 24
   ```

* Install [git](https://git-scm.com/downloads) if not already installed.

   ```bash
   sudo apt install git
   ```

* Clone this repository with submodules (this might be complicated, because the SSH key needs to be set up first).

   ```bash
   git clone --recurse-submodules git@github.com:davidsneighbour/dotfiles.git
   ```

* Install dependencies with `npm install`.

   ```bash
   npm install
   ```

* Run `sudo ./dotbot.sh setup` to install system-level packages and dependencies.

   ```bash
   sudo ./dotbot.sh setup
   ```

   > [!WARNING]
   > This MUST run with `sudo`, so make sure to check the `configs/dotbot/config.setup.yaml` file and adjust depending on the requirements.

* Run `./dotbot.sh` to set up symlinks and `./dotbot.sh protected` to set up protected symlinks.

   ```bash
   ./dotbot.sh
   ./dotbot.sh protected
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

Keybindings are managed via `actions` → `keybindings` scope. Run `actions menu` and select the keybindings scope to export or import the current Cinnamon keybinding configuration.

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

### Communication tools

#### Discord

Install the Flatpak version instead of the snap or deb version. The deb version requires manual installation of a downloaded `.deb` file to update the app.

### Productivity tools

#### Todoist

> [!WARNING]
> Don't try to get fancy. Use Chrome and set up as Chrome app. Their "app" works only on Gnome.
