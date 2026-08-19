# Repo-wide check command

`npm run check` runs the lightweight validation gates that decide whether the
repository is healthy enough to commit or hand to another agent, in order
from fastest to slowest:

1. `test:backup-runner` — backup-runner TOML config fixtures
2. `lint:log-filenames` — date-bearing log filename policy
3. `test:shell` — shell include resolution and desktop helper smoke checks
4. `lint:config` — YAML linting for `configs/` and `bashrc/`
5. `typecheck` — TypeScript checking across config, scripts, and bash helpers
6. `lint:markdown` — Markdown linting
7. `lint:shell` — ShellCheck against tracked shell files

The command fails on the first gate that fails, with that gate's own
actionable output.

## Intentionally omitted checks

* `check:node-engines` — requires network access to fetch the current Node.js
  release schedule; run manually or in an environment with network access.
* `lint:biome` / `check:biome` and their `:fix` variants — Biome linting and
  formatting for JS/TS/JSON; run separately, not part of the baseline gate.
* `lint:markdown:fix`, `format`, `format:shell`, `lint:biome:fix`,
  `check:biome:fix` — mutating variants; `check` only reads, never writes.
* `lint:hook:commit` / `lint:hook:commit:loud` — scoped to the staged file
  set for pre-commit hooks, not the whole repository.
* `release*` — publishing/version-bump commands; never part of a health check.
