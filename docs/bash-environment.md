# Bash Environment Architecture

* [Architecture Notes](#architecture-notes)
* [Shell Startup Model](#shell-startup-model)
  * [Login shells](#login-shells)
    * [Flow](#flow)
  * [Interactive shells](#interactive-shells)
  * [Non-interactive shells](#non-interactive-shells)
* [Interactive Detection](#interactive-detection)
  * [Where it is defined](#where-it-is-defined)
* [Interactive Detection Helper](#interactive-detection-helper)
* [Partial Script Architecture](#partial-script-architecture)
  * [`lib`](#lib)
  * [`_programs`](#_programs)
* [Runtime Initialisation Strategy](#runtime-initialisation-strategy)
  * [Environment-only tools](#environment-only-tools)
  * [Interactive integrations](#interactive-integrations)
* [Node Execution Wrapper](#node-execution-wrapper)
* [Node Wrapper Behaviour](#node-wrapper-behaviour)
* [Fast Node Resolution](#fast-node-resolution)
* [Automatic Fallback](#automatic-fallback)
* [Wrapper Usage](#wrapper-usage)
  * [Run script with default Node](#run-script-with-default-node)
  * [Specify Node version](#specify-node-version)
  * [Use project `.nvmrc`](#use-project-nvmrc)
  * [Enable debug output](#enable-debug-output)
* [Cron Usage Example](#cron-usage-example)
* [TypeScript Support](#typescript-support)

## Architecture Notes

This repository implements a structured Bash environment that separates:

* login/session configuration
* interactive shell behaviour
* program initialisation
* reusable helper libraries

The goal is predictable shell behaviour across:

* login shells
* interactive shells
* non-interactive shells
* cron jobs
* scripts

This document explains how the environment is structured and how scripts integrate with it.

## Shell Startup Model

The environment follows the standard Bash startup sequence.

### Login shells

Login shells load: `.bash_profile`. This file then loads: `.profile` and `.bashrc`.

This ensures login shells receive both session environment and interactive configuration.

#### Flow

```plaintext
login shell
    └── .bash_profile
            ├── .profile
            └── .bashrc
```

### Interactive shells

Interactive shells load: `.bashrc`. These shells include:

* terminal sessions
* shells opened inside editors
* subshells launched by interactive tools

### Non-interactive shells

Non-interactive shells do not automatically load shell configuration.

Examples:

* cron
* system scripts
* CI jobs
* shell scripts invoked directly

Scripts should bootstrap their environment explicitly if required.

## Interactive Detection

The environment defines the variable: `DNB_IS_INTERACTIVE`.

* 1 = interactive shell
* 0 = non-interactive session

### Where it is defined

* `.bashrc`: `export DNB_IS_INTERACTIVE=1`
* `.profile`: `export DNB_IS_INTERACTIVE=0`

## Interactive Detection Helper

To simplify checks across partial scripts, a helper function is provided.

```bash
dnb_is_interactive() {
  [[ "${DNB_IS_INTERACTIVE:-0}" == "1" ]]
}

if dnb_is_interactive; then
  # interactive-only logic
fi
```

This avoids repeated direct variable comparisons and ensures consistent behaviour.

## Partial Script Architecture

Shell configuration is split into reusable partial scripts.

Directory structure:

```plaintext
bashrc/
    lib/
    partials/
        _programs/
```

### `lib`

Contains reusable shell helpers and functions.

Examples:

```plaintext
dnb_is_interactive
```

These are loaded early by both `.profile` and `.bashrc`.

### `_programs`

Contains program-specific initialisation.

Examples:

```plaintext
nvm
language runtimes
tool integrations
```

These scripts should:

* be idempotent
* not assume interactive shells unless explicitly required
* guard interactive-only behaviour using `dnb_is_interactive`99999999999999
Example:

```plaintext
if dnb_is_interactive; then
  enable-completions
fi
```

## Runtime Initialisation Strategy

Programs fall into three categories.

### Environment-only tools

These only require environment variables or PATH adjustments.

Example:

```plaintext
deno
```

These can safely run in both login and non-interactive environments.

### Interactive integrations

These add features like:

* shell completions
* prompt integration
* aliases
* shell functions

These must be guarded:

```plaintext
if dnb_is_interactive; then
```

## Node Execution Wrapper

Cron jobs and automation scripts often require Node from `nvm`.

However, cron environments do not load shell startup files.

To solve this, a wrapper script is used.

Location example:

```plaintext
~/bin/node-run.sh
```

This script:

* loads `nvm`
* optionally selects a Node version
* executes a script

## Node Wrapper Behaviour

The wrapper supports:

* explicit Node version selection
* `.nvmrc` detection
* automatic fallback to `nvm`
* fast resolution when possible

## Fast Node Resolution

When the requested version is simple, the wrapper resolves Node directly.

Supported fast versions:

```plaintext
22
v22
22.12.0
v22.12.0
```

The wrapper searches:

```plaintext
~/.nvm/versions/node/
```

and selects the appropriate binary without loading `nvm`.

Benefits:

* faster startup
* reduced shell overhead
* ideal for cron jobs

## Automatic Fallback

For complex selectors, the wrapper loads `nvm`.

Examples:

```plaintext
lts/*
node
aliases
.nvmrc
```

This guarantees compatibility with full `nvm` behaviour.

## Wrapper Usage

### Run script with default Node

```bash
node-run.sh --script /path/job.ts
```

### Specify Node version

```bash
node-run.sh --script /path/job.ts --node-version 22
```

### Use project `.nvmrc`

```bash
node-run.sh --script job.ts --cwd /path/project
```

### Enable debug output

```bash
node-run.sh --script job.ts --verbose
```

## Cron Usage Example

Example cron job:

```crontab
*/5 * * * * /home/patrick/bin/node-run.sh --script /home/patrick/jobs/example.ts >> /home/patrick/.logs/cron/example.log 2>&1
```

This ensures:

* the correct Node version is used
* runtime resolution does not depend on shell startup files

## TypeScript Support

Modern Node versions (v24+) include built-in TypeScript typing support. And we assume that support baked in. No special treatment of `node` calls is done when we work with TypeScript files.

The wrapper does not modify Node's TypeScript behaviour. It only resolves the Node runtime.
