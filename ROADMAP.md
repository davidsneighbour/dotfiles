<!-- vale off -->
# Roadmap

**Project:** `@davidsneighbour/dotfiles` — v3004.0.0
**Last updated:** 2026-07-01
**Branch:** `main`

## Project state

GitHub Issues is the source of truth for actionable work. The repository now has
34 open issues, including 20 new issues created from the repo-wide recommendation
inbox. `TODO.md` is empty except for a note that no unprocessed scratch items
remain.

The main health risks are now visible: npm audit has remaining dev-tooling
findings, the broad TypeScript check fails because runtime-specific scripts share
one configuration, and YAML/config linting mixes first-party errors with
vendored style-pack noise.

## Health indicators

| Signal | Status |
| --- | --- |
| Open GitHub issues | 34 |
| TODO.md | No unprocessed scratch notes remain |
| npm audit | Failing: 11 vulnerabilities, 2 high, 6 moderate, 3 low, 0 critical |
| TypeScript check | Failing: broad `npx tsc --noEmit --pretty false` reports missing Node/runtime globals and typed-script errors |
| Config lint | Failing: `npm run lint:config` reports first-party Dotbot trailing spaces plus vendored/generated Vale YAML noise |
| Markdown lint | Pending after roadmap regeneration; validate `TODO.md` and `ROADMAP.md` before committing |

## Open issues

### Project health and automation

| Issue | Notes |
| --- | --- |
| [#503 Add one repo-wide check command](https://github.com/davidsneighbour/dotfiles/issues/503) | Depends on making the individual validation gates reliable and host-safe. |
| [#504 Split TypeScript configuration by runtime](https://github.com/davidsneighbour/dotfiles/issues/504) | Needed before TypeScript can become a meaningful repo-wide health gate. |
| [#507 Add shell linting and formatting scripts](https://github.com/davidsneighbour/dotfiles/issues/507) | Exposes the required Bash/ShellCheck standard as a runnable check. |
| [#511 Stabilize YAML linting for vendored configs](https://github.com/davidsneighbour/dotfiles/issues/511) | Separates actionable first-party YAML errors from downloaded style-pack noise. |
| [#495 Make lint-staged commands operate only on staged files](https://github.com/davidsneighbour/dotfiles/issues/495) | Keeps pre-commit checks fast and scoped to the staged file set. |
| [#494 Add spell checking for commit messages](https://github.com/davidsneighbour/dotfiles/issues/494) | Needs a decision about local hooks, CI, or both. |
| [#489 Add version-bump linter for changed files](https://github.com/davidsneighbour/dotfiles/issues/489) | Needs clear scope for authoritative version files before implementation. |
| [#502 Follow up on remaining npm audit findings](https://github.com/davidsneighbour/dotfiles/issues/502) | Current audit still reports a fixable `js-yaml` path and unresolved transitive Markdown tooling findings. |

### Setup and installation

| Issue | Notes |
| --- | --- |
| [#497 Fix quick installation flow for dotfiles](https://github.com/davidsneighbour/dotfiles/issues/497) | Clarify the canonical setup entrypoint before broader install-script cleanup. |
| [#506 Make install scripts safe CLI commands](https://github.com/davidsneighbour/dotfiles/issues/506) | Adds help, verbosity, dry-run behaviour, and safer failure modes to install scripts. |
| [#510 Validate setup link targets before applying them](https://github.com/davidsneighbour/dotfiles/issues/510) | Adds a Dotbot/link preflight so setup mistakes are visible before changes apply. |
| [#509 Fix setup shell snippets and permissions](https://github.com/davidsneighbour/dotfiles/issues/509) | Reviews Dotbot snippets for quoting, `${HOME}` usage, and broad permissions. |
| [#505 Remove hard-coded home paths where safe](https://github.com/davidsneighbour/dotfiles/issues/505) | Must account for contexts such as XFCE commands where variable expansion may not exist. |
| [#491 Refine global npm package setup](https://github.com/davidsneighbour/dotfiles/issues/491) | Splits minimal npm defaults from optional global tooling. |
| [#492 Add zoxide to the workstation stack](https://github.com/davidsneighbour/dotfiles/issues/492) | Adds install and Bash initialization with graceful fallback. |
| [#493 Add msgvault Bash completion](https://github.com/davidsneighbour/dotfiles/issues/493) | Loads completions without breaking shell startup when `msgvault` is absent. |

### Shell and desktop workflow

| Issue | Notes |
| --- | --- |
| [#501 Clean up and document bashrc partials](https://github.com/davidsneighbour/dotfiles/issues/501) | Covers startup separation and strict-mode safety in sourced interactive shell code. |
| [#499 Clean up and document bashrc helpers](https://github.com/davidsneighbour/dotfiles/issues/499) | Inventories helpers and adds focused help where useful. |
| [#496 Clean up and document bashrc cronjob helpers](https://github.com/davidsneighbour/dotfiles/issues/496) | Reviews cron helper logging, help output, and shellcheck coverage. |
| [#508 Normalize logging across cronjobs and UI helpers](https://github.com/davidsneighbour/dotfiles/issues/508) | Extends the logging standard across cron, Rofi, Polybar, and install commands. |
| [#500 Clean up and deprecate bashrc workspaces](https://github.com/davidsneighbour/dotfiles/issues/500) | Includes workspace helper hardening or deprecation decisions. |
| [#522 Add health checks for desktop helpers](https://github.com/davidsneighbour/dotfiles/issues/522) | Smoke-checks Rofi, Polybar, and desktop integration helpers without a full desktop session. |
| [#490 Evaluate and add a window tiling helper](https://github.com/davidsneighbour/dotfiles/issues/490) | Compares the linked Xubuntu script, `zentile`, and current window-management patterns. |

### Containers and services

| Issue | Notes |
| --- | --- |
| [#520 Review token and secret handling](https://github.com/davidsneighbour/dotfiles/issues/520) | Audits tokens, API keys, webhooks, credential loading, and secret-safe logging. |
| [#512 Move container secrets into environment files](https://github.com/davidsneighbour/dotfiles/issues/512) | Moves sensitive compose values into documented local environment sources. |
| [#513 Decide on container image pinning policy](https://github.com/davidsneighbour/dotfiles/issues/513) | Makes floating tags intentional and pins the rest for reproducibility. |
| [#517 Replace curl-pipe installers with safer update commands](https://github.com/davidsneighbour/dotfiles/issues/517) | Replaces direct remote installer execution with inspectable update steps. |

### Backups and data safety

| Issue | Notes |
| --- | --- |
| [#516 Replace custom TOML parsing in backup-runner](https://github.com/davidsneighbour/dotfiles/issues/516) | Reduces parser maintenance risk before extending backup configuration. |
| [#515 Add backup retention and restore checks](https://github.com/davidsneighbour/dotfiles/issues/515) | Adds archive rotation and restore confidence checks. |

### Repository structure and modules

| Issue | Notes |
| --- | --- |
| [#498 Document and clean up configs directory](https://github.com/davidsneighbour/dotfiles/issues/498) | Inventory config ownership before moving files or changing link paths. |
| [#519 Centralize local TODO files into the issue tracker](https://github.com/davidsneighbour/dotfiles/issues/519) | Prevents helper-local TODO fragments from drifting away from GitHub Issues. |
| [#518 Document cleanup for local generated and vendored payloads](https://github.com/davidsneighbour/dotfiles/issues/518) | Adds safe cleanup guidance for ignored logs, caches, themes, and downloaded metadata. |
| [#514 Split gmailctl build from apply, version, and push](https://github.com/davidsneighbour/dotfiles/issues/514) | Separates validation from external mutation and publishing in `modules/gmailctl`. |

## Audit findings

`npm audit --json` currently reports 11 dev-tooling vulnerabilities. The high
findings flow through Markdown parser tooling rather than production runtime
dependencies, but #502 remains the tracking issue for remediation or accepted
risk.

| Root package | Severity | Notes |
| --- | --- | --- |
| `js-yaml` → `markdownlint-cli2` | moderate | Fix is available according to npm audit; tracked in #502 |
| `linkify-it` → `markdown-it` → Markdown lint tooling | high/moderate | No complete upstream fix available for all paths |
| `elliptic` → `secp256k1` → secretlint tooling | low | No upstream fix available |

## Suggested order of work

1. Handle [#502](https://github.com/davidsneighbour/dotfiles/issues/502) first because npm audit reports at least one fixable path.
2. Make the local health signals useful: [#511](https://github.com/davidsneighbour/dotfiles/issues/511), [#504](https://github.com/davidsneighbour/dotfiles/issues/504), and [#507](https://github.com/davidsneighbour/dotfiles/issues/507).
3. Add the unified check command in [#503](https://github.com/davidsneighbour/dotfiles/issues/503) after the individual gates are trustworthy.
4. Stabilize setup safety next: [#497](https://github.com/davidsneighbour/dotfiles/issues/497), [#506](https://github.com/davidsneighbour/dotfiles/issues/506), [#510](https://github.com/davidsneighbour/dotfiles/issues/510), [#509](https://github.com/davidsneighbour/dotfiles/issues/509), and [#505](https://github.com/davidsneighbour/dotfiles/issues/505).
5. Continue shell and desktop maintenance: [#501](https://github.com/davidsneighbour/dotfiles/issues/501), [#499](https://github.com/davidsneighbour/dotfiles/issues/499), [#496](https://github.com/davidsneighbour/dotfiles/issues/496), [#508](https://github.com/davidsneighbour/dotfiles/issues/508), [#500](https://github.com/davidsneighbour/dotfiles/issues/500), and [#522](https://github.com/davidsneighbour/dotfiles/issues/522).
6. Review service safety: [#520](https://github.com/davidsneighbour/dotfiles/issues/520), [#512](https://github.com/davidsneighbour/dotfiles/issues/512), [#513](https://github.com/davidsneighbour/dotfiles/issues/513), and [#517](https://github.com/davidsneighbour/dotfiles/issues/517).
7. Improve backup reliability with [#516](https://github.com/davidsneighbour/dotfiles/issues/516) before [#515](https://github.com/davidsneighbour/dotfiles/issues/515).
8. Finish structure cleanup and module polish with [#519](https://github.com/davidsneighbour/dotfiles/issues/519), [#518](https://github.com/davidsneighbour/dotfiles/issues/518), [#498](https://github.com/davidsneighbour/dotfiles/issues/498), and [#514](https://github.com/davidsneighbour/dotfiles/issues/514).
9. Keep [#490](https://github.com/davidsneighbour/dotfiles/issues/490), [#491](https://github.com/davidsneighbour/dotfiles/issues/491), [#492](https://github.com/davidsneighbour/dotfiles/issues/492), [#493](https://github.com/davidsneighbour/dotfiles/issues/493), [#494](https://github.com/davidsneighbour/dotfiles/issues/494), and [#489](https://github.com/davidsneighbour/dotfiles/issues/489) as focused tasks that can be selected independently when their decisions are clear.

## Open clarification questions

* [#489](https://github.com/davidsneighbour/dotfiles/issues/489): Which files own version bumps, and should the command run in lint-staged, release preparation, or manually?
* [#494](https://github.com/davidsneighbour/dotfiles/issues/494): Should commit-message spell checking run locally, in CI, or both?
* [#497](https://github.com/davidsneighbour/dotfiles/issues/497): What is the canonical quick-install entrypoint, and should protected modules be included?
* [#500](https://github.com/davidsneighbour/dotfiles/issues/500): What replaces `bashrc/workspaces`, and do any hosts still rely on it?
* [#505](https://github.com/davidsneighbour/dotfiles/issues/505): Which desktop/config contexts require literal paths because variables are not expanded?
* [#513](https://github.com/davidsneighbour/dotfiles/issues/513): Which services intentionally track floating image tags?
* [#520](https://github.com/davidsneighbour/dotfiles/issues/520): Which secret sources are canonical for local-only services versus shared workstation config?

## Notes

* `scratch/` remains an informal workspace and is not part of the tracking system.
* `TODO.md` should only regain entries for unclear, non-actionable, or intentionally unprocessed notes.
