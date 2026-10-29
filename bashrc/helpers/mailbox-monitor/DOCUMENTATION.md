# Mailbox monitor function reference

Operational instructions are in [README.md](README.md).

## Monitor

* `REMOTE_SCRIPT` — `sh` script that runs on the mail server and prints one tab-separated line per mailbox (`OK`, `SKIP`, or `ERROR`).
* `runBestEffort` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `showHelp` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `requireEnv` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `optionalEnv` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `numberEnv` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `expandHome` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `safeRemoteArgument` — rejects values that are not safe to pass to the remote shell.
* `getConfig` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `readRemoteQuotas` — runs `REMOTE_SCRIPT` over SSH and returns its output.
* `formatSize` — formats a KB value as MB or GB.
* `parseRemoteOutput` — converts the remote output into quota records and errors.
* `createDiscordContent` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `sendDiscordMessage` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `createMarkdownSummary` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `appendHistory` — appends one JSON line per mailbox to the history file.
* `writeOutputs` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `run` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).

## Wrapper

* `show_help` — prints wrapper options.
* `load_env` — sources the selected private configuration file.
* `run_monitor` — runs Node in the configured directory.
* `main` — parses wrapper arguments and starts the monitor.

Wrapper functions are defined in [run-mailbox-monitor.sh](run-mailbox-monitor.sh).

## History analyser

* `defaultHistoryFile` — resolves the history file from the environment, defined in [analyse-history.mjs](analyse-history.mjs).
* `readHistory` — reads the JSON lines and skips invalid lines with a warning.
* `analyse` — groups checks by mailbox and calculates change, rate, and days until full.
* `printTable` — prints the summary table, optionally with each check.
* `run` — parses the options and prints the result.
