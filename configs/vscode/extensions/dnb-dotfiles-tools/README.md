# DNB Dotfiles Tools

Local VS Code extension for the David's Neighbour dotfiles repository.

## What it does

This extension adds one command:

* `Dotfiles: Insert Next Version`

The command runs:

```bash
 dotfiles --next
```

It inserts the trimmed output at the current cursor position or replaces the current selection.

## Default keybinding

```text
Ctrl+Alt+V
```

## Settings

The command is configurable via VS Code settings:

```json
{
  "dnbDotfilesTools.dotfilesCommand": "dotfiles",
  "dnbDotfilesTools.nextVersionArgs": ["--next"],
  "dnbDotfilesTools.timeoutMs": 10000
}
```

Use an absolute command path if VS Code cannot find `dotfiles` in its environment.

## Build

From this folder:

```bash
npm install
npm run build
```

## Install locally

From the dotfiles repository root:

```bash
./configs/vscode/extensions/scripts/install-local-extensions.sh
```

This creates the symlink:

```text
~/.vscode/extensions/davidsneighbour.dnb-dotfiles-tools -> ~/github.com/davidsneighbour/dotfiles/configs/vscode/extensions/dnb-dotfiles-tools
```

Restart VS Code after the first install.

## Usage

Type a header prefix, for example:

```text
version: 
```

Then run `Dotfiles: Insert Next Version` from the command palette or press `Ctrl+Alt+V`.
