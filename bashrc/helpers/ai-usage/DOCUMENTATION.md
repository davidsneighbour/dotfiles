# Ai-usage

`ai-usage` is a local TypeScript-backed helper command for collecting AI assistant
usage-limit information from authenticated provider CLIs and rendering a compact
terminal dashboard.

The implementation is intentionally provider-adapter based. Claude Code and
Codex parsing live under `src/providers/`, while health scoring, rendering, and
configuration stay provider-neutral.

## Usage

Run the dashboard:

```bash
ai-usage
```

Print structured output:

```bash
ai-usage --json
```

Run provider diagnostics:

```bash
ai-usage doctor
```

Use a non-default config file:

```bash
ai-usage --config ./config.toml
```

## Configuration

The default configuration path is:

```text
~/.config/ai-usage/config.toml
```

Missing configuration is not an error. The default enables both initial
providers:

```toml
[providers.claude]
enabled = true

[providers.codex]
enabled = true
```

Health thresholds can be overridden:

```toml
[health]
warning_ratio = 1.15
critical_ratio = 1.35
critical_remaining_percent = 10
minimum_elapsed_percent = 10
```

## Provider acquisition

Credentials are not managed by this helper. It uses the existing authenticated
state of the local `claude` and `codex` commands.

Provider failures are isolated. If one provider is unavailable, the other can
still render. The command exits non-zero when every configured provider fails or
when configuration is invalid.

## Claude code provider details

`claude -p /usage --output-format json --no-session-persistence` is the only
confirmed non-interactive Claude Code usage source. There is no separate
structured quota API: the JSON envelope's `result` field is the same
human-readable text shown by `/usage` interactively (e.g. `Current session:
4% used · resets Aug 22, 7:59pm (Asia/Bangkok)`), including a variable
"What's contributing to your limits usage?" breakdown of unrelated
percentages (skills, MCP servers, context usage). Parsing must extract only
the two quota lines (`Current session`, `Current week`) and ignore the rest.

Two upstream quirks were confirmed against a real authenticated `claude`
outside the sandbox and are handled defensively rather than assumed away:

* `claude --output-format json` can leak an unrelated MCP diagnostic line
  (e.g. `Client.listTools() called but server does not advertise tools
  capability - returning empty list`) onto stdout *after* the JSON payload.
  `parseProviderOutput` retries `JSON.parse` against just the first line
  before falling back to whole-blob text parsing, so this noise can't break
  parsing or (worse) get scanned as if it were quota text.
* Reset times are reported inconsistently — sometimes a whole hour
  (`resets Aug 20, 4pm`), sometimes with minutes (`resets Aug 22, 7:59pm`).
  `parseResetAt`'s minute group is optional to match both.

Claude does not report a window start time, only a reset time, for either
window. `startedAt` is derived as `resetsAt - durationSeconds` using the
publicly documented quota windows: a 5-hour rolling session limit and a
7-day weekly limit. This is what lets health scoring use pace
(`usageRatio / elapsedRatio`) instead of falling back to absolute-only
classification for every Claude limit. If Claude ever reports quota windows
of a different length, the label-based duration table in
`src/providers/provider.ts` (`KNOWN_WINDOW_DURATIONS_SECONDS`) needs updating.

## Codex provider details

`codex-cli 0.149.0` does not currently expose a confirmed non-interactive
quota source. The checked CLI surface has `codex doctor --json`, which reports
installation, authentication, configuration, reachability, and local state
health, but it does not include quota, limit, usage-window, reset, or remaining
allowance fields. `codex --help` lists no `status` or `usage` subcommand;
asking for `codex status --help` or `codex usage --help` falls through to the
main interactive CLI help. `codex status` itself is not used because it enters
the interactive TUI path instead of returning parseable usage data.

The current adapter therefore treats Codex as authenticated only when
`codex doctor --json` reports `auth.credentials.status = "ok"`, then returns an
explicit unsupported-usage error with no invented quota windows. `ai-usage
doctor` still reports Codex executable and authentication state, while marking
usage retrieval as unsupported.

A Playwright-based web scrape was also checked and rejected as a helper source:
opening `https://chatgpt.com/` from the automation browser returned a `403`
`Just a moment...` page. Even if that path sometimes works locally, it depends
on browser session/web UI state rather than the local authenticated `codex`
command, so it is not stable enough for this CLI helper.

## Health model

Usage health is based on quota pressure, not raw percentage consumed. For
windows with known start and reset times, the helper compares usage progress to
elapsed window time:

```text
pressureRatio = usageRatio / elapsedRatio
```

When timing data is incomplete, it falls back to absolute remaining quota.

## Functions/methods defined

* `main` (`src/cli.ts`) — parses CLI arguments, loads config, orchestrates providers, and selects the renderer.
* `ai-usage` (`bin/ai-usage`) — top-level command launcher that forwards to the helper entry point.
* `ai-usage.ts` (`ai-usage/ai-usage.ts`) — executable TypeScript entry point for the helper.
* `loadConfig` (`src/config.ts`) — loads TOML config and applies defaults.
* `runCommand` (`src/commands/run-command.ts`) — runs provider commands without shell interpolation and with a timeout.
* `commandFailureMessage` (`src/commands/run-command.ts`) — normalises command failure details for provider errors.
* `runDoctor` (`src/commands/doctor.ts`) — runs provider executable, authentication, and retrieval checks.
* `parseProviderOutput` (`src/providers/provider.ts`) — extracts normalised limits from JSON or fallback text output, tolerating trailing non-JSON diagnostic lines.
* `ClaudeCodeProvider.collect` (`src/providers/claude-code.ts`) — retrieves Claude Code usage.
* `ClaudeCodeProvider.doctor` (`src/providers/claude-code.ts`) — checks Claude Code availability and retrieval.
* `CodexProvider.collect` (`src/providers/codex.ts`) — retrieves Codex usage.
* `CodexProvider.doctor` (`src/providers/codex.ts`) — checks Codex availability and retrieval.
* `classifyLimitHealth` (`src/usage/health.ts`) — classifies one limit as healthy, elevated, critical, or unknown.
* `attachHealth` (`src/usage/health.ts`) — adds health results to provider limits.
* `buildSummary` (`src/usage/health.ts`) — builds aggregate dashboard signals.
* `formatDuration` (`src/usage/time.ts`) — renders compact durations such as `2h 12m`.
* `formatResetAt` (`src/usage/time.ts`) — renders absolute reset times for the terminal table.
* `secondsUntil` (`src/usage/time.ts`) — calculates reset countdown values.
* `renderTerminalReport` (`src/renderers/terminal.ts`) — renders the default terminal dashboard.
* `renderJsonReport` (`src/renderers/json.ts`) — renders the structured JSON report.

## Tests

Run the focused test suite:

```bash
npm run test:ai-usage
```

The tests use fixtures under `tests/fixtures/` for parser coverage and direct
health boundary assertions for quota-pressure classification.
