# Mailbox monitor function reference

Operational instructions are in [README.md](README.md).

## Monitor

* `runBestEffort` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `showHelp` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `requireEnv` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `optionalEnv` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `numberEnv` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `booleanEnv` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `expandHome` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `getConfig` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `escapeRegExp` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `firstVisibleLocator` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `clickFirstVisible` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `waitAfterNavigationAction` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `cssAttributeValue` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `clickNavigationPath` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `unitToMb` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `parseDataSortToMb` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `parseMailboxUsage` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `extractRawRows` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `createDiscordContent` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `sendDiscordMessage` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `createMarkdownSummary` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `writeOutputs` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).
* `run` — defined in [monitor-mailboxes.mjs](monitor-mailboxes.mjs).

## Wrapper

* `show_help` — prints wrapper options.
* `load_env` — sources the selected private configuration file.
* `run_monitor` — runs Node in the configured directory and forwards login mode.
* `main` — parses wrapper arguments and starts the monitor.

Wrapper functions are defined in [run-mailbox-monitor.sh](run-mailbox-monitor.sh).
