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
* `parseProviderOutput` (`src/providers/provider.ts`) — extracts normalised limits from JSON or fallback text output.
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
