<!-- vale off -->
# Roadmap

**Project:** `@davidsneighbour/dotfiles` — v3003.9.1
**Last updated:** 2026-06-29
**Branch:** `main`

## Project state

The repository is in a healthy, low-activity state. CI is green, patch/minor dependency updates have been applied (commit `de1c4d26b11c`). One issue (#488) remains open for remaining audit findings that cannot be resolved without updates to first-party packages.

## Health indicators

| Signal | Status |
|---|---|
| CI (Push on main) | ✅ passing (last 5 runs succeeded) |
| Open GitHub issues | 1 |
| npm audit | ⚠️ 41 vulnerabilities: 25 high, 13 moderate, 3 low (all require `--force` or have no upstream fix) |
| Markdown lint | ⚠️ errors in `modules/protected/` (submodule, not actionable) |
| TODO.md | ✅ not present (clean) |

## Open issues

### Maintenance

- **[#488](https://github.com/davidsneighbour/dotfiles/issues/488) — fix(deps): address npm audit vulnerabilities**
  Patch/minor updates applied (commit `de1c4d26b11c`). 41 vulnerabilities remain — all require `--force` (breaking) or have no upstream fix. Root causes: `@davidsneighbour/imagemin-lint-staged` (old imagemin binary tooling) and `@davidsneighbour/nanny` (old release-it/undici). Also `elliptic`/`linkify-it` with no upstream fix yet. All are devDependencies only; no production exposure. Follow-up: update the two first-party packages.

## Suggested order of work

1. **#488** — update `@davidsneighbour/imagemin-lint-staged` and `@davidsneighbour/nanny` in their own repos to clear the remaining transitive vulnerability chains. Then re-run `npm install` here.

## Open clarification questions

None.

## Notes

- Markdown lint errors in `modules/protected/DraculaPro/` originate from the DraculaPro submodule and are not actionable here.
- `scratch/` is excluded from linting enforcement by design.
- `PROJECT.md` has a title-case lint error (`# Project Instructions` → `# Project instructions`) but this is a cosmetic issue and is not tracked separately.
