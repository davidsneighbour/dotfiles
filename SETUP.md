# Setup Notes

* [Installation](#installation)
* [Update](#update)
* [Automatic functionality after setup](#automatic-functionality-after-setup)
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
    * [Joplin](#joplin)

## Installation

1. Install nvm and set to use required Node.js version (currently 24, see `.nvmrc`, for the latest script [check the repository](https://github.com/nvm-sh/nvm#install--update-script)).

   ```bash
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
   source ~/.bashrc
   nvm install 24
   nvm use 24
   ```

2. Install [git](https://git-scm.com/downloads) if not already installed.

   ```bash
   sudo apt install git
   ```

3. Clone this repository with submodules (this might be complicated, because the SSH key needs to be set up first).

   ```bash
   git clone --recurse-submodules git@github.com:davidsneighbour/dotfiles.git
   ```

4. Clone the `protected` repository into `protected/`.
5. Install dependencies with `npm install`.

   ```bash
   npm install
   ```

6. Run `./dotbot.sh install` to set up the environment.

   ```bash
   ./dotbot.sh install
   ```

7. Run `./dotbot.sh` to setup all symlinks and `./dotbot.sh protected` to setup the protected symlinks.

   ```bash
   ./dotbot.sh
   ./dotbot.sh protected
   ```

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

### Shortcuts/Keybindings

#### Import/Export Shortcuts

~~Dotfiles set up adds a cronjob that exports the keybindings at 6pm daily to `etc/keybindings.csv`. This file is imported when running dotbot.sh.~~

#### Custom Shortcuts that are set up (work in progress)

| key binding | function |
| ---: | --- |
| SUPER+A | open Alan |
| SUPER+W | open VSCode workspace selection, keep single window |
| SUPER+E | open VSCode workspace selection, add new window |
| SUPER+N | open Netflix |
| SUPER+C | open Chrome user profile selection (or browser) |
| SUPER+T | open Terminal |
| SUPER+F | open file manager in Home directory |
| SUPER+S | open Spotify |
| SUPER+SHIFT+S | open Sublime Text |
| SUPER+Q | open Todoist |
| SUPER+J | open Joplin |

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

#### Joplin

The recommended way to install Joplin on Linux is to use the script provided by the Joplin team. This script will handle the installation and future updates. For possible options, like install path, [see the script itself](https://github.com/laurent22/joplin/blob/dev/Joplin_install_and_update.sh#L50):

```bash
wget -O - https://raw.githubusercontent.com/laurent22/joplin/dev/Joplin_install_and_update.sh | bash
```

> [!NOTE]
> to myself: data is stored in Onedrive
