---
applyTo: "bashrc/partials/_functions/**,bashrc/partials/_completions/**"
---

# Bash completions

All new or changed user-facing Bash functions and repository CLIs must implement the [safe standard help contract](../../../bashrc/partials/_completions/README.md) and register once in `bashrc/partials/_completions/commands.sh` with `dnb_register_completion COMMAND`. The shared engine derives options and subcommands from help. Never duplicate CLI option lists in completion files. Keep specialised third-party completions where needed. Test safe help and completion when changing a CLI.
