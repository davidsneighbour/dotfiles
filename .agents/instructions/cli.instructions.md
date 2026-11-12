---
applyTo: "bin/**,bashrc/helpers/**,bashrc/partials/_functions/**,tools/**,scripts/**"
---

# CLI behaviour

All user-facing CLI scripts **MUST**:

* Support `--help`
* Print help if required parameters are missing
* Use named flags, never positional-only arguments
* Support `--verbose` (default: minimal output)
* Fail gracefully with actionable messages
* Keep results on stdout and human-facing output on stderr; Bash commands use the [terminal UI facade](bashrc/terminal-ui.instructions.md) for messages, prompts, and rendering

For Bash helper commands, also print help when invoked with no arguments, even when all parameters are optional. Missing required files or folders must produce an error, help output, and a non-zero exit.

## Help output

* Help text must be accurate
* Function-level help should use `${FUNCNAME[0]}` where applicable
* Usage examples are encouraged

## Bash completion

All new or changed user-facing CLIs and sourced Bash functions must follow the [standardised safe help contract](../../bashrc/partials/_completions/README.md). Handle `--help` before side effects, configuration, credentials, dependency checks, or prompts. List every option under `Options:` and subcommands under `Commands:`; each subcommand must provide its own safe `--help`. Share parsing and help definitions where practical. Register the command name once using `dnb_register_completion COMMAND` in `bashrc/partials/_completions/commands.sh`. Never maintain a second option list for completion.

For a local npm package that needs global CLI links on locutus, add one explicit `shell` entry per repository in `configs/dotbot/config.host-locutus.yaml`, following [the local npm CLI link pattern](../../configs/dotbot/README.md#local-npm-cli-links). Use the caller's active Node/npm, report the runtime and global prefix, and run `npm link` inside the repository with failures propagated. Do not link packages during shell startup or runtime switching. Keep completion registration separate.
