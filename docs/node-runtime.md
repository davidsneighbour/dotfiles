# Node runtime execution with NVM

## Stable runtime for scheduled services

`scripts/node-cron.sh --refresh` maintains `~/.local/bin/node-cron`, a machine-local symlink to the newest installed NVM LTS major and patch known through local LTS aliases. It loads `${NVM_DIR:-${HOME}/.nvm}/nvm.sh` without selecting a shell runtime, validates the executable, and atomically replaces the link. It never installs Node or accesses the network. If `lts/*` points to an uninstalled patch, it also checks installed versions of cached LTS majors. Refresh fails clearly when NVM, cached LTS metadata, or an installed LTS executable is missing. An existing regular file is preserved. The symlink is runtime state and is not tracked in Git.

From the repository root:

```bash
/bin/bash scripts/node-cron.sh --refresh
readlink -f "${HOME}/.local/bin/node-cron"
"${HOME}/.local/bin/node-cron" --version
/bin/bash scripts/node-cron.sh --refresh --exec -- /absolute/path/to/job.ts
```

The Git catalogue cron entries use `--exec`; the storage runner refreshes when `--node` selects this stable path. Each startup and periodic invocation completes refresh before Node starts, so there is no dependency on ordering between independent `@reboot` jobs. Refresh failures stop the dependent job. Concurrent refreshes use separate temporary directories and atomic replacement. Refresh status is recorded in `~/.logs/node-runtime/YYYYMMDD-HHMMSS.log`. Use `--verbose` to print the selected path when using `--exec`.

To check the published release metadata, install the latest released LTS, and refresh the link:

```bash
/bin/bash configs/session/npm/cron-node-update.sh --lts --dry-run
/bin/bash scripts/node-cron.sh --update
```

`--update` resolves `nvm version-remote --lts`, installs that exact release with `nvm install` in the helper process, validates it, and then refreshes the link. It requires network access and may take time. Resolution or installation failure leaves the existing link unchanged and reports the log path. Installer output goes to the runtime log. The existing updater's `--lts` option delegates to this same operation; `--lts --dry-run` prints the delegated command without running it. It preserves the existing Node Current update and default-selection behaviour when `--lts` is omitted. The weekly Current cron job remains unchanged. The `host-locutus` profile also runs `node-cron.sh --update` every Sunday at 04:45 in the cron daemon’s local timezone, using the stable job ID `node-cron-lts-weekly`. Missed weekly runs are not replayed when the workstation is off. Boot never runs an installer. Reapply the `host-locutus` and storage Dotbot profiles to install the revised cron commands; changing the YAML does not change the installed crontab. Existing running services keep their runtime until restarted.

The separate `node-run` helper below can install missing versions and therefore is not the boot-time refresh mechanism.

This repository provides a wrapper script for running Node.js programs in environments where the normal shell initialisation process is not executed. This is particularly relevant for cron jobs, system services, and other non-interactive execution contexts.

The wrapper ensures that Node.js managed by `nvm` can be used reliably without depending on shell startup files such as `.bashrc` or `.profile`.

## Why this wrapper exists

Node installed via `nvm` is not globally available by default. Instead, `nvm` modifies the environment dynamically when it is loaded in a shell.

Interactive shells typically load `nvm` through `.bashrc`, but non-interactive environments such as cron do not load shell configuration automatically. As a result, commands such as:

```bash
node script.ts
```

may fail in cron even though they work in a terminal session.

This wrapper solves that problem by explicitly resolving the correct Node runtime before executing the script.

## Location

Example installation location:

```text
~/bin/node-run.sh
```

Any location in the user's executable `PATH` is acceptable.

## Behaviour

The wrapper performs the following steps:

1. Determine the working directory
2. Resolve the Node version to use
3. Attempt a fast direct lookup of the Node binary
4. Fall back to `nvm` if necessary
5. Execute the script with the resolved Node runtime

The wrapper does not modify Node runtime behaviour. It only determines which Node binary is used.

## Version resolution strategy

### Fast path resolution

For simple version identifiers, the wrapper resolves Node directly from the filesystem without loading `nvm`.

Supported forms:

```text
22
v22
22.12.0
v22.12.0
```

Resolution occurs by scanning:

```text
~/.nvm/versions/node/
```

and selecting the appropriate binary.

Benefits:

* faster startup
* no shell overhead
* ideal for cron jobs

### NVM fallback

For more complex selectors, the wrapper loads `nvm`.

Examples:

```text
lts/*
node
default
aliases
.nvmrc
```

This ensures compatibility with all `nvm` features.

## Script usage

### Run script with default node

```bash
node-run.sh --script /path/to/job.ts
```

The wrapper will attempt to use the current `nvm` default or `.nvmrc` if present.

### Run script with explicit node version

```bash
node-run.sh --script /path/to/job.ts --node-version 22
```

### Use project `.nvmrc`

```bash
node-run.sh --script job.ts --cwd /path/to/project
```

The wrapper will change into the provided directory and run:

```bash
nvm use
```

### Enable verbose output

```bash
node-run.sh --script job.ts --node-version lts/* --verbose
```

Verbose mode prints:

* resolution strategy
* Node version
* working directory
* executed script

## Cron integration

Example cron job:

```text
*/5 * * * * /home/patrick/bin/node-run.sh --script /home/patrick/jobs/example.ts >> /home/patrick/.logs/cron/example.log 2>&1
```

This ensures:

* Node version resolution independent of shell startup
* compatibility with `nvm`
* reliable execution in cron environments

## TypeScript execution

Modern Node versions include built-in TypeScript support that strips type annotations at runtime.

This allows scripts such as:

```bash
node script.ts
```

to run directly.

Supported TypeScript features include:

* type annotations
* interfaces
* type-only imports

However, Node does not perform full TypeScript compilation.

Unsupported constructs may require additional flags:

```text
--experimental-transform-types
```

or a separate runtime such as `tsx`.

The wrapper does not modify TypeScript behaviour. It simply resolves the Node runtime.

## Design goals

The wrapper is designed to provide:

* reliable Node execution in cron environments
* compatibility with `nvm`
* minimal runtime overhead
* forward compatibility with new Node versions
* optional support for `.nvmrc`

## Summary

This wrapper allows Node scripts to run consistently across:

* interactive shells
* login shells
* cron jobs
* automated scripts

without requiring shell configuration files to be loaded.
