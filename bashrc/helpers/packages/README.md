# Package archive helper

`create.sh` is a standalone helper command that creates a zip archive from a named package section in one or more configuration files.

## Usage

```bash
bashrc/helpers/packages/create.sh --package documents
bashrc/helpers/packages/create.sh --package photos --config ~/.config/dnb/packages.toml --verbose
bashrc/helpers/packages/create.sh --list
```

The command prints the created zip path on success.

## Configuration file selection

Configuration files are selected in this order:

1. `--config <file>` values, in the order given. The flag may be repeated.
2. `DNB_PACKAGE_CONFIG_FILES`, as a colon-separated list.
3. `~/.dotfiles/configs/hosts/<hostname-lowercase>.toml`.

When more than one config file is selected, matching `[packages.<name>]` sections are merged in order.

## Package syntax

Package sections use the existing line-oriented package format:

```toml
[packages.documents]
~/Documents/report.pdf
$HOME/Documents/*.md
/srv/project/releases/**/*.tar.gz
```

Rules:

- Put one path or glob pattern per line under `[packages.<name>]`.
- Empty lines and lines starting with `#` or `;` are ignored.
- Use `~` or `$HOME` for files below the home directory.
- Other `$VARIABLE` references are expanded when `envsubst` is available.
- Use Bash glob syntax directly in the config file:
  - `*` matches within a path segment.
  - `?` matches one character.
  - `[abc]` or `[a-z]` matches a character set or range.
  - `**` matches recursively.
- Do not quote glob patterns in the config file. Quote them only when passing a path through a shell command.
- Filename newline characters are not supported.

## Verbosity

Verbose output follows the repository-wide `DNB_VERBOSE` contract:

```bash
DNB_VERBOSE=1 bashrc/helpers/packages/create.sh --package documents
bashrc/helpers/packages/create.sh --package documents --verbose
bashrc/helpers/packages/create.sh --package documents --quiet
```

`--quiet` overrides `--verbose` and unsets `DNB_VERBOSE` for the helper process.
