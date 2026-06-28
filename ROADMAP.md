<!-- vale off -->
# Roadmap

**Project:** `@davidsneighbour/dotfiles` — v3003.9.1
**Last updated:** 2026-06-29
**Branch:** `main`

## Project state

The repository is in a healthy, low-activity state. CI is green, no open issues exist prior to this triage run, and the codebase has been receiving regular maintenance commits (submodule updates, config fixes, new AI aliases). One new issue was filed during triage for dependency vulnerabilities.

## Health indicators

| Signal | Status |
|---|---|
| CI (Push on main) | ✅ passing (last 5 runs succeeded) |
| Open GitHub issues | 1 (filed during this triage) |
| npm audit | ⚠️ 44 vulnerabilities: 26 high, 15 moderate, 3 low |
| Markdown lint | ⚠️ errors in `modules/protected/` (submodule, not actionable) |
| TODO.md | ✅ not present (clean) |

## Open issues

### Maintenance

- **[#488](https://github.com/davidsneighbour/dotfiles/issues/488) — fix(deps): address npm audit vulnerabilities (26 high, 15 moderate, 3 low)**
  Affects devDependencies including `cross-spawn` (ReDoS), `undici`, `hono`, `markdown-it`, `release-it`, and imagemin tooling. Start with `npm audit fix` for non-breaking updates, then evaluate `npm audit fix --force`. Use the `dnb-dependency-maintenance` skill for a guided update workflow.

## Suggested order of work

1. **#488** — run `npm audit fix`, review output, update first-party packages if needed, document accepted-risk exceptions for any remaining issues.

## Open clarification questions

None.

## Notes

- Markdown lint errors in `modules/protected/DraculaPro/` originate from the DraculaPro submodule and are not actionable here.
- `scratch/` is excluded from linting enforcement by design.
- `PROJECT.md` has a title-case lint error (`# Project Instructions` → `# Project instructions`) but this is a cosmetic issue and is not tracked separately.
