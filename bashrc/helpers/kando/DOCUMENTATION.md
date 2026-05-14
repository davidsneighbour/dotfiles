# `kando/` documentation

This file documents every file currently present in `bashrc/helpers/kando`.

Parent index: [`../INDEX.md`](../INDEX.md).

## Files

### `kando/kando-vscode-menu-creator.ts`

Updates a Kando menu from VS Code .code-workspace files.

CLI option notes:

* --menu-json-path PATH — Kando menus.json path.
* --workspaces-dir PATH — directory with workspace files.
* --menu-name NAME — Kando menu root.name to replace.
* --vscode-command COMMAND — command in each Kando entry.
* --extensions LIST — comma-separated extensions.
* --dry-run — print changes only.
* --apply — write changes and backup original.
* --verbose — extra logging.
* --help — show help.

Functions/methods defined:

* `printHelp`
* `expandHome`
* `safeJsonPreview`
* `parseCommaList`
* `parseArgs`
* `vlog`
* `pathExists`
* `readMenuJson`
* `listWorkspaceFiles`
* `makeChildEntry`
* `isMenuRootObject`
* `isMenuObject`
* `updateTargetMenu`
* `writeBackup`
* `writeUpdatedMenu`
* `summariseChange`
* `main`

Requirements:

* Node.js with TypeScript execution support.
* A writable Kando menus.json file.
* VS Code workspace files.
