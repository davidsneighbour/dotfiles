# AGENTS.md

This repository contains the personal dotfiles, automation scripts, and infrastructure tooling of **Patrick Kollitsch (David's Neighbour)**.

It is a *production system*, not a playground. All changes must prioritise reproducibility, safety, and long-term maintainability.

This document defines **scope**, **architecture**, **features**, and **mandatory rules** for working with this repository.

## Purpose and philosophy

This dotfiles repository exists to:

* Provide a **reproducible Linux workstation setup**
* Centralise **CLI tools, Bash functions, and automation**
* Manage **Docker-based services** in a consistent structure
* Encode **operational knowledge** as scripts instead of documentation
* Remain usable without cloud dependencies or proprietary tooling

Core principles:

* Explicit over implicit
* Safe defaults over clever shortcuts
* Scripts must be composable and inspectable
* Failure must be observable and explainable
* No hidden state

## High-level structure

The repository is organised by *function*, not by technology.

Common top-level areas (names may evolve):

* `bin/`
  User-facing CLI commands and helpers

* `modules/`
  Feature modules such as containers, cronjobs, or integrations

* `lib/`
  Shared Bash helpers and internal functions

* `config/`
  Static configuration files

* `docs/`
  Human documentation (never required to operate the system)

* `.github/`
  Repository-specific configuration (including optional `dnb.toml` files)

## Environment assumptions

All scripts and tooling assume:

* Linux (primary target: Linux Mint / Ubuntu-based)
* Bash (not POSIX sh)
* No cross-shell compatibility required
* Node.js (modern LTS or newer)
* Docker and Docker Compose available
* Git available and configured

Nothing in this repository is intended to run on macOS or Windows unless explicitly stated.

## Bash standards (mandatory)

All Bash code **MUST** comply with the following rules.

### Shell and safety

* Use `#!/bin/bash`
* Do **NOT** rely on `/usr/bin/env`
* Interactive shell functions **MUST NOT** use:

  * `set -e`
  * `set -u`
  * `set -o pipefail`
* Non-interactive scripts **MUST** fail safely and explicitly

### Linting and correctness

* All scripts **MUST** pass `shellcheck`
* SC2250-style pipe safety **MUST** be respected
* No empty `catch`-equivalent blocks
* Errors must be logged or printed meaningfully

### Variables and quoting

* Always use `${var}` syntax
* Never rely on implicit globbing
* Quote paths unless intentional splitting is required

### Logging

* All logs go to `~/.logs/`
* Log files **MUST** be named: `setup-log-YYYYMMDD-HHMMSS.log`

No per-error or per-script log naming.

## CLI behaviour standards

All user-facing CLI scripts **MUST**:

* Support `--help`
* Print help if required parameters are missing
* Use named flags, never positional-only arguments
* Support `--verbose` (default: minimal output)
* Fail gracefully with actionable messages

### Help output

* Help text must be accurate
* Function-level help should use `${FUNCNAME[0]}` where applicable
* Usage examples are encouraged

## Repository-local configuration (`.github/dnb.toml`)

Repositories may optionally define a configuration file at `.github/dnb.toml`.

Properties:

* File may exist or not
* Absence is **not an error**
* Consumers must treat missing values as `false`
* Empty strings are valid values
* Only zero-length strings are considered empty

### Access pattern

* Configuration keys use dot notation: `section.key`
* Consumers must rely on **exit codes**, not sentinel strings
* Literal `"false"` is a valid value and must not collide with "not found"

This design intentionally avoids JSON and complex schemas.

## Node.js and TypeScript rules

When Node.js is used:

* ESM only
* No `require`
* No `any` typing
* Strict typing preferred
* Scripts must be runnable directly via `node script.ts`

### Error handling

* No empty `catch` blocks
* Errors must be logged
* Failures must be explicit

## Docker and containers

Containers are managed via **Docker Compose**.

Rules:

* Volumes should be local to the compose file where possible
* Paths must be explicit
* No hidden bind mounts
* No reliance on Docker Desktop features
* Compose files must be readable without external context

The repository prefers *few well-structured containers* over many small ones.

## Cronjobs and automation

Cronjobs:

* Prefer `@reboot` where daily uptime is uncertain
* Scripts must be idempotent
* Scripts must log execution
* Scripts must not assume network availability

Cron scripts live alongside the functionality they support, not in a central cron folder.

## Documentation rules

Documentation is **secondary**, not authoritative.

Rules:

* Scripts are the source of truth
* Documentation must not describe behaviour that scripts do not enforce
* Avoid duplication
* Prefer short explanations over exhaustive prose

## AI agent rules (mandatory)

Any AI agent operating on this repository **MUST**:

* Read this file before proposing changes
* Follow all Bash, CLI, and safety rules
* Ask explicitly if required information is missing
* Never assume user intent
* Never optimise for cleverness over clarity
* Never remove safeguards without justification

AI-generated code is treated as production code.

## Change management

Before making changes:

* Understand existing patterns
* Do not introduce new conventions lightly
* Prefer extending existing helpers over adding new ones
* Refactors must preserve behaviour unless explicitly requested

Breaking changes require explicit acknowledgement.

## Non-goals

This repository intentionally avoids:

* Framework abstractions
* Meta build systems
* Plugin-heavy solutions
* Over-generalisation
* Cross-platform promises

If a tool does not justify its existence, it does not belong here.

## Final note

This dotfiles repository is not a showcase. It is a **working system**.
Consistency, restraint, and clarity are more valuable than novelty.
When in doubt: **Make the safe thing obvious and the dangerous thing hard.**
