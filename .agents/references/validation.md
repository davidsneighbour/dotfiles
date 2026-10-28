# Validation commands

Run these from the repo root (npm, Node ^22/^24/^26 per `package.json` engines):

* `npm run check` — full local gate, including terminal-theme drift, terminal UI lint and tests, backup-runner, ai-usage, Dotbot crontab, log-filename, shell, config, TypeScript, Markdown, and shellcheck checks. Run this before considering a change done.
* `npm run lint:terminal-ui` — rejects raw ANSI escapes, direct Gum styling or widgets, and `tput` colours in shell and awk files outside the terminal UI facade (`scripts/lint-terminal-ui.ts`)
* `npm run test:ui` — terminal UI facade contracts (`bashrc/helpers/tests/dnb-ui-test.sh`)
* `npm run lint:terminal-theme` — drift check for generated renderer themes in `configs/theme/dnb-terminal/`; fix with `npm run build:terminal-theme`
* `npm run test:shell` — Chrome app launcher tests, dotfiles include tests, the `31-session-config` system check, and package tests.
* `npm run test:dotbot-crontab` — `python3 configs/dotbot/tests/crontab-test.py`
* `npm run test:ai-usage` — `node --experimental-strip-types bashrc/helpers/ai-usage/tests/ai-usage-test.ts`
* `npm run test:backup-runner` — `node --experimental-strip-types bashrc/helpers/docker/tests/backup-runner-config-test.ts`
* `npm run lint:shell` / `lint:shell:all` — shellcheck via `scripts/shell-quality.sh` (`lint-all` covers
  the full tree, not just changed files)
* `npm run lint:config` — `yamllint -c .yamllint.yml configs bashrc`
* `npm run lint:markdown` / `lint:markdown:fix` — markdownlint-cli2
* `npm run typecheck` — runs `typecheck:config`, `typecheck:scripts`, `typecheck:bash-helpers` (three
  separate `tsconfig*.json` projects)
* `npm run check:biome` / `check:biome:fix` — Biome check/format/lint combined
* `npm run format:shell` — `scripts/shell-quality.sh format-write`

There is no single-test runner; the `.ts` test files under `bashrc/helpers/**/tests/` are run directly
with `node --experimental-strip-types <file>` for a targeted run.
