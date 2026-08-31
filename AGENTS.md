<!-- markdownlint-disable-next-line title-case-style -->
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

* `protected/`
  Private submodule for secrets, credentials, and local secure assets

* `lib/`
  Shared Bash helpers and internal functions

* `config/`
  Static configuration files

* `docs/`
  Human documentation (never required to operate the system)

* `.github/`
  Repository-specific configuration (including optional `dnb.toml` files)

### Related packages

Packages referred to as `@davidsneighbour/PACKAGENAME` live at `https://github.com/davidsneighbour/PACKAGENAME`. If a referenced package is not found there, ask for a clear location for the latest version before depending on it.

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

### Instructions

For all Bash and shell-related code, including every file within bashrc/ and any file outside that directory that influences the Bash or interactive shell experience, .github/instructions/bashrc.instructions.md MUST be read and strictly adhered to.

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

* All logs go to `~/.logs/` into a subdirectory that reflects the functionality being logged (e.g. `~/.logs/cron/` for cronjob logs)
* If you are able to use `dnb_log_init` the folder will be created for you, otherwise you must ensure the folder exists before writing logs
* Log files **MUST** be named: `YYYYMMDD-HHMMSS.log`

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

<!-- markdownlint-disable-next-line title-case-style -->
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

### Package manager

* Use static versions in `package.json`
* Use npm as the package manager; `npm install` must work without issues

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

## Secrets and tokens

* Real tokens, API keys, and other credentials belong only in real, gitignored `.env` files (or in the `protected/` submodule) — never in `.env.template`, `.env.example`, or any other file whose name or purpose marks it as a template
* When a token-shaped value must appear in a template, example, or documentation, anonymise it (e.g. `gpd_######`) instead of using a real-looking value
* Every secret-consuming script must load its value from a documented `.env`/config source, never a hardcoded literal
* Missing secrets must fail safely and quietly (log a short skip message and continue or exit non-fatally), not spam errors or crash unrelated functionality
* Never log secret values, even at verbose/debug log levels
* `secretlint` (wired into `lint-staged` on every tracked file) is the enforcement backstop for this policy — do not bypass it or narrow `.secretlintignore` to work around a real finding

## Documentation rules

Documentation is **secondary**, not authoritative.

Rules:

* Scripts are the source of truth
* Documentation must not describe behaviour that scripts do not enforce
* Avoid duplication
* Prefer short explanations over exhaustive prose
* If a folder contains a `README.md`, read and follow it before working in that folder
* If a folder contains an `INDEX.md`, read it and follow the structure it lays out
* Update `README.md` and `INDEX.md` files as you work on their counterparts
* Add documentation for any change you make in the codebase
* Read and apply any instructions under `.github/instructions/`, scoped by each file's `applyTo` field

### Quick instructions

These shorthand instructions carry a fixed meaning when a user gives them:

* **"Update your references"** — fetch the currently used repository and update to the latest HEAD of the main branch; update code to reflect any upstream changes; resolve merge conflicts if any arise.
* **"Document"** — add documentation to the `README.md` in the folder you worked on, or create a new documentation file and link it from `README.md`; explain what the code does, how to use it, and anything else useful to someone new to the codebase.

## AI agent rules (mandatory)

Any AI agent operating on this repository **MUST**:

* Read this file before proposing changes
* Follow all Bash, CLI, and safety rules
* Ask explicitly if required information is missing
* Never assume user intent
* Never optimise for cleverness over clarity
* Never remove safeguards without justification
* Before touching i3, Polybar, Rofi, X11/Xorg, LightDM/session selection,
  or any other part of the graphical desktop session, read the repo-root
  `SESSION.md` first — it is the authoritative session architecture
  reference — and update it in the same change if the change affects what
  it documents

AI-generated code is treated as production code.

## Change management

### Commits and branching

* Commit directly to `main`; create a branch only when explicitly asked to do so
* Use Conventional Commits messages
* Use `.release-it.ts` for the list of available commit scopes

### Submodules

When committing submodule updates, commit only the changed submodule HEAD recorded by this parent repository.
Stage the submodule path from the parent repository, for example `git add protected`.
Do not commit, amend, clean, reset, or otherwise modify work inside the submodule unless the user explicitly asks for submodule-internal changes.

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
