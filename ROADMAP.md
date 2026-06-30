<!-- vale off -->
# Roadmap

**Project:** `@davidsneighbour/dotfiles` — v3004.0.0
**Last updated:** 2026-07-01
**Branch:** `main`

## Project state

The repository is healthy enough to continue regular maintenance. GitHub Issues now contains the actionable work from the TODO inbox, and `TODO.md` only keeps unclear scratch notes that need more direction before tracking.

## Health indicators

| Signal | Status |
| --- | --- |
| CI | Passing: last 10 GitHub Actions runs succeeded |
| Open GitHub issues | 14 |
| npm audit | 11 vulnerabilities: 2 high, 6 moderate, 3 low, 0 critical |
| Markdown lint | Passing for `TODO.md` and `ROADMAP.md` |
| Runtime observed locally | Node.js v26.3.0, npm 11.16.0 |
| TODO.md | 2 unclear inbox notes remain |

## Open issues

### Setup and installation

| Issue | Notes |
| --- | --- |
| [#497 Fix quick installation flow for dotfiles](https://github.com/davidsneighbour/dotfiles/issues/497) | Clarify the canonical quick-install path before broader setup cleanup. |
| [#491 Refine global npm package setup](https://github.com/davidsneighbour/dotfiles/issues/491) | Split minimal defaults from optional global packages. |
| [#492 Add zoxide to the workstation stack](https://github.com/davidsneighbour/dotfiles/issues/492) | Add install and Bash initialization with graceful fallback. |
| [#493 Add msgvault Bash completion](https://github.com/davidsneighbour/dotfiles/issues/493) | Load completions without breaking shells where `msgvault` is absent. |
| [#490 Evaluate and add a window tiling helper](https://github.com/davidsneighbour/dotfiles/issues/490) | Decide between the linked Xubuntu script, `zentile`, or no addition. |

### Quality automation

| Issue | Notes |
| --- | --- |
| [#495 Make lint-staged commands operate only on staged files](https://github.com/davidsneighbour/dotfiles/issues/495) | Check each lint-staged task for broad glob expansion or ignored file lists. |
| [#494 Add spell checking for commit messages](https://github.com/davidsneighbour/dotfiles/issues/494) | Decide whether enforcement belongs in local hooks, CI, or both. |
| [#489 Add version-bump linter for changed files](https://github.com/davidsneighbour/dotfiles/issues/489) | Needs scope decisions for authoritative version files and execution timing. |
| [#502 Follow up on remaining npm audit findings](https://github.com/davidsneighbour/dotfiles/issues/502) | Resolve the fixable `js-yaml` path and document remaining accepted risk. |

### Bash maintenance

| Issue | Notes |
| --- | --- |
| [#496 Clean up and document bashrc cronjob helpers](https://github.com/davidsneighbour/dotfiles/issues/496) | Review logging, help output, and shellcheck coverage. |
| [#499 Clean up and document bashrc helpers](https://github.com/davidsneighbour/dotfiles/issues/499) | Inventory helpers and add focused function-level help where useful. |
| [#501 Clean up and document bashrc partials](https://github.com/davidsneighbour/dotfiles/issues/501) | Keep interactive shell startup safe, quiet, and explicit. |
| [#500 Clean up and deprecate bashrc workspaces](https://github.com/davidsneighbour/dotfiles/issues/500) | Requires a replacement or host-usage decision before removal. |

### Configuration maintenance

| Issue | Notes |
| --- | --- |
| [#498 Document and clean up configs directory](https://github.com/davidsneighbour/dotfiles/issues/498) | Inventory config ownership and avoid moves until link/install paths are checked. |

## Audit findings

`npm audit --json` reports 11 dev-tooling vulnerabilities. The remaining high findings flow through Markdown parser tooling, not production dependencies.

| Root package | Severity | Why not fixed |
| --- | --- | --- |
| `elliptic` → `secp256k1` → `@secretlint/secretlint-rule-secp256k1-privatekey` | low | No upstream fix available |
| `linkify-it` → `markdown-it` → `markdownlint`/`markdownlint-rule-*` | 2 high, moderate | No upstream fix available for all paths |
| `js-yaml` → `markdownlint-cli2` | moderate | Fix is available according to npm audit; tracked in #502 |

## Suggested order of work

1. Handle [#502](https://github.com/davidsneighbour/dotfiles/issues/502) first because npm audit reports a fixable `js-yaml` path.
2. Clarify the quick-install entrypoint in [#497](https://github.com/davidsneighbour/dotfiles/issues/497).
3. Then handle setup polish: [#491](https://github.com/davidsneighbour/dotfiles/issues/491), [#492](https://github.com/davidsneighbour/dotfiles/issues/492), and [#493](https://github.com/davidsneighbour/dotfiles/issues/493).
4. Tighten automation next: [#495](https://github.com/davidsneighbour/dotfiles/issues/495), [#494](https://github.com/davidsneighbour/dotfiles/issues/494), and [#489](https://github.com/davidsneighbour/dotfiles/issues/489).
5. Work through Bash maintenance by area: [#496](https://github.com/davidsneighbour/dotfiles/issues/496), [#499](https://github.com/davidsneighbour/dotfiles/issues/499), [#501](https://github.com/davidsneighbour/dotfiles/issues/501), then [#500](https://github.com/davidsneighbour/dotfiles/issues/500).
6. Finish with broader config cleanup in [#498](https://github.com/davidsneighbour/dotfiles/issues/498) after install/link paths are stable.
7. Keep [#490](https://github.com/davidsneighbour/dotfiles/issues/490) as a focused workstation usability task that can be picked up independently once current window-management patterns are reviewed.

## Open clarification questions

* [#489](https://github.com/davidsneighbour/dotfiles/issues/489): Which files own version bumps, and should the command run in lint-staged, release preparation, or manually?
* [#494](https://github.com/davidsneighbour/dotfiles/issues/494): Should commit-message spell checking run locally, in CI, or both?
* [#497](https://github.com/davidsneighbour/dotfiles/issues/497): What is the canonical quick-install entrypoint, and should protected modules be included?
* [#500](https://github.com/davidsneighbour/dotfiles/issues/500): What replaces `bashrc/workspaces`, and do any hosts still rely on it?

## Notes

* `scratch/` is excluded from linting enforcement by design.
* `TODO.md` intentionally keeps only unclear scratch notes after this triage pass.
