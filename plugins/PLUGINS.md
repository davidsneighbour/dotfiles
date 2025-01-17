# Plugin System for Dotfiles

This document provides an overview of the plugin system used in this dotfiles repository, including how to add, update, and remove plugins, as well as an introduction to the `plugins-loader.sh` script.

## Overview

The plugin system organizes reusable scripts and configurations as modular Git repositories. Each plugin is integrated into the dotfiles repository using **Git Subtree**, ensuring easy version control and updates. Plugins are stored in the `plugins/` directory, with each plugin following a consistent naming convention and structure.

## Plugin Naming Convention

Plugins follow the naming convention: `dotfiles-plugin-{tool}-{script-name}`

* **`dotfiles-plugin`**: Indicates the repository is a plugin for the dotfiles system.
* **`{tool}`**: Specifies the primary tool or language used (e.g., `bash`, `node`, `python`).
* **`{script-name}`**: Reflects the purpose or functionality of the plugin.

### Example Plugin Names

* `dotfiles-plugin-bash-rofi-scripts`
* `dotfiles-plugin-node-workspaces`
* `dotfiles-plugin-python-env-manager`

## Plugin Directory Structure

Each plugin is added under the `plugins/` directory, e.g., `plugins/dotfiles-plugin-bash-rofi-scripts`. Plugins should include:

* `README.md`: Documentation for the plugin.
* `script.sh`: The primary script or entry point.
* `config.json`: A configuration file specifying script paths and dependencies.

## Adding a Plugin

To add a plugin, use the following steps:

1. **Add the Plugin via Subtree**:

   ```bash
   git subtree add --prefix=plugins/{plugin-name} {repository-url} {branch}
   ```

   * Replace `{plugin-name}` with the name of the plugin (e.g., `dotfiles-plugin-bash-rofi-scripts`).
   * Replace `{repository-url}` with the URL of the plugin repository.
   * Replace `{branch}` with the branch you want to add (typically `main`).

   **Example**:

   ```bash
   git subtree add --prefix=plugins/dotfiles-plugin-bash-rofi-scripts git@github.com:davidsneighbour/dotfiles-plugin-bash-rofi-scripts.git main
   ```

2. **Verify the Addition**:
   Confirm the plugin was added by checking the `plugins/` directory.

## Updating a Plugin

To pull updates from the plugin repository:

```bash
git subtree pull --prefix=plugins/{plugin-name} {repository-url} {branch}
```

**Example**:

```bash
git subtree pull --prefix=plugins/dotfiles-plugin-bash-rofi-scripts git@github.com:davidsneighbour/dotfiles-plugin-bash-rofi-scripts.git main
```

## Removing a Plugin

To remove a plugin:

1. **Remove the Plugin Files**:

   ```bash
   git rm -r plugins/{plugin-name}
   ```

2. **Commit the Changes**:

   ```bash
   git commit -m "Remove {plugin-name} plugin"
   ```

3. **Prune Unused Objects** (optional):

   ```bash
   git gc --prune=now
   ```

## `plugins-loader.sh` Script

The `plugins-loader.sh` script is responsible for initializing and managing plugins. It scans the `plugins/` directory for `config.json` files, processes them, and ensures the correct setup of each plugin.

### Features

* Dynamically loads all plugins.
* Ensures scripts are executable.
* Installs dependencies as specified in `config.json`.
* Logs initialization details to `~/.logs/plugins-loader.log`.

### Running the Loader

To initialize plugins, run:

```bash
./plugins-loader.sh
```

### Example Workflow

1. Add a plugin using `git subtree`.
2. Run `plugins-loader.sh` to initialize the new plugin.
3. Verify the logs in `~/.logs/plugins-loader.log` for any errors or warnings.

## Best Practices

* Use descriptive names for plugins.
* Keep each plugin repository self-contained with clear documentation.
* Regularly update plugins using `git subtree pull`.
* Review `plugins-loader.sh` logs after changes to ensure proper initialization.

For additional help, refer to the specific plugin’s `README.md` or contact the repository maintainer.
