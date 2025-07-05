Work in progress... to be written.

# Initial setup of OS

## Quick setup

1. Install nvm and set to use required Node.js version (currently 24, see `.nvmrc`, for the latest script [check the repository](https://github.com/nvm-sh/nvm#install--update-script)).
   ```bash
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
   source ~/.bashrc
   nvm install 24
   nvm use 24
   ```
1. Install [git](https://git-scm.com/downloads) if not already installed.
   ```bash
   sudo apt install git
   ```
1. Clone this repository with submodules (this might be complicated, because the SSH key needs to be set up first).
   ```bash
   git clone --recurse-submodules git@github.com:davidsneighbour/dotfiles.git
   ```
1. Clone the `protected` repository into `protected/`.
1. Install dependencies with `npm install`.
   ```bash
   npm install
   ```
1. Run `./dotbot.sh install` to set up the environment.
   ```bash
   ./dotbot.sh install
   ```
1. Run `./dotbot.sh` to setup all symlinks and `./dotbot.sh protected` to setup the protected symlinks.
   ```bash
   ./dotbot.sh
   ./dotbot.sh protected
   ```

# Automatic functionality after setup

## Shortcuts/Keybindings

### Import/Export Shortcuts

~~Dotfiles set up adds a cronjob that exports the keybindings at 6pm daily to `etc/keybindings.csv`. This file is imported when running dotbot.sh.~~

### Custom Shortcuts that are set up (work in progress)

| key binding | command | notes |
|-------------|---------|-------|
| SUPER+R     | `rofi -show run` | |
| SUPER+W     | `vscode workspaces` | |
| SUPER+E     | `vscode workspaces` | like SUPER+W but doesn't take over the already open VSCode window(s) |
| SUPER+N | | open Netflix |
| SUPER+C | | open Chrome user profile selection (or browser) |
| SUPER+T | | open Terminal |
| SUPER+F | | open file manager in Home directory |
| SUPER+S | | open Spotify |
| SUPER+Q | | open Todoist |
| SUPER+J | | open Joplin |

# Manual installations after setup

## Productivity tools

### Todoist

> [!NOTE]
> Don't try to get fancy. Use Chrome and set up as Chrome app. Their "app" works only on Gnome.

### Joplin

The recommended way to install Joplin on Linux is to use the script provided by the Joplin team. This script will handle the installation and future updates. For possible options, like install path, [see the script itself](https://github.com/laurent22/joplin/blob/dev/Joplin_install_and_update.sh#L50):

```bash
wget -O - https://raw.githubusercontent.com/laurent22/joplin/dev/Joplin_install_and_update.sh | bash
```

> [!NOTE]
> to myself: data is stored in Onedrive

# Update

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
