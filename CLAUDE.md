# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Start here

**Read `AGENTS.md` before doing anything in this repository.** It is the single source of truth for
all agent behaviour here: purpose, architecture, Bash/CLI/Node standards, secrets handling, commit and
submodule rules, and mandatory AI-agent rules. Follow it, and follow any documents it links to
(including `SESSION.md` before touching the i3/Polybar/Rofi desktop session, and
`.github/instructions/*.md` scoped by their `applyTo` field).

This file (`CLAUDE.md`) only adds Claude-specific notes on top of `AGENTS.md`. Any instruction that is
not specific to Claude belongs in `AGENTS.md`, not here.

## Commands

Run these from the repo root (npm, Node ^22/^24/^26 per `package.json` engines):

- `npm run check` — full local gate: backup-runner test, ai-usage test, log-filename lint, shell test,
  config lint, typecheck, markdown lint, shell lint. Run this before considering a change done.
- `npm run test:shell` — `bashrc/helpers/tests/dotfiles-includes-test.sh` +
  `bashrc/helpers/tests/desktop-helpers-health-check.sh`
- `npm run test:ai-usage` — `node --experimental-strip-types bashrc/helpers/ai-usage/tests/ai-usage-test.ts`
- `npm run test:backup-runner` — `node --experimental-strip-types bashrc/helpers/docker/tests/backup-runner-config-test.ts`
- `npm run lint:shell` / `lint:shell:all` — shellcheck via `scripts/shell-quality.sh` (`lint-all` covers
  the full tree, not just changed files)
- `npm run lint:config` — `yamllint -c .yamllint.yml configs bashrc`
- `npm run lint:markdown` / `lint:markdown:fix` — markdownlint-cli2
- `npm run typecheck` — runs `typecheck:config`, `typecheck:scripts`, `typecheck:bash-helpers` (three
  separate `tsconfig*.json` projects)
- `npm run check:biome` / `check:biome:fix` — Biome check/format/lint combined
- `npm run format:shell` — `scripts/shell-quality.sh format-write`

There is no single-test runner; the `.ts` test files under `bashrc/helpers/**/tests/` are run directly
with `node --experimental-strip-types <file>` for a targeted run.

## Architecture notes (beyond AGENTS.md)

- `bashrc/helpers/` is organised by feature (`docker/`, `ai-usage/`, `gh/`, `dotfiles/`, `skillz/`,
  etc.); each helper with tests keeps them in its own `tests/` subdirectory.
- `bashrc/partials/` holds the composable aliases/completions/exports/functions/prompt/topical pieces
  that `bashrc/bashrc` assembles into the interactive shell.
- `bashrc/INDEX.md` and the `DOCUMENTATION*.md` files under `bashrc/` and `bashrc/partials/` are
  generated references for the shell layer — update the source, not these files directly, unless told
  otherwise.
- `configs/` holds static, non-secret configuration (dotbot, fonts, hosts, installs, packages,
  session, system, theme, vscode) applied to the workstation; `protected/` (a private submodule) holds
  the secret counterpart.
- `containers/` holds Docker Compose service stacks (one directory per stack).
- `scripts/` holds the repo's own Node/TS tooling (linting, release, Node-engine sync) — distinct from
  `bin/` (user-facing CLI commands) and `tools/` (standalone utilities like `unsplash-collections`).
