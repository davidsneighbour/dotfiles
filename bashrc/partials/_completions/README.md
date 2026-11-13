# Help-driven Bash completion

The shared engine reads each registered command's `--help`. It supports executables in any language and sourced Bash functions. Register a command once in `commands.sh` with `dnb_register_completion command`. Do not list options there. Existing third-party completions retain their own definitions; migrate repository commands as their help is made compliant. `searchfor` is the first migrated function.

The loader in `partials/completions` sources `_help_completion.sh` before all other files, because glob order depends on the locale. It skips `*.md` and `test-*` files.

## Mandatory help contract

Handle `--help` before configuration, credentials, dependency checks, network calls, prompts, or work. Help must terminate promptly, return zero, and print plain text on stdout. It must be safe in a non-interactive subshell. Registration is a trust boundary: only register tools whose help satisfies this contract. The engine does not enforce a time limit on sourced functions.

Use exact section names at column one. Indent each definition by two or more spaces, and separate its description with at least two spaces. Define one option per line, with optional comma-separated short and long names. Use `<name>` for required values and `[<name>]` for optional values. Document every supported option. Generate help and argument parsing from shared definitions where practical.

```text
Usage: example [options]

Description:
  Manage example items.

Options:
  -h, --help             Show help
  -o, --output <file>    Write a file
      --format <name>    Select a format

Commands:
  list                  List items
  import                Import items

Examples:
  example list --help
```

Each subcommand must support `command subcommand --help` using the same contract, including nested subcommands. Only options for the current context are offered. Option values are skipped during subcommand detection. Both required and optional values reserve the next word; use `--option=value` when omitting an optional value before a subcommand. Values use Bash's default filename completion. The engine does not infer enum values from descriptions. After `--`, Bash's default completion applies.

## Cache and refresh

No help commands run during shell startup. Metadata is held in associative arrays in the current Bash process, never written to disk, sourced, or evaluated. Cache entries expire after five minutes. Executable path, timestamp, size, and inode changes invalidate entries; function definition changes do too. Wrapper dependencies, environment changes, and helper function changes can require `dnb_completion_refresh`, which clears all entries and cached failures. Reloading the engine preserves cached entries; start a new shell or refresh after changing the parser.

Run `npm run test:completions` for parser, executable, function, cache, subcommand, and loader integration tests. The normal `npm run check` gate includes these tests.
