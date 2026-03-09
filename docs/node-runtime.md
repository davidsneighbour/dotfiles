# Node Runtime Execution with NVM

This repository provides a wrapper script for running Node.js programs in environments where the normal shell initialisation process is not executed. This is particularly relevant for cron jobs, system services, and other non-interactive execution contexts.

The wrapper ensures that Node.js managed by `nvm` can be used reliably without depending on shell startup files such as `.bashrc` or `.profile`.

## Why This Wrapper Exists

Node installed via `nvm` is not globally available by default. Instead, `nvm` modifies the environment dynamically when it is loaded in a shell.

Interactive shells typically load `nvm` through `.bashrc`, but non-interactive environments such as cron do not load shell configuration automatically. As a result, commands such as:

```bash
node script.ts
````

may fail in cron even though they work in a terminal session.

This wrapper solves that problem by explicitly resolving the correct Node runtime before executing the script.

## Location

Example installation location:

```
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

## Version Resolution Strategy

### Fast Path Resolution

For simple version identifiers, the wrapper resolves Node directly from the filesystem without loading `nvm`.

Supported forms:

```
22
v22
22.12.0
v22.12.0
```

Resolution occurs by scanning:

```
~/.nvm/versions/node/
```

and selecting the appropriate binary.

Benefits:

* faster startup
* no shell overhead
* ideal for cron jobs

### NVM Fallback

For more complex selectors, the wrapper loads `nvm`.

Examples:

```
lts/*
node
default
aliases
.nvmrc
```

This ensures compatibility with all `nvm` features.

## Script Usage

### Run script with default Node

```
node-run.sh --script /path/to/job.ts
```

The wrapper will attempt to use the current `nvm` default or `.nvmrc` if present.

### Run script with explicit Node version

```
node-run.sh --script /path/to/job.ts --node-version 22
```

### Use project `.nvmrc`

```
node-run.sh --script job.ts --cwd /path/to/project
```

The wrapper will change into the provided directory and run:

```
nvm use
```

### Enable verbose output

```
node-run.sh --script job.ts --node-version lts/* --verbose
```

Verbose mode prints:

* resolution strategy
* Node version
* working directory
* executed script

## Cron Integration

Example cron job:

```
*/5 * * * * /home/patrick/bin/node-run.sh --script /home/patrick/jobs/example.ts >> /home/patrick/.logs/cron/example.log 2>&1
```

This ensures:

* Node version resolution independent of shell startup
* compatibility with `nvm`
* reliable execution in cron environments

## TypeScript Execution

Modern Node versions include built-in TypeScript support that strips type annotations at runtime.

This allows scripts such as:

```
node script.ts
```

to run directly.

Supported TypeScript features include:

* type annotations
* interfaces
* type-only imports

However, Node does not perform full TypeScript compilation.

Unsupported constructs may require additional flags:

```
--experimental-transform-types
```

or a separate runtime such as `tsx`.

The wrapper does not modify TypeScript behaviour. It simply resolves the Node runtime.

## Design Goals

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
