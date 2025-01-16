# `rofi-workspaces.sh` - README

This script generates a dynamic menu using **Rofi** to manage project directories and workspace files for efficient development workflows. It can display `.code-workspace` files from specific directories and optionally create missing ones.

## Features

* **Dynamic Menu**: Displays projects and workspace files in a Rofi menu.
* **Recent Items**: Highlights the last selected items (configurable via cache).
* **Custom Sorting**: Alphabetical ordering (ASC or DESC) for menu items.
* **Empty Projects Filtering**: Optionally hide directories without `.code-workspace` files.
* **Workspace Creation**: Automatically create `.code-workspace` files for missing directories.
* **Multi-directory Support**: Handles multiple `projectsdirs` and `workspacedirs`.

## Requirements

- **Rofi**: Must be installed (`rofi` command).
* **Visual Studio Code**: Must be available as the `code` command.

## Usage

```bash
./rofi-workspaces.sh [OPTIONS]
```

### Options

| Option                | Description                                                                                 | Default                                  |
|-----------------------|---------------------------------------------------------------------------------------------|------------------------------------------|
| `--workingdir DIR`    | Set the directory containing Rofi configuration files.                                      | `$HOME/.config/rofi/`                   |
| `--projectsdirs DIRS` | Comma-separated list of directories containing project folders.                             | `$HOME/github.com/davidsneighbour`      |
| `--workspacedirs DIRS`| Comma-separated list of directories containing `.code-workspace` files.                     | None                                     |
| `--filepattern PATTERN`| Set the file pattern for workspace files.                                                  | `*.code-workspace`                      |
| `--config FILE`       | Set the Rofi configuration file.                                                            | `${WORKINGDIR}/config.rasi`             |
| `--prompt TEXT`       | Set the text displayed in the Rofi menu prompt.                                             | `Select Project`                        |
| `--sortorder ORDER`   | Sorting order of menu items. Use `ASC` or `DESC`.                                           | `ASC`                                   |
| `--createworkspace`   | Enable automatic creation of `.code-workspace` files in missing directories.                | Disabled                                |
| `--hideemptyprojects` | Hide project directories without `.code-workspace` files.                                   | Disabled                                |
| `--clearcache`        | Clear the cache of recent items. Must be used alone.                                        | N/A                                     |
| `--help`              | Display a help message with usage details.                                                 | N/A                                     |

## Examples

### Basic Usage

List projects and workspaces with default settings:

```bash
./rofi-workspaces.sh
```

### Set Custom Projects and Workspace Directories

```bash
./rofi-workspaces.sh --projectsdirs github.com/example,gitlab.com/example --workspacedirs $HOME/workspaces
```

### Hide Empty Project Directories

```bash
./rofi-workspaces.sh --hideemptyprojects
```

### Create Missing `.code-workspace` Files

Automatically create `.code-workspace` files for directories without them:

```bash
./rofi-workspaces.sh --createworkspace
```

### Sort Items in Descending Order

```bash
./rofi-workspaces.sh --sortorder DESC
```

### Clear Recent Items Cache

Clear the cache of recent items:

```bash
./rofi-workspaces.sh --clearcache
```

### Specify Rofi Configuration

```bash
./rofi-workspaces.sh --config ~/.config/rofi/myconfig.rasi
```

## Behavior Details

### Workflow

1. **Directory Scan**:
   * The script scans directories provided in `--projectsdirs` and `--workspacedirs`.
   * `.code-workspace` files are added to the menu.
2. **Rofi Menu**:
   * Displays all scanned items, optionally sorted and filtered.
   * Allows the user to select a project or workspace file.
3. **Selection Handling**:
   * If a `.code-workspace` file is selected, it opens in Visual Studio Code.
   * If a project directory is selected:
     * Opens its `.code-workspace` file (if present).
     * Creates one if `--createworkspace` is enabled.

## Notes

- **Cache Behavior**:
  * Recent selections are stored in `${HOME}/.cache/rofi_workspaces_cache`.
  * Only the last `N` items (default `5`) are retained.
* **Fallback Template**:
  * If no `.code-workspace` template is found in the `--workingdir`, a default is created with the following content:

    ```json
    {
      "folders": [
        {
          "path": "."
        }
      ]
    }
    ```

## Troubleshooting

1. **Rofi Not Found**:
   * Ensure `rofi` is installed and available in your `PATH`.
2. **Visual Studio Code Not Found**:
   * Ensure `code` is installed and available in your `PATH`.
3. **Directory Issues**:
   * Verify paths provided to `--projectsdirs` and `--workspacedirs`.
