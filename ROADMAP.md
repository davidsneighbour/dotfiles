<!-- vale off -->
# Roadmap

**Project:** `@davidsneighbour/dotfiles` — v3003.9.1
**Last updated:** 2026-06-29
**Branch:** `main`

## Project state

The repository is healthy. CI is green, all actionable dependency vulnerabilities have been resolved. No open GitHub issues.

## Health indicators

| Signal | Status |
| --- | --- |
| CI (Push on main) | ✅ passing (last 5 runs succeeded) |
| Open GitHub issues | 0 |
| npm audit | ⚠️ 14 vulnerabilities: 2 high, 9 moderate, 3 low — all accepted risk (no upstream fix or --force only) |
| Markdown lint | ⚠️ errors in `modules/protected/` (submodule, not actionable) |
| TODO.md | ✅ not present (clean) |

## Open issues

None.

## Accepted-risk audit findings (14)

All are devDependencies with no production exposure. None can be fixed without a breaking change or an upstream fix that does not yet exist.

| Root package | Severity | Why not fixed |
| --- | --- | --- |
| `elliptic` → `secp256k1` → `@secretlint/secretlint-rule-secp256k1-privatekey` | low | No upstream fix available |
| `linkify-it` → `markdown-it` → `markdownlint`/`markdownlint-rule-*` | 2 high, moderate | No upstream fix available |
| `js-yaml` in `@yarnpkg/parsers` → `lockfile-lint-api` → `lockfile-lint` | moderate | Fix requires `--force` downgrade to `lockfile-lint@4.7.4` (breaking) |

## Suggested order of work

Watch upstream for fixes to `elliptic`, `linkify-it`, and `@yarnpkg/parsers`/`js-yaml`. Re-run `npm audit` after any secretlint, markdownlint-rule-title-case-style, or lockfile-lint updates.

## Notes

* Markdown lint errors in `modules/protected/DraculaPro/` originate from the DraculaPro submodule and are not actionable here.
* `scratch/` is excluded from linting enforcement by design.
* `PROJECT.md` has a title-case lint error (`# Project Instructions` → `# Project instructions`) but this is a cosmetic issue and is not tracked separately.
